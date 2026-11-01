import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PdfService } from '../pdf/pdf.service';
import { CommunicationsService } from '../notifications/communications.service';
import {
  OrderStatus,
  PaymentStatus,
  PaymentMethod,
  BuyerType,
  UserRoleType,
} from '@prisma/client';
import { LoyaltyService } from '../loyalty/loyalty.service';

@Injectable()
export class OrdersService {
  constructor(
    private prisma: PrismaService,
    private pdfService: PdfService,
    private communicationsService: CommunicationsService,
    private loyaltyService: LoyaltyService,
  ) {}

  async findAll(query: {
    status?: OrderStatus;
    paymentStatus?: PaymentStatus;
    buyerProfileId?: string;
    salesmanProfileId?: string;
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query.page) || 1;
    const limit = Number(query.limit) || 20;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query.status) where.status = query.status;
    if (query.paymentStatus) where.paymentStatus = query.paymentStatus;
    if (query.buyerProfileId) where.buyerProfileId = query.buyerProfileId;
    if (query.salesmanProfileId) where.salesmanProfileId = query.salesmanProfileId;

    if (query.search) {
      where.OR = [
        { orderNumber: { contains: query.search, mode: 'insensitive' } },
        { buyer: { businessName: { contains: query.search, mode: 'insensitive' } } },
        { buyer: { user: { fullName: { contains: query.search, mode: 'insensitive' } } } },
      ];
    }

    if (!this.prisma.isConnected) {
      return this.getMockOrders();
    }

    try {
      const [total, orders] = await Promise.all([
        this.prisma.order.count({ where }),
        this.prisma.order.findMany({
          where,
          skip,
          take: limit,
          include: {
            buyer: {
              include: { user: true },
            },
            salesman: {
              include: { user: true },
            },
            items: {
              include: {
                product: {
                  include: {
                    media: true,
                    category: true,
                  },
                },
              },
            },
            payments: true,
            statusHistory: {
              orderBy: { changedAt: 'desc' },
            },
          },
          orderBy: { createdAt: 'desc' },
        }),
      ]);

      const enrichedOrders = orders.map((o) => {
        const taxable = Math.max(0, Number(o.subtotal) - Number(o.discountTotal || 0));
        let profit = o.profit !== null && o.profit !== undefined ? Number(o.profit) : null;
        if (profit === null) {
          const totalCost = o.items.reduce((s: number, it: any) => {
            const cost = Number(it.purchasePrice ?? it.product?.purchasePrice ?? it.product?.pricing?.purchasePrice ?? 0);
            return s + (it.quantity * cost);
          }, 0);
          profit = Math.round((taxable - totalCost) * 100) / 100;
        }
        const profitMargin = taxable > 0 ? Math.round((profit / taxable) * 100) : 0;
        return {
          ...o,
          profit,
          profitMargin,
        };
      });

      return {
        orders: enrichedOrders,
        pagination: {
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit),
        },
      };
    } catch (err) {
      return this.getMockOrders();
    }
  }

  private getMockOrders() {
    const list = [
      {
        id: 'ord-101',
        orderNumber: 'ORD-2026-001',
        status: 'PROCESSING',
        paymentStatus: 'PAID',
        paymentMethod: 'ONLINE',
        totalAmount: 132915.2,
        outstandingBalance: 0,
        createdAt: new Date().toISOString(),
        buyer: { businessName: 'Apex Water Systems Pvt Ltd', user: { fullName: 'Rajesh Verma' } },
        items: [{ id: 'item-1', title: 'Grand Aqua Pro RO+UV+UF', quantity: 8, unitPrice: 16000 }],
      },
      {
        id: 'ord-102',
        orderNumber: 'ORD-2026-002',
        status: 'DELIVERED',
        paymentStatus: 'PAID',
        paymentMethod: 'CREDIT',
        totalAmount: 95285,
        outstandingBalance: 0,
        createdAt: new Date(Date.now() - 3 * 24 * 3600 * 1000).toISOString(),
        buyer: { businessName: 'National RO Spares', user: { fullName: 'Suresh Patel' } },
        items: [{ id: 'item-2', title: 'Commercial RO Plant 250 LPH', quantity: 1, unitPrice: 85000 }],
      },
    ];
    return { orders: list, pagination: { total: list.length, page: 1, limit: 20, totalPages: 1 } };
  }

  async findOne(id: string) {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: {
        buyer: {
          include: { user: true, addresses: true, creditAccount: true },
        },
        salesman: {
          include: { user: true },
        },
        items: {
          include: {
            product: {
              include: {
                media: true,
                category: true,
              },
            },
          },
        },
        statusHistory: {
          orderBy: { changedAt: 'desc' },
        },
        payments: {
          orderBy: { createdAt: 'desc' },
        },
        invoices: true,
      },
    });

    if (!order) {
      throw new NotFoundException(`Order with ID "${id}" not found`);
    }

    const taxable = Math.max(0, Number(order.subtotal) - Number(order.discountTotal || 0));
    let profit = order.profit !== null && order.profit !== undefined ? Number(order.profit) : null;
    if (profit === null) {
      const totalCost = order.items.reduce((s: number, it: any) => {
        const cost = Number(it.purchasePrice ?? it.product?.purchasePrice ?? it.product?.pricing?.purchasePrice ?? 0);
        return s + (it.quantity * cost);
      }, 0);
      profit = Math.round((taxable - totalCost) * 100) / 100;
    }
    const profitMargin = taxable > 0 ? Math.round((profit / taxable) * 100) : 0;

    return {
      ...order,
      profit,
      profitMargin,
    };
  }

  async createDirectCheckoutOrder(
    buyerUserId: string,
    data: {
      items: { productId: string; quantity: number }[];
      shippingAddress: any;
      billingAddress?: any;
      voucherCode?: string;
      paymentMethod: PaymentMethod;
      deliveryNotes?: string;
    },
  ) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { userId: buyerUserId },
      include: {
        user: true,
        creditAccount: true,
      },
    });

    if (!buyer) throw new NotFoundException('Buyer profile not found for user');
    if (buyer.accountStatus === 'BLOCKED' || buyer.accountStatus === 'SUSPENDED') {
      throw new BadRequestException('Your account is restricted from placing new orders');
    }

    // Server-side price calculation: strictly uses buyer's current type
    let subtotal = 0;
    let taxTotal = 0;
    let totalPurchaseCost = 0;
    const orderItemsData: any[] = [];

    for (const item of data.items) {
      const product = await this.prisma.product.findUnique({
        where: { id: item.productId },
        include: { pricing: true },
      });

      if (!product || !product.pricing) {
        throw new BadRequestException(`Product ${item.productId} invalid`);
      }

      let unitPrice = Number(product.pricing.customerPrice);
      if (buyer.buyerType === BuyerType.DISTRIBUTOR) {
        unitPrice = Number(product.pricing.distributorPrice);
      } else if (buyer.buyerType === BuyerType.WHOLESALER) {
        unitPrice = Number(product.pricing.wholesalerPrice);
      } else if (buyer.buyerType === BuyerType.DEALER) {
        unitPrice = Number(product.pricing.dealerPrice);
      }

      const purchasePrice = Number(product.purchasePrice ?? product.pricing?.purchasePrice ?? 0);
      totalPurchaseCost += purchasePrice * item.quantity;

      const lineBeforeTax = unitPrice * item.quantity;
      const taxRate = Number(product.pricing.taxRate || 18.0);
      const taxAmount = (lineBeforeTax * taxRate) / 100;
      const totalPrice = lineBeforeTax + taxAmount;

      subtotal += lineBeforeTax;
      taxTotal += taxAmount;

      orderItemsData.push({
        productId: product.id,
        sku: product.sku,
        productName: product.name,
        quantity: item.quantity,
        unitPrice,
        purchasePrice,
        taxAmount,
        totalPrice,
      });
    }

    // Voucher code discount validation on backend
    let discountTotal = 0;
    let appliedVoucher: any = null;
    if (data.voucherCode) {
      const voucher = await this.prisma.giftVoucher.findUnique({
        where: { code: data.voucherCode.trim().toUpperCase() },
      });

      if (
        voucher &&
        voucher.status === 'ACTIVE' &&
        new Date() >= voucher.validFrom &&
        new Date() <= voucher.validUntil
      ) {
        if (subtotal >= Number(voucher.minOrderValue)) {
          if (voucher.isPercentage) {
            discountTotal = (subtotal * Number(voucher.voucherValue)) / 100;
          } else {
            discountTotal = Number(voucher.voucherValue);
          }
          appliedVoucher = voucher;
        }
      }
    }

    const shippingCharges = subtotal >= 5000 ? 0 : 250;
    const taxableSubtotal = Math.max(0, subtotal - discountTotal);
    const profit = Math.round((taxableSubtotal - totalPurchaseCost) * 100) / 100;
    const finalAmount = Math.max(0, taxableSubtotal + taxTotal + shippingCharges);

    // If paying via CREDIT_ACCOUNT, enforce credit limit check
    if (data.paymentMethod === PaymentMethod.CREDIT_ACCOUNT) {
      if (!buyer.creditAccount || buyer.creditAccount.status !== 'ACTIVE') {
        throw new BadRequestException('You do not have an active approved credit facility');
      }
      if (Number(buyer.creditAccount.availableCredit) < finalAmount) {
        throw new BadRequestException(
          `Order exceeds available credit limit. Available: ₹${buyer.creditAccount.availableCredit}, Order: ₹${finalAmount}`,
        );
      }
    }

    const orderCount = await this.prisma.order.count();
    const orderNumber = `GA-ORD-2026-${String(orderCount + 1).padStart(4, '0')}`;

    const createdOrder = await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.create({
        data: {
          orderNumber,
          buyerProfileId: buyer.id,
          salesmanProfileId: buyer.assignedSalesmanId,
          status: OrderStatus.PENDING,
          paymentStatus:
            data.paymentMethod === PaymentMethod.CREDIT_ACCOUNT
              ? PaymentStatus.PAID
              : PaymentStatus.PENDING,
          paymentMethod: data.paymentMethod,
          subtotal,
          discountTotal,
          taxTotal,
          taxRate: 18.0,
          profit,
          shippingCharges,
          finalAmount,
          paidAmount: data.paymentMethod === PaymentMethod.CREDIT_ACCOUNT ? finalAmount : 0,
          outstandingAmount: data.paymentMethod === PaymentMethod.CREDIT_ACCOUNT ? 0 : finalAmount,
          shippingAddress: data.shippingAddress,
          billingAddress: data.billingAddress || data.shippingAddress,
          deliveryNotes: data.deliveryNotes,
          items: {
            create: orderItemsData,
          },
        },
        include: {
          items: true,
          buyer: true,
        },
      });

      // Update credit ledger if credit was used
      if (data.paymentMethod === PaymentMethod.CREDIT_ACCOUNT && buyer.creditAccount) {
        const newUtilized = Number(buyer.creditAccount.utilizedCredit) + finalAmount;
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
            transactionType: 'USAGE',
            amount: finalAmount,
            balanceAfter: newAvailable,
            referenceType: 'ORDER',
            referenceId: order.id,
            notes: `Credit utilized for order ${orderNumber}`,
            createdBy: buyerUserId,
          },
        });
      }

      // Record voucher redemption
      if (appliedVoucher) {
        await tx.voucherRedemption.create({
          data: {
            voucherId: appliedVoucher.id,
            buyerProfileId: buyer.id,
            orderId: order.id,
            discountAmount: discountTotal,
          },
        });
        await tx.giftVoucher.update({
          where: { id: appliedVoucher.id },
          data: { currentUses: { increment: 1 } },
        });
      }

      // Record status history
      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: OrderStatus.PENDING,
          toStatus: OrderStatus.PENDING,
          reason: 'Order placed by buyer',
          changedBy: buyerUserId,
        },
      });

      // Update buyer aggregates
      await tx.buyerProfile.update({
        where: { id: buyer.id },
        data: {
          totalOrders: { increment: 1 },
          totalPurchaseValue: { increment: finalAmount },
          outstandingBalance: {
            increment: data.paymentMethod === PaymentMethod.CREDIT_ACCOUNT ? 0 : finalAmount,
          },
        },
      });

      // Deduct inventory stock & check low stock thresholds
      for (const item of data.items) {
        try {
          const prod = await tx.product.findUnique({
            where: { id: item.productId },
            include: { inventory: true },
          });
          if (prod) {
            const currentQty = prod.stockQuantity ?? 50;
            const newQty = Math.max(0, currentQty - item.quantity);
            await tx.product.update({
              where: { id: item.productId },
              data: { stockQuantity: newQty },
            });

            if (prod.inventory) {
              const newInvStock = Math.max(0, prod.inventory.currentStock - item.quantity);
              await tx.inventoryItem.update({
                where: { id: prod.inventory.id },
                data: { currentStock: newInvStock },
              });

              if (newInvStock <= prod.inventory.reorderLevel) {
                const superAdmin = await tx.user.findFirst({
                  where: { role: UserRoleType.SUPER_ADMIN },
                });
                if (superAdmin) {
                  await tx.notification.create({
                    data: {
                      userId: superAdmin.id,
                      title: `Low Stock Alert: ${prod.name}`,
                      body: `Stock for ${prod.name} (${prod.sku}) has fallen to ${newInvStock} units (Reorder level: ${prod.inventory.reorderLevel}).`,
                      type: 'SYSTEM_ALERT',
                      referenceType: 'PRODUCT',
                      referenceId: prod.id,
                    },
                  });
                }
              }
            }
          }
        } catch (stockErr) {
          // Log and continue gracefully
        }
      }

      return order;
    });

    // Automatically award loyalty points based on configured percentage
    try {
      await this.loyaltyService.awardPointsForOrder(
        createdOrder.id,
        createdOrder.finalAmount,
        createdOrder.buyerProfileId,
        createdOrder.orderNumber,
      );
    } catch (_) {}

    return createdOrder;
  }

  async updateOrderStatus(
    orderId: string,
    newStatus: OrderStatus,
    changedById: string,
    reason?: string,
    trackingNumber?: string,
  ) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        buyer: { include: { user: true } },
        salesman: { include: { user: true } },
        items: true,
      },
    });

    if (!order) throw new NotFoundException('Order not found');

    const previousStatus = order.status;

    const result = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.order.update({
        where: { id: orderId },
        data: {
          status: newStatus,
          trackingNumber: trackingNumber || order.trackingNumber,
          deliveredAt: newStatus === OrderStatus.DELIVERED ? new Date() : undefined,
          cancelledAt: newStatus === OrderStatus.CANCELLED ? new Date() : undefined,
          cancellationReason: newStatus === OrderStatus.CANCELLED ? reason : undefined,
        },
        include: {
          buyer: { include: { user: true } },
          items: true,
        },
      });

      // Restore inventory stock if order cancelled
      if (newStatus === OrderStatus.CANCELLED && previousStatus !== OrderStatus.CANCELLED) {
        if (order.items && order.items.length > 0) {
          for (const item of order.items) {
            try {
              const prod = await tx.product.findUnique({
                where: { id: item.productId },
                include: { inventory: true },
              });
              if (prod) {
                await tx.product.update({
                  where: { id: item.productId },
                  data: { stockQuantity: (prod.stockQuantity ?? 50) + item.quantity },
                });
                if (prod.inventory) {
                  await tx.inventoryItem.update({
                    where: { id: prod.inventory.id },
                    data: { currentStock: prod.inventory.currentStock + item.quantity },
                  });
                }
              }
            } catch (stockRestoreErr) {
              // Continue gracefully
            }
          }
        }
      }

      // Record status transition
      await tx.orderStatusHistory.create({
        data: {
          orderId,
          fromStatus: previousStatus,
          toStatus: newStatus,
          reason: reason || `Status updated to ${newStatus}`,
          changedBy: changedById,
        },
      });

      // Send In-App & Push Notification to buyer
      await tx.notification.create({
        data: {
          userId: order.buyer.userId,
          title: `Order ${order.orderNumber} Status: ${newStatus}`,
          body: `Your order is now ${newStatus.toLowerCase()}.${trackingNumber ? ` Tracking Number: ${trackingNumber}` : ''}`,
          type: 'ORDER_UPDATE',
          referenceType: 'ORDER',
          referenceId: orderId,
        },
      });

      return updated;
    });

    if (newStatus === OrderStatus.DELIVERED) {
      try {
        await this.loyaltyService.awardPointsForOrder(
          order.id,
          order.finalAmount,
          order.buyerProfileId,
          order.orderNumber,
        );
      } catch (_) {}
    }

    return result;
  }

  async getOrCreateInvoice(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        buyer: { include: { user: true } },
        salesman: { include: { user: true } },
        sourceQuotation: true,
        items: {
          include: {
            product: {
              include: { media: true, category: true },
            },
          },
        },
        invoices: true,
      },
    });

    if (!order) {
      throw new NotFoundException(`Order with ID "${orderId}" not found`);
    }

    let invoice = order.invoices?.[0];
    if (!invoice) {
      const cleanDigits = order.orderNumber.replace(/[^0-9]/g, '') || Date.now().toString().slice(-4);
      const invoiceNumber = `GA-INV-2026-${cleanDigits.padStart(4, '0')}`;
      invoice = await this.prisma.invoice.create({
        data: {
          invoiceNumber,
          orderId: order.id,
          buyerProfileId: order.buyerProfileId,
          invoiceDate: new Date(),
          dueDate: order.expectedDeliveryDate || new Date(Date.now() + 15 * 86400000),
          subtotal: order.subtotal,
          taxAmount: order.taxTotal,
          discountAmount: order.discountTotal || 0,
          totalAmount: order.finalAmount,
          status: order.paymentStatus === PaymentStatus.PAID ? 'PAID' : 'ISSUED',
        },
      });
    }

    return { order, invoice };
  }

  async dispatchOrder(
    orderId: string,
    data: { trackingNumber: string; carrierName?: string; expectedDeliveryDate?: Date; notes?: string },
    changedById: string,
  ) {
    const carrierNote = data.carrierName ? `Carrier: ${data.carrierName}. ` : '';
    const fullNotes = `${carrierNote}${data.notes || ''}`.trim();

    const updatedOrder = await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({
        where: { id: orderId },
        include: {
          buyer: { include: { user: true } },
          invoices: true,
        },
      });

      if (!order) throw new NotFoundException('Order not found');

      const updated = await tx.order.update({
        where: { id: orderId },
        data: {
          status: OrderStatus.SHIPPED,
          trackingNumber: data.trackingNumber,
          expectedDeliveryDate: data.expectedDeliveryDate,
          deliveryNotes: fullNotes || order.deliveryNotes,
        },
        include: {
          buyer: { include: { user: true } },
          items: true,
          invoices: true,
        },
      });

      // Ensure Invoice is created upon dispatch
      if (!order.invoices || order.invoices.length === 0) {
        const cleanDigits = order.orderNumber.replace(/[^0-9]/g, '') || Date.now().toString().slice(-4);
        const invoiceNumber = `GA-INV-2026-${cleanDigits.padStart(4, '0')}`;
        await tx.invoice.create({
          data: {
            invoiceNumber,
            orderId: order.id,
            buyerProfileId: order.buyerProfileId,
            invoiceDate: new Date(),
            dueDate: data.expectedDeliveryDate || new Date(Date.now() + 15 * 86400000),
            subtotal: order.subtotal,
            taxAmount: order.taxTotal,
            discountAmount: order.discountTotal || 0,
            totalAmount: order.finalAmount,
            status: order.paymentStatus === PaymentStatus.PAID ? 'PAID' : 'ISSUED',
          },
        });
      }

      // Record timeline
      await tx.orderStatusHistory.create({
        data: {
          orderId,
          fromStatus: order.status,
          toStatus: OrderStatus.SHIPPED,
          reason: `Dispatched via ${data.carrierName || 'Carrier'}. Tracking Docket: ${data.trackingNumber}`,
          changedBy: changedById,
        },
      });

      // In-app Notification to buyer
      await tx.notification.create({
        data: {
          userId: order.buyer.userId,
          title: `Order ${order.orderNumber} Dispatched!`,
          body: `Your order has been shipped via ${data.carrierName || 'Courier'}. Tracking No: ${data.trackingNumber}`,
          type: 'ORDER_UPDATE',
          referenceType: 'ORDER',
          referenceId: orderId,
        },
      });

      return updated;
    });

    // Automated WhatsApp & SMS Notification with Tracking Link and PDF Invoice
    try {
      const recipientPhone = updatedOrder.buyer?.user?.phone;
      const recipientName =
        updatedOrder.buyer?.user?.fullName || updatedOrder.buyer?.businessName || 'Valued Customer';
      const totalItems = (updatedOrder.items || []).reduce(
        (sum: number, it: any) => sum + (Number(it.quantity) || 1),
        0,
      );

      if (recipientPhone) {
        await this.communicationsService.sendDispatchNotification({
          orderId: updatedOrder.id,
          orderNumber: updatedOrder.orderNumber,
          recipientPhone,
          recipientName,
          carrierName: data.carrierName,
          trackingNumber: data.trackingNumber,
          finalAmount: updatedOrder.finalAmount,
          itemCount: totalItems,
          expectedDeliveryDate: data.expectedDeliveryDate,
        });
      }
    } catch (notifErr: any) {
      // Do not fail order dispatch if messaging gateway encounters network glitch
      console.error(`[DISPATCH NOTIFICATION WARNING] Failed to send dispatch alert:`, notifErr.message);
    }

    return updatedOrder;
  }

  async resendDispatchNotification(
    orderId: string,
    channel: 'WHATSAPP' | 'SMS' | 'ALL' = 'ALL',
  ) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        buyer: { include: { user: true } },
        items: true,
      },
    });

    if (!order) throw new NotFoundException('Order not found');
    if (!order.trackingNumber) {
      throw new BadRequestException('Order does not have a tracking docket number. Please dispatch first.');
    }

    let carrierName = 'Grand Aqua Logistics';
    if (order.deliveryNotes && order.deliveryNotes.includes('Carrier: ')) {
      carrierName = order.deliveryNotes.split('Carrier: ')[1].split('.')[0].trim();
    }

    const totalItems = (order.items || []).reduce(
      (sum: number, it: any) => sum + (Number(it.quantity) || 1),
      0,
    );

    return this.communicationsService.sendDispatchNotification({
      orderId: order.id,
      orderNumber: order.orderNumber,
      recipientPhone: order.buyer.user.phone,
      recipientName: order.buyer.user.fullName || order.buyer.businessName,
      carrierName,
      trackingNumber: order.trackingNumber,
      finalAmount: order.finalAmount,
      itemCount: totalItems,
      expectedDeliveryDate: order.expectedDeliveryDate || undefined,
      channel,
    });
  }

  async getDispatchLogs(orderId: string) {
    return this.communicationsService.getOrderDispatchLogs(orderId);
  }

  async getInvoicePdf(orderId: string, template: string = '1'): Promise<{ buffer: Buffer; invoiceNumber: string }> {
    const { order, invoice } = await this.getOrCreateInvoice(orderId);
    const buffer = await this.pdfService.generateInvoicePdf(order, invoice, template);
    return {
      buffer,
      invoiceNumber: invoice.invoiceNumber,
    };
  }
}
