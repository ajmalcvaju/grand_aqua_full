import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentMethod, PaymentStatus, UserRoleType } from '@prisma/client';

@Injectable()
export class PaymentsService {
  constructor(private prisma: PrismaService) {}

  async findAll(query: {
    buyerProfileId?: string;
    orderId?: string;
    paymentMethod?: PaymentMethod;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query.page) || 1;
    const limit = Number(query.limit) || 20;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query.buyerProfileId) where.buyerProfileId = query.buyerProfileId;
    if (query.orderId) where.orderId = query.orderId;
    if (query.paymentMethod) where.paymentMethod = query.paymentMethod;

    const [total, payments] = await Promise.all([
      this.prisma.payment.count({ where }),
      this.prisma.payment.findMany({
        where,
        skip,
        take: limit,
        include: {
          buyer: {
            include: { user: true },
          },
          order: true,
          allocations: true,
        },
        orderBy: { paymentDate: 'desc' },
      }),
    ]);

    return {
      payments,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async recordPayment(
    data: {
      buyerProfileId: string;
      orderId?: string;
      amount: number;
      paymentMethod: PaymentMethod;
      transactionReference?: string;
      notes?: string;
      isManualEntry?: boolean;
    },
    receivedByUserId: string,
  ) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id: data.buyerProfileId },
      include: { creditAccount: true },
    });
    if (!buyer) throw new NotFoundException('Buyer profile not found');

    const paymentAmount = Number(data.amount);
    if (paymentAmount <= 0) {
      throw new BadRequestException('Payment amount must be greater than zero');
    }

    const count = await this.prisma.payment.count();
    const paymentNumber = `GA-PAY-2026-${String(count + 1).padStart(4, '0')}`;

    return this.prisma.$transaction(async (tx) => {
      // 1. Create Payment record
      const payment = await tx.payment.create({
        data: {
          paymentNumber,
          buyerProfileId: data.buyerProfileId,
          orderId: data.orderId,
          amount: paymentAmount,
          paymentMethod: data.paymentMethod,
          transactionReference: data.transactionReference,
          paymentStatus: PaymentStatus.PAID,
          isManualEntry: data.isManualEntry !== undefined ? data.isManualEntry : true,
          receivedBy: receivedByUserId,
          notes: data.notes,
        },
      });

      // 2. If orderId specified, allocate payment to order
      if (data.orderId) {
        const order = await tx.order.findUnique({ where: { id: data.orderId } });
        if (order) {
          const newPaid = Number(order.paidAmount) + paymentAmount;
          const newOutstanding = Math.max(0, Number(order.finalAmount) - newPaid);
          const newPaymentStatus =
            newOutstanding <= 0 ? PaymentStatus.PAID : PaymentStatus.PARTIALLY_PAID;

          await tx.order.update({
            where: { id: data.orderId },
            data: {
              paidAmount: newPaid,
              outstandingAmount: newOutstanding,
              paymentStatus: newPaymentStatus,
            },
          });

          await tx.paymentAllocation.create({
            data: {
              paymentId: payment.id,
              orderId: order.id,
              allocatedAmount: paymentAmount,
            },
          });
        }
      }

      // 3. Update Buyer totals
      const newOutstandingBalance = Math.max(0, Number(buyer.outstandingBalance) - paymentAmount);
      await tx.buyerProfile.update({
        where: { id: data.buyerProfileId },
        data: {
          totalPayments: { increment: paymentAmount },
          outstandingBalance: newOutstandingBalance,
        },
      });

      // 4. If buyer has credit account, replenish available credit
      if (buyer.creditAccount) {
        const newUtilized = Math.max(0, Number(buyer.creditAccount.utilizedCredit) - paymentAmount);
        const newAvailable = Number(buyer.creditAccount.creditLimit) - newUtilized;

        await tx.creditAccount.update({
          where: { id: buyer.creditAccount.id },
          data: {
            utilizedCredit: newUtilized,
            availableCredit: newAvailable,
          },
        });

        await tx.creditTransaction.create({
          data: {
            creditAccountId: buyer.creditAccount.id,
            transactionType: 'PAYMENT_SETTLEMENT',
            amount: paymentAmount,
            balanceAfter: newAvailable,
            referenceType: 'PAYMENT',
            referenceId: payment.id,
            notes: `Credit balance settled via payment ${paymentNumber}`,
            createdBy: receivedByUserId,
          },
        });
      }

      // 5. Audit log
      await tx.auditLog.create({
        data: {
          actorId: receivedByUserId,
          actorType: 'ADMIN',
          action: 'RECORD_PAYMENT',
          module: 'payments',
          entityId: payment.id,
          afterState: { paymentNumber, amount: paymentAmount, method: data.paymentMethod },
        },
      });

      return payment;
    });
  }

  async handleGatewayPayment(params: {
    provider: 'RAZORPAY' | 'CASHFREE';
    gatewayPaymentId: string;
    gatewayOrderId?: string;
    amountInInr: number;
    orderId?: string;
    orderNumber?: string;
    buyerProfileId?: string;
    rawPayload?: any;
    notes?: string;
  }) {
    // 1. Resolve Target Order and Buyer
    let order: any = null;
    if (params.orderId) {
      order = await this.prisma.order.findUnique({
        where: { id: params.orderId },
        include: { buyer: { include: { user: true } } },
      });
    } else if (params.orderNumber) {
      order = await this.prisma.order.findUnique({
        where: { orderNumber: params.orderNumber },
        include: { buyer: { include: { user: true } } },
      });
    }

    let buyerProfileId = params.buyerProfileId || order?.buyerProfileId;

    if (!buyerProfileId && order) {
      buyerProfileId = order.buyerProfileId;
    }

    if (!buyerProfileId) {
      throw new BadRequestException('Cannot associate gateway collection: Neither valid Order nor Buyer was identified');
    }

    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id: buyerProfileId },
      include: { user: true, creditAccount: true },
    });

    if (!buyer) {
      throw new NotFoundException(`Buyer profile not found for id ${buyerProfileId}`);
    }

    // Check if this gateway payment ID has already been recorded (idempotency check)
    const existing = await this.prisma.payment.findFirst({
      where: { transactionReference: params.gatewayPaymentId },
    });
    if (existing) {
      return {
        success: true,
        isDuplicate: true,
        paymentId: existing.id,
        message: 'Payment has already been processed and reconciled',
      };
    }

    const paymentAmount = Number(params.amountInInr);
    const count = await this.prisma.payment.count();
    const paymentNumber = `GA-PAY-2026-${String(count + 1).padStart(4, '0')}`;

    return this.prisma.$transaction(async (tx) => {
      // 1. Create Payment record
      const payment = await tx.payment.create({
        data: {
          paymentNumber,
          buyerProfileId,
          orderId: order?.id,
          amount: paymentAmount,
          paymentMethod: PaymentMethod.ONLINE_GATEWAY,
          transactionReference: params.gatewayPaymentId,
          paymentStatus: PaymentStatus.PAID,
          isManualEntry: false,
          receivedBy: `GATEWAY_${params.provider}`,
          notes: params.notes || `Online payment collected via ${params.provider} (${params.gatewayPaymentId})`,
          gatewayProvider: params.provider,
          gatewayOrderId: params.gatewayOrderId,
          gatewayPayload: params.rawPayload || {},
        },
      });

      // 2. Allocate to Order if applicable
      if (order) {
        const newPaid = Number(order.paidAmount) + paymentAmount;
        const newOutstanding = Math.max(0, Number(order.finalAmount) - newPaid);
        const newPaymentStatus =
          newOutstanding <= 0 ? PaymentStatus.PAID : PaymentStatus.PARTIALLY_PAID;

        await tx.order.update({
          where: { id: order.id },
          data: {
            paidAmount: newPaid,
            outstandingAmount: newOutstanding,
            paymentStatus: newPaymentStatus,
          },
        });

        await tx.paymentAllocation.create({
          data: {
            paymentId: payment.id,
            orderId: order.id,
            allocatedAmount: paymentAmount,
          },
        });
      }

      // 3. Update Buyer totals
      const newOutstandingBalance = Math.max(0, Number(buyer.outstandingBalance) - paymentAmount);
      await tx.buyerProfile.update({
        where: { id: buyerProfileId },
        data: {
          totalPayments: { increment: paymentAmount },
          outstandingBalance: newOutstandingBalance,
        },
      });

      // 4. Replenish Credit Account if exists
      if (buyer.creditAccount) {
        const newUtilized = Math.max(0, Number(buyer.creditAccount.utilizedCredit) - paymentAmount);
        const newAvailable = Number(buyer.creditAccount.creditLimit) - newUtilized;

        await tx.creditAccount.update({
          where: { id: buyer.creditAccount.id },
          data: {
            utilizedCredit: newUtilized,
            availableCredit: newAvailable,
          },
        });

        await tx.creditTransaction.create({
          data: {
            creditAccountId: buyer.creditAccount.id,
            transactionType: 'PAYMENT_SETTLEMENT',
            amount: paymentAmount,
            balanceAfter: newAvailable,
            referenceType: 'PAYMENT',
            referenceId: payment.id,
            notes: `Online gateway settlement via ${params.provider} (${paymentNumber})`,
            createdBy: `GATEWAY_${params.provider}`,
          },
        });
      }

      // 5. In-app Notification to Buyer
      if (buyer.userId) {
        await tx.notification.create({
          data: {
            userId: buyer.userId,
            title: `Payment Received: ₹${paymentAmount.toLocaleString('en-IN')}`,
            body: `Your payment of ₹${paymentAmount.toLocaleString('en-IN')} via ${params.provider} was successfully processed${order ? ` for Order #${order.orderNumber}` : ''}. Ref: ${params.gatewayPaymentId}`,
            type: 'PAYMENT_CONFIRMED',
            referenceType: 'PAYMENT',
            referenceId: payment.id,
          },
        });
      }

      // 6. In-app Notification to Super Admin
      const superAdmin = await tx.user.findFirst({
        where: { role: UserRoleType.SUPER_ADMIN },
      });
      if (superAdmin) {
        await tx.notification.create({
          data: {
            userId: superAdmin.id,
            title: `Online Collection: ₹${paymentAmount.toLocaleString('en-IN')} (${params.provider})`,
            body: `Payment received from ${buyer.businessName}${order ? ` for Order #${order.orderNumber}` : ''}. Ref: ${params.gatewayPaymentId}`,
            type: 'PAYMENT_RECEIVED',
            referenceType: 'PAYMENT',
            referenceId: payment.id,
          },
        });
      }

      // 7. Audit log
      await tx.auditLog.create({
        data: {
          actorId: `SYSTEM_${params.provider}`,
          actorType: 'GATEWAY_WEBHOOK',
          action: 'ONLINE_PAYMENT_COLLECTION',
          module: 'payments',
          entityId: payment.id,
          afterState: {
            paymentNumber,
            amount: paymentAmount,
            provider: params.provider,
            reference: params.gatewayPaymentId,
            orderNumber: order?.orderNumber,
          },
        },
      });

      return {
        success: true,
        paymentId: payment.id,
        paymentNumber,
        amount: paymentAmount,
        provider: params.provider,
        orderId: order?.id,
        orderNumber: order?.orderNumber,
        buyerBusinessName: buyer.businessName,
      };
    });
  }

  async getReceivablesSummary() {
    const buyers = await this.prisma.buyerProfile.findMany({
      where: { outstandingBalance: { gt: 0 } },
      select: {
        id: true,
        buyerId: true,
        businessName: true,
        buyerType: true,
        outstandingBalance: true,
        user: { select: { fullName: true, phone: true } },
        assignedSalesman: {
          select: { user: { select: { fullName: true } } },
        },
      },
      orderBy: { outstandingBalance: 'desc' },
    });

    const totalOutstanding = buyers.reduce(
      (acc, b) => acc + Number(b.outstandingBalance),
      0,
    );

    return {
      totalOutstanding,
      count: buyers.length,
      debtors: buyers,
    };
  }
}
