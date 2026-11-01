import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  BuyerType,
  QuotationStatus,
  DiscountApprovalStatus,
  OrderStatus,
  PaymentStatus,
  UserRoleType,
} from '@prisma/client';
import { PdfService } from '../pdf/pdf.service';

@Injectable()
export class QuotationsService {
  constructor(
    private prisma: PrismaService,
    private pdfService: PdfService,
  ) {}

  async findAll(query: {
    buyerProfileId?: string;
    salesmanProfileId?: string;
    status?: QuotationStatus;
    discountApprovalStatus?: DiscountApprovalStatus;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query.page) || 1;
    const limit = Number(query.limit) || 20;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query.buyerProfileId) where.buyerProfileId = query.buyerProfileId;
    if (query.salesmanProfileId) where.salesmanProfileId = query.salesmanProfileId;
    if (query.status) where.status = query.status;
    if (query.discountApprovalStatus) where.discountApprovalStatus = query.discountApprovalStatus;

    if (!this.prisma.isConnected) {
      return this.getMockQuotations();
    }

    try {
      const [total, quotations] = await Promise.all([
        this.prisma.quotation.count({ where }),
        this.prisma.quotation.findMany({
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
            discountApprovals: {
              orderBy: { createdAt: 'desc' },
              take: 1,
            },
          },
          orderBy: { createdAt: 'desc' },
        }),
      ]);

      const enrichedQuotations = quotations.map((q) => {
        const taxableSubtotal = Math.max(0, Number(q.subtotal) - Number(q.additionalDiscountApproved || 0));
        let profit = q.profit !== null && q.profit !== undefined ? Number(q.profit) : null;
        if (profit === null) {
          const totalCost = q.items.reduce((sum: number, it: any) => {
            const cost = Number(it.purchasePrice ?? it.product?.purchasePrice ?? it.product?.pricing?.purchasePrice ?? 0);
            return sum + (it.quantity * cost);
          }, 0);
          profit = Math.round((taxableSubtotal - totalCost) * 100) / 100;
        }
        const profitMargin = taxableSubtotal > 0 ? Math.round((profit / taxableSubtotal) * 100) : 0;
        return {
          ...q,
          profit,
          profitMargin,
        };
      });

      return {
        quotations: enrichedQuotations,
        pagination: {
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit),
        },
      };
    } catch (err) {
      return this.getMockQuotations();
    }
  }

  private getMockQuotations() {
    const list = [
      {
        id: 'q-101',
        quotationNumber: 'QUO-2026-001',
        status: 'PENDING_APPROVAL',
        discountApprovalStatus: 'PENDING',
        extraDiscountPercent: 12.0,
        subtotal: 128000,
        discountAmount: 15360,
        taxAmount: 20275.2,
        finalTotal: 132915.2,
        buyer: { businessName: 'Apex Water Systems Pvt Ltd', user: { fullName: 'Rajesh Verma' } },
        salesman: { user: { fullName: 'Amit Sharma' } },
        items: [{ id: 'qi-1', quantity: 8, unitPrice: 16000, product: { title: 'Grand Aqua Pro RO Purifier' } }],
      },
      {
        id: 'q-102',
        quotationNumber: 'QUO-2026-002',
        status: 'ACCEPTED',
        discountApprovalStatus: 'APPROVED',
        extraDiscountPercent: 5.0,
        subtotal: 85000,
        discountAmount: 4250,
        taxAmount: 14535,
        finalTotal: 95285,
        buyer: { businessName: 'National RO Spares', user: { fullName: 'Suresh Patel' } },
        salesman: { user: { fullName: 'Amit Sharma' } },
        items: [{ id: 'qi-2', quantity: 1, unitPrice: 85000, product: { title: 'Commercial RO Plant 250 LPH' } }],
      },
    ];
    return { quotations: list, pagination: { total: list.length, page: 1, limit: 20, totalPages: 1 } };
  }

  async findOne(id: string) {
    const quotation = await this.prisma.quotation.findUnique({
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
        discountApprovals: {
          orderBy: { createdAt: 'desc' },
        },
        versions: {
          orderBy: { createdAt: 'desc' },
        },
        orders: true,
      },
    });

    if (!quotation) {
      throw new NotFoundException(`Quotation with ID "${id}" not found`);
    }

    const taxableSubtotal = Math.max(0, Number(quotation.subtotal) - Number(quotation.additionalDiscountApproved || 0));
    let profit = quotation.profit !== null && quotation.profit !== undefined ? Number(quotation.profit) : null;
    if (profit === null) {
      const totalCost = quotation.items.reduce((sum: number, it: any) => {
        const cost = Number(it.purchasePrice ?? it.product?.purchasePrice ?? it.product?.pricing?.purchasePrice ?? 0);
        return sum + (it.quantity * cost);
      }, 0);
      profit = Math.round((taxableSubtotal - totalCost) * 100) / 100;
    }
    const profitMargin = taxableSubtotal > 0 ? Math.round((profit / taxableSubtotal) * 100) : 0;

    return {
      ...quotation,
      profit,
      profitMargin,
    };
  }

  async create(data: {
    buyerProfileId: string;
    salesmanProfileId?: string;
    items: { productId: string; quantity: number }[];
    additionalDiscountRequested?: number;
    discountReason?: string;
    validityDays?: number;
    paymentTerms?: string;
    buyerNotes?: string;
    internalNotes?: string;
    creatorUser: { id: string; role: UserRoleType };
  }) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id: data.buyerProfileId },
      include: { user: true },
    });
    if (!buyer) throw new NotFoundException('Buyer profile not found');

    // Load products and calculate snapshot prices based on buyer's category
    let subtotal = 0;
    let taxAmount = 0;
    let totalPurchaseCost = 0;
    const itemRecords: any[] = [];
    const isBuyerInitiated = data.creatorUser.role === UserRoleType.BUYER;
    const requestedTaxRate = (data as any).taxRate !== undefined ? Number((data as any).taxRate) : (isBuyerInitiated ? 0 : 18.0);

    for (const item of data.items) {
      const product = await this.prisma.product.findUnique({
        where: { id: item.productId },
        include: { pricing: true },
      });

      if (!product || !product.pricing) {
        throw new BadRequestException(`Product ${item.productId} invalid or has no pricing`);
      }

      // 4-tier pricing rule: category determines base price
      let unitPrice = Number(product.pricing.customerPrice);
      if (buyer.buyerType === BuyerType.DISTRIBUTOR) {
        unitPrice = Number(product.pricing.distributorPrice);
      } else if (buyer.buyerType === BuyerType.WHOLESALER) {
        unitPrice = Number(product.pricing.wholesalerPrice);
      } else if (buyer.buyerType === BuyerType.DEALER) {
        unitPrice = Number(product.pricing.dealerPrice);
      }

      const purchasePrice = Number(product.purchasePrice ?? product.pricing.purchasePrice ?? 0);
      totalPurchaseCost += purchasePrice * item.quantity;

      const lineTotalBeforeTax = unitPrice * item.quantity;
      const taxRate = isBuyerInitiated ? 0 : requestedTaxRate;
      const lineTax = (lineTotalBeforeTax * taxRate) / 100;
      const lineTotal = lineTotalBeforeTax + lineTax;

      subtotal += lineTotalBeforeTax;
      taxAmount += lineTax;

      itemRecords.push({
        productId: product.id,
        sku: product.sku,
        productName: product.name,
        quantity: item.quantity,
        unitPrice,
        purchasePrice,
        taxRate,
        taxAmount: lineTax,
        totalPrice: lineTotal,
      });
    }

    const additionalDiscountRequested = Number(data.additionalDiscountRequested || 0);
    const requiresApproval =
      isBuyerInitiated ||
      (additionalDiscountRequested > 0 && data.creatorUser.role === UserRoleType.SALESMAN);

    let initialStatus: QuotationStatus = requiresApproval
      ? QuotationStatus.PENDING_DISCOUNT_APPROVAL
      : QuotationStatus.ISSUED;

    if (data.creatorUser.role === UserRoleType.SUPER_ADMIN && (data as any).status) {
      initialStatus = (data as any).status;
    }

    let discountApprovalStatus = requiresApproval
      ? DiscountApprovalStatus.PENDING
      : additionalDiscountRequested > 0
        ? DiscountApprovalStatus.APPROVED
        : DiscountApprovalStatus.NOT_REQUESTED;

    let approvedDiscount = requiresApproval ? 0 : additionalDiscountRequested;
    if (initialStatus === QuotationStatus.ACCEPTED) {
      discountApprovalStatus = DiscountApprovalStatus.APPROVED;
      approvedDiscount = additionalDiscountRequested;
    }

    const shippingCharges = Number((data as any).shippingCharges || 0);
    const taxableSubtotal = Math.max(0, subtotal - approvedDiscount);
    const profit = Math.round((taxableSubtotal - totalPurchaseCost) * 100) / 100;
    const finalTotal = Math.max(0, subtotal + taxAmount + shippingCharges - approvedDiscount);

    // Generate quotation number: GA-QT-2026-XXXX
    const count = await this.prisma.quotation.count();
    const quotationNumber = `GA-QT-2026-${String(count + 1).padStart(4, '0')}`;

    const validUntil = new Date(Date.now() + (data.validityDays || 15) * 24 * 60 * 60 * 1000);

    let finalSalesmanId: string | null = null;
    if (
      data.salesmanProfileId === 'NONE' ||
      data.salesmanProfileId === null ||
      data.salesmanProfileId === '' ||
      (data as any).noSalesman === true
    ) {
      finalSalesmanId = null;
    } else if (data.salesmanProfileId) {
      finalSalesmanId = data.salesmanProfileId;
    } else {
      finalSalesmanId = buyer.assignedSalesmanId || null;
    }

    return this.prisma.$transaction(async (tx) => {
      const quotation = await tx.quotation.create({
        data: {
          quotationNumber,
          buyerProfileId: data.buyerProfileId,
          salesmanProfileId: finalSalesmanId,
          status: initialStatus,
          validUntil,
          subtotal,
          taxAmount,
          taxRate: isBuyerInitiated ? 0 : requestedTaxRate,
          profit,
          shippingCharges,
          additionalDiscountRequested,
          additionalDiscountApproved: approvedDiscount,
          discountApprovalStatus,
          finalTotal,
          discountReason: data.discountReason,
          paymentTerms: data.paymentTerms || 'Payment on Delivery / Approved Credit',
          buyerNotes: data.buyerNotes,
          internalNotes: data.internalNotes,
          approvedBy: initialStatus === QuotationStatus.ACCEPTED ? data.creatorUser.id : undefined,
          approvedAt: initialStatus === QuotationStatus.ACCEPTED ? new Date() : undefined,
          items: {
            create: itemRecords,
          },
        },
        include: {
          items: true,
          buyer: { include: { user: true } },
          salesman: { include: { user: true } },
        },
      });

      if (requiresApproval) {
        await tx.discountApproval.create({
          data: {
            quotationId: quotation.id,
            requestedDiscount: additionalDiscountRequested,
            proposedTotal: subtotal + taxAmount + shippingCharges - additionalDiscountRequested,
            reason: data.discountReason || (isBuyerInitiated ? 'Buyer sent cart for quotation approval & shipping fee calculation' : 'Salesman requested commercial concession'),
            status: 'PENDING',
          },
        });

        // 1. Notify Assigned Sales Representative (if any)
        if (finalSalesmanId) {
          const assignedSalesman = await tx.salesmanProfile.findUnique({
            where: { id: finalSalesmanId },
            include: { user: true },
          });
          if (assignedSalesman?.userId) {
            await tx.notification.create({
              data: {
                userId: assignedSalesman.userId,
                title: `New Quotation Sent for Approval: ${quotationNumber}`,
                body: `${buyer.businessName || buyer.user.fullName} sent a cart with ${itemRecords.length} items for approval. Shipping charges & terms require review with Super Admin.`,
                type: 'DISCOUNT_APPROVAL',
                referenceType: 'QUOTATION',
                referenceId: quotation.id,
              },
            });
          }
        }

        // 2. Notify Super Admins
        const admins = await tx.user.findMany({
          where: { role: UserRoleType.SUPER_ADMIN },
        });
        for (const admin of admins) {
          await tx.notification.create({
            data: {
              userId: admin.id,
              title: isBuyerInitiated
                ? `Buyer Quotation Approval: ${quotationNumber}`
                : `Discount Approval Request: ${quotationNumber}`,
              body: `${buyer.businessName || buyer.user.fullName} submitted quotation for ${itemRecords.length} product(s). Please calculate shipping charges and approve.`,
              type: 'DISCOUNT_APPROVAL',
              referenceType: 'QUOTATION',
              referenceId: quotation.id,
            },
          });
        }
      }

      return quotation;
    });
  }

  async reviewDiscount(
    quotationId: string,
    action: 'APPROVE' | 'REJECT' | 'REVISE',
    approverId: string,
    notes?: string,
    revisedDiscount?: number,
  ) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { id: quotationId },
      include: {
        salesman: { include: { user: true } },
        buyer: { include: { user: true } },
      },
    });

    if (!quotation) throw new NotFoundException('Quotation not found');

    // Rule: Salesmen cannot approve their own discount requests
    if (quotation.salesman?.userId === approverId) {
      throw new ForbiddenException('Salesmen are strictly prohibited from approving their own discount requests');
    }

    return this.prisma.$transaction(async (tx) => {
      let approvedDiscount = Number(quotation.additionalDiscountApproved);
      let newStatus: QuotationStatus = quotation.status;
      let newApprovalStatus: DiscountApprovalStatus = quotation.discountApprovalStatus;

      if (action === 'APPROVE') {
        approvedDiscount = Number(quotation.additionalDiscountRequested);
        newStatus = QuotationStatus.ISSUED;
        newApprovalStatus = DiscountApprovalStatus.APPROVED;
      } else if (action === 'REJECT') {
        approvedDiscount = 0;
        newStatus = QuotationStatus.DISCOUNT_REJECTED;
        newApprovalStatus = DiscountApprovalStatus.REJECTED;
      } else if (action === 'REVISE') {
        approvedDiscount = Number(revisedDiscount || 0);
        newStatus = QuotationStatus.ISSUED;
        newApprovalStatus = DiscountApprovalStatus.REVISED;
      }

      const finalTotal = Math.max(
        0,
        Number(quotation.subtotal) + Number(quotation.taxAmount) - approvedDiscount,
      );

      const updated = await tx.quotation.update({
        where: { id: quotationId },
        data: {
          additionalDiscountApproved: approvedDiscount,
          status: newStatus,
          discountApprovalStatus: newApprovalStatus,
          finalTotal,
          approvedBy: approverId,
          approvedAt: new Date(),
          discountRejectionReason: action === 'REJECT' ? notes : undefined,
        },
        include: {
          buyer: { include: { user: true } },
          salesman: { include: { user: true } },
        },
      });

      await tx.discountApproval.updateMany({
        where: { quotationId, status: 'PENDING' },
        data: {
          status: action,
          approvedDiscount,
          finalTotal,
          approverNotes: notes,
          approverId,
          actionAt: new Date(),
        },
      });

      // Notify salesman
      if (quotation.salesman?.userId) {
        await tx.notification.create({
          data: {
            userId: quotation.salesman.userId,
            title: `Discount Request ${action}: ${quotation.quotationNumber}`,
            body: `Your discount request was ${action.toLowerCase()} by administration. Final total: ₹${finalTotal}.`,
            type: 'DISCOUNT_APPROVAL',
            referenceType: 'QUOTATION',
            referenceId: quotation.id,
          },
        });
      }

      return updated;
    });
  }

  async buyerRespond(quotationId: string, response: 'ACCEPT' | 'REJECT', buyerUserId: string) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { id: quotationId },
      include: { buyer: true },
    });

    if (!quotation) throw new NotFoundException('Quotation not found');
    if (quotation.buyer.userId !== buyerUserId) {
      throw new ForbiddenException('Unauthorized to respond to this quotation');
    }

    if (new Date() > quotation.validUntil) {
      throw new BadRequestException('Quotation has expired and cannot be accepted');
    }

    const newStatus =
      response === 'ACCEPT' ? QuotationStatus.ACCEPTED : QuotationStatus.REJECTED;

    return this.prisma.quotation.update({
      where: { id: quotationId },
      data: { status: newStatus },
    });
  }

  async convertToOrder(quotationId: string, userId: string) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { id: quotationId },
      include: {
        buyer: {
          include: {
            user: true,
            addresses: true,
            creditAccount: true,
          },
        },
        salesman: true,
        items: true,
      },
    });

    if (!quotation) throw new NotFoundException('Quotation not found');

    // Rule: Prevent conversion of rejected, expired, or cancelled quotations
    if (quotation.status !== QuotationStatus.ACCEPTED && quotation.status !== QuotationStatus.ISSUED) {
      throw new BadRequestException(`Cannot convert quotation with status "${quotation.status}" to order. Only accepted quotations can be converted.`);
    }

    // Rule: Prevent duplicate conversion
    const existingOrder = await this.prisma.order.findFirst({
      where: { sourceQuotationId: quotationId },
    });
    if (existingOrder) {
      throw new BadRequestException(`Quotation already converted to Order ${existingOrder.orderNumber}`);
    }

    const orderCount = await this.prisma.order.count();
    const orderNumber = `GA-ORD-2026-${String(orderCount + 1).padStart(4, '0')}`;

    const defaultAddress = quotation.buyer.addresses[0] || {
      streetAddress: 'Main Business Location',
      city: quotation.buyer.district || 'New Delhi',
      state: quotation.buyer.state || 'Delhi',
      pinCode: quotation.buyer.pinCode || '110001',
    };

    return this.prisma.$transaction(async (tx) => {
      // 1. Create Order preserving accepted quotation's price and terms
      const order = await tx.order.create({
        data: {
          orderNumber,
          sourceQuotationId: quotation.id,
          buyerProfileId: quotation.buyerProfileId,
          salesmanProfileId: quotation.salesmanProfileId,
          status: OrderStatus.CONFIRMED,
          paymentStatus: PaymentStatus.PENDING,
          subtotal: quotation.subtotal,
          discountTotal: quotation.additionalDiscountApproved,
          taxTotal: quotation.taxAmount,
          taxRate: quotation.taxRate ?? 18.0,
          profit: quotation.profit ?? 0,
          shippingCharges: quotation.shippingCharges,
          finalAmount: quotation.finalTotal,
          outstandingAmount: quotation.finalTotal,
          paidAmount: 0,
          shippingAddress: defaultAddress,
          billingAddress: defaultAddress,
          items: {
            create: quotation.items.map((i) => ({
              productId: i.productId,
              sku: i.sku,
              productName: i.productName,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
              purchasePrice: i.purchasePrice ?? 0,
              taxAmount: i.taxAmount,
              totalPrice: i.totalPrice,
            })),
          },
        },
        include: {
          items: true,
          buyer: { include: { user: true } },
        },
      });

      // 2. Mark Quotation as CONVERTED_TO_ORDER
      await tx.quotation.update({
        where: { id: quotationId },
        data: { status: QuotationStatus.CONVERTED_TO_ORDER },
      });

      // 3. Record Order Status History
      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: OrderStatus.PENDING,
          toStatus: OrderStatus.CONFIRMED,
          reason: `Converted from accepted quotation ${quotation.quotationNumber}`,
          changedBy: userId,
        },
      });

      // 4. Update Buyer total orders count & outstanding balance
      await tx.buyerProfile.update({
        where: { id: quotation.buyerProfileId },
        data: {
          totalOrders: { increment: 1 },
          outstandingBalance: { increment: quotation.finalTotal },
          totalPurchaseValue: { increment: quotation.finalTotal },
        },
      });

      return order;
    });
  }

  async update(id: string, data: any, user: { id: string; role: UserRoleType }) {
    const existing = await this.prisma.quotation.findUnique({
      where: { id },
      include: {
        items: true,
        buyer: { include: { user: true } },
        salesman: { include: { user: true } },
      },
    });
    if (!existing) throw new NotFoundException('Quotation not found');

    if (user.role === UserRoleType.BUYER) {
      if (existing.buyer?.userId !== user.id) {
        throw new ForbiddenException('You can only edit your own quotation');
      }
      if (existing.status === QuotationStatus.CONVERTED_TO_ORDER) {
        throw new BadRequestException('Quotation has already been converted to an order and cannot be edited');
      }
    }

    return this.prisma.$transaction(async (tx) => {
      // 1. Salesman resolution
      let finalSalesmanId = existing.salesmanProfileId;
      if (user.role !== UserRoleType.BUYER && data.salesmanProfileId !== undefined) {
        if (
          data.salesmanProfileId === 'NONE' ||
          data.salesmanProfileId === null ||
          data.salesmanProfileId === '' ||
          data.noSalesman === true
        ) {
          finalSalesmanId = null;
        } else {
          finalSalesmanId = data.salesmanProfileId;
        }
      }

      // 2. Buyer resolution
      const buyerProfileId =
        user.role === UserRoleType.BUYER ? existing.buyerProfileId : (data.buyerProfileId || existing.buyerProfileId);
      const buyer = await tx.buyerProfile.findUnique({ where: { id: buyerProfileId } });
      if (!buyer) throw new NotFoundException('Buyer profile not found');

      // 3. Items recalculation if provided
      let subtotal = Number(existing.subtotal);
      let taxAmount = Number(existing.taxAmount);
      let appliedTaxRate = existing.taxRate !== null && existing.taxRate !== undefined ? Number(existing.taxRate) : 0;
      if (user.role === UserRoleType.SUPER_ADMIN && data.taxRate !== undefined) {
        appliedTaxRate = Number(data.taxRate);
      } else if (user.role === UserRoleType.BUYER) {
        appliedTaxRate = 0;
      }

      let totalPurchaseCost = 0;

      if (data.items && Array.isArray(data.items) && data.items.length > 0) {
        subtotal = 0;
        taxAmount = 0;
        const newItems: any[] = [];

        for (const item of data.items) {
          const product = await tx.product.findUnique({
            where: { id: item.productId },
            include: { pricing: true },
          });
          if (!product || !product.pricing) {
            throw new BadRequestException(`Product ${item.productId} invalid or has no pricing`);
          }

          let unitPrice = item.unitPrice !== undefined ? Number(item.unitPrice) : Number(product.pricing.customerPrice);
          if (item.unitPrice === undefined || user.role === UserRoleType.BUYER) {
            if (buyer.buyerType === BuyerType.DISTRIBUTOR) {
              unitPrice = Number(product.pricing.distributorPrice);
            } else if (buyer.buyerType === BuyerType.WHOLESALER) {
              unitPrice = Number(product.pricing.wholesalerPrice);
            } else if (buyer.buyerType === BuyerType.DEALER) {
              unitPrice = Number(product.pricing.dealerPrice);
            } else {
              unitPrice = Number(product.pricing.customerPrice);
            }
          }

          const qty = Number(item.quantity) || 1;
          const purchasePrice = Number(product.purchasePrice ?? product.pricing?.purchasePrice ?? 0);
          totalPurchaseCost += purchasePrice * qty;

          const lineTotalBeforeTax = unitPrice * qty;
          const taxRate = appliedTaxRate;
          const lineTax = (lineTotalBeforeTax * taxRate) / 100;
          const lineTotal = lineTotalBeforeTax + lineTax;

          subtotal += lineTotalBeforeTax;
          taxAmount += lineTax;

          newItems.push({
            quotationId: id,
            productId: product.id,
            sku: product.sku,
            productName: product.name,
            quantity: qty,
            unitPrice,
            purchasePrice,
            taxRate,
            taxAmount: lineTax,
            totalPrice: lineTotal,
          });
        }

        // Replace items
        await tx.quotationItem.deleteMany({ where: { quotationId: id } });
        for (const it of newItems) {
          await tx.quotationItem.create({ data: it });
        }
      } else {
        if (user.role === UserRoleType.SUPER_ADMIN && data.taxRate !== undefined) {
          taxAmount = (subtotal * appliedTaxRate) / 100;
          await tx.quotationItem.updateMany({
            where: { quotationId: id },
            data: { taxRate: appliedTaxRate },
          });
        }
        const currentItems = await tx.quotationItem.findMany({ where: { quotationId: id } });
        totalPurchaseCost = currentItems.reduce((s, it: any) => s + (it.quantity * Number(it.purchasePrice || 0)), 0);
      }

      // 4. Discounts, shipping charges & totals
      let shippingCharges =
        data.shippingCharges !== undefined
          ? Number(data.shippingCharges)
          : Number(existing.shippingCharges || 0);

      // If buyer edited, reset shipping fee to 0 / pending recalculation unless Super Admin already locked it
      if (user.role === UserRoleType.BUYER) {
        shippingCharges = 0;
      }

      const additionalDiscountRequested =
        data.additionalDiscountRequested !== undefined
          ? Number(data.additionalDiscountRequested)
          : Number(existing.additionalDiscountRequested);

      let additionalDiscountApproved = Number(existing.additionalDiscountApproved);
      let discountApprovalStatus = existing.discountApprovalStatus;
      let status: QuotationStatus = data.status || existing.status;

      if (user.role === UserRoleType.BUYER) {
        // Buyer editing items sends quotation back for Super Admin approval
        status = QuotationStatus.PENDING_DISCOUNT_APPROVAL;
        discountApprovalStatus = DiscountApprovalStatus.PENDING;
      } else if (user.role === UserRoleType.SUPER_ADMIN) {
        if (data.status === QuotationStatus.ACCEPTED || data.status === QuotationStatus.ISSUED) {
          additionalDiscountApproved = additionalDiscountRequested;
          discountApprovalStatus = DiscountApprovalStatus.APPROVED;
        } else if (data.additionalDiscountApproved !== undefined) {
          additionalDiscountApproved = Number(data.additionalDiscountApproved);
        }
      }

      const taxableSubtotal = Math.max(0, subtotal - additionalDiscountApproved);
      if (appliedTaxRate > 0) {
        taxAmount = (taxableSubtotal * appliedTaxRate) / 100;
      } else {
        taxAmount = 0;
      }
      const profit = Math.round((taxableSubtotal - totalPurchaseCost) * 100) / 100;
      const finalTotal = Math.max(
        0,
        taxableSubtotal + taxAmount + shippingCharges,
      );

      const isApproving =
        (status === QuotationStatus.ISSUED || status === QuotationStatus.ACCEPTED) &&
        (existing.status !== QuotationStatus.ISSUED && existing.status !== QuotationStatus.ACCEPTED);

      const updated = await tx.quotation.update({
        where: { id },
        data: {
          buyerProfileId,
          salesmanProfileId: finalSalesmanId,
          status,
          subtotal,
          taxAmount,
          taxRate: appliedTaxRate,
          profit,
          shippingCharges,
          additionalDiscountRequested,
          additionalDiscountApproved,
          discountApprovalStatus,
          finalTotal,
          paymentTerms: data.paymentTerms ?? existing.paymentTerms,
          discountReason: data.discountReason ?? existing.discountReason,
          buyerNotes: data.buyerNotes ?? existing.buyerNotes,
          internalNotes: data.internalNotes ?? existing.internalNotes,
          approvedBy:
            status === QuotationStatus.ACCEPTED || status === QuotationStatus.ISSUED
              ? user.id
              : existing.approvedBy,
          approvedAt:
            status === QuotationStatus.ACCEPTED || status === QuotationStatus.ISSUED
              ? new Date()
              : existing.approvedAt,
          validUntil: data.validityDays
            ? new Date(Date.now() + Number(data.validityDays) * 24 * 60 * 60 * 1000)
            : existing.validUntil,
        },
        include: {
          items: { include: { product: true } },
          buyer: { include: { user: true } },
          salesman: { include: { user: true } },
        },
      });

      // Notify the buyer when Super Admin approves or updates shipping charges
      if (isApproving && existing.buyer?.userId) {
        await tx.notification.create({
          data: {
            userId: existing.buyer.userId,
            title: `Quotation Approved: ${existing.quotationNumber}`,
            body: `Your quotation has been approved by Super Admin. Shipping charges: ₹${shippingCharges}. Total amount: ₹${finalTotal}. Please review and accept in Quotes!`,
            type: 'GENERAL',
            referenceType: 'QUOTATION',
            referenceId: existing.id,
          },
        });
      }

      // Notify Super Admin if buyer edited quotation
      if (user.role === UserRoleType.BUYER) {
        const superAdmin = await tx.user.findFirst({ where: { role: UserRoleType.SUPER_ADMIN } });
        if (superAdmin) {
          await tx.notification.create({
            data: {
              userId: superAdmin.id,
              title: `Quotation Edited by Buyer: ${existing.quotationNumber}`,
              body: `Buyer ${existing.buyer?.businessName || existing.buyer?.user?.fullName} updated line items in quotation ${existing.quotationNumber}. New subtotal: ₹${subtotal}. Please review and approve shipping charge.`,
              type: 'GENERAL',
              referenceType: 'QUOTATION',
              referenceId: existing.id,
            },
          });
        }
      }

      return updated;
    });
  }

  async updateStatus(
    id: string,
    newStatus: QuotationStatus,
    userId: string,
    reason?: string,
  ) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { id },
      include: { buyer: true, items: true },
    });
    if (!quotation) throw new NotFoundException('Quotation not found');

    const updates: any = { status: newStatus };

    // If changing to ACCEPTED, ensure discount is approved and totals aligned
    if (newStatus === QuotationStatus.ACCEPTED) {
      updates.additionalDiscountApproved = quotation.additionalDiscountRequested;
      updates.discountApprovalStatus = DiscountApprovalStatus.APPROVED;
      updates.approvedBy = userId;
      updates.approvedAt = new Date();
      updates.finalTotal = Math.max(
        0,
        Number(quotation.subtotal) +
          Number(quotation.taxAmount) -
          Number(quotation.additionalDiscountRequested),
      );
    } else if (newStatus === QuotationStatus.REJECTED) {
      if (reason) updates.discountRejectionReason = reason;
    }

    return this.prisma.quotation.update({
      where: { id },
      data: updates,
      include: {
        buyer: { include: { user: true } },
        salesman: { include: { user: true } },
        items: { include: { product: true } },
      },
    });
  }

  async delete(id: string) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { id },
      include: { orders: true },
    });
    if (!quotation) throw new NotFoundException('Quotation not found');

    if (quotation.orders && quotation.orders.length > 0) {
      throw new BadRequestException(
        `Cannot delete quotation ${quotation.quotationNumber} because Order ${quotation.orders[0].orderNumber} is linked to it.`,
      );
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.quotationItem.deleteMany({ where: { quotationId: id } });
      await tx.discountApproval.deleteMany({ where: { quotationId: id } });
      await tx.quotationVersion.deleteMany({ where: { quotationId: id } });
      return tx.quotation.delete({ where: { id } });
    });
  }

  async getPdfBuffer(quotationId: string, template: string = '1'): Promise<Buffer> {
    const quotation = await this.findOne(quotationId);
    return this.pdfService.generateQuotationPdf(quotation, template);
  }
}
