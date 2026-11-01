import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { BuyerType, LoyaltyTierLevel, AccountStatus, UserRoleType } from '@prisma/client';

@Injectable()
export class BuyersService {
  constructor(private prisma: PrismaService) {}

  async findAll(query: {
    buyerType?: BuyerType;
    loyaltyTier?: LoyaltyTierLevel;
    assignedSalesmanId?: string;
    accountStatus?: AccountStatus;
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query.page) || 1;
    const limit = Number(query.limit) || 20;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query.buyerType) where.buyerType = query.buyerType;
    if (query.loyaltyTier) where.loyaltyTier = query.loyaltyTier;
    if (query.assignedSalesmanId) where.assignedSalesmanId = query.assignedSalesmanId;
    if (query.accountStatus) where.accountStatus = query.accountStatus;

    if (query.search) {
      where.OR = [
        { buyerId: { contains: query.search, mode: 'insensitive' } },
        { businessName: { contains: query.search, mode: 'insensitive' } },
        { user: { fullName: { contains: query.search, mode: 'insensitive' } } },
        { user: { username: { contains: query.search, mode: 'insensitive' } } },
        { user: { phone: { contains: query.search, mode: 'insensitive' } } },
        { user: { email: { contains: query.search, mode: 'insensitive' } } },
      ];
    }

    if (!this.prisma.isConnected) {
      return this.getMockBuyers(query.buyerType);
    }

    try {
      const [total, buyers] = await Promise.all([
        this.prisma.buyerProfile.count({ where }),
        this.prisma.buyerProfile.findMany({
          where,
          skip,
          take: limit,
          include: {
            user: true,
            assignedSalesman: {
              include: { user: true },
            },
            creditAccount: true,
            _count: {
              select: { orders: true, quotations: true },
            },
          },
          orderBy: { createdAt: 'desc' },
        }),
      ]);

      const enrichedBuyers = buyers.map((b) => ({
        ...b,
        dueSummary: this.calculateDueSummary(b),
      }));

      return {
        buyers: enrichedBuyers,
        pagination: {
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit),
        },
      };
    } catch (err) {
      return this.getMockBuyers(query.buyerType);
    }
  }

  calculateDueSummary(buyer: any) {
    const creditDays = buyer.creditDays ?? buyer.creditAccount?.paymentTermsDays ?? 30;
    const creditLimit = Number(buyer.creditLimit ?? buyer.creditAccount?.creditLimit ?? 0);
    const availableCredit = Number(buyer.creditAccount?.availableCredit ?? (creditLimit - Number(buyer.outstandingBalance ?? 0)));

    let outstandingAmount = Number(buyer.outstandingBalance ?? 0);
    if (buyer.creditAccount && Number(buyer.creditAccount.utilizedCredit) > 0) {
      outstandingAmount = Math.max(outstandingAmount, Number(buyer.creditAccount.utilizedCredit));
    }

    const unpaidOrders = (buyer.orders || []).filter(
      (o: any) => o.paymentStatus !== 'PAID' && o.status !== 'CANCELLED',
    );
    const orderOutstanding = unpaidOrders.reduce(
      (sum: number, o: any) =>
        sum +
        (Number(o.outstandingAmount) ||
          Math.max(0, Number(o.finalAmount || 0) - Number(o.paidAmount || 0))),
      0,
    );
    if (orderOutstanding > 0) {
      outstandingAmount = Math.max(outstandingAmount, orderOutstanding);
    }

    let oldestUnpaidDate: Date | null = null;
    if (unpaidOrders.length > 0) {
      const dates = unpaidOrders
        .map((o: any) => new Date(o.createdAt))
        .filter((d: Date) => !isNaN(d.getTime()))
        .sort((a: Date, b: Date) => a.getTime() - b.getTime());
      if (dates.length > 0) oldestUnpaidDate = dates[0];
    }

    let daysLeft: number | null = null;
    let dueDate: Date | null = null;
    let isOverdue = false;
    let statusText = 'No Pending Dues';

    if (outstandingAmount > 0) {
      const baseDate = oldestUnpaidDate || new Date(buyer.updatedAt || buyer.createdAt || Date.now());
      dueDate = new Date(baseDate.getTime() + creditDays * 24 * 60 * 60 * 1000);
      const msDiff = dueDate.getTime() - Date.now();
      daysLeft = Math.ceil(msDiff / (1000 * 60 * 60 * 24));
      if (daysLeft < 0) {
        isOverdue = true;
        statusText = `Overdue by ${Math.abs(daysLeft)} days`;
      } else if (daysLeft === 0) {
        statusText = 'Due Today';
      } else {
        statusText = `${daysLeft} days left`;
      }
    }

    return {
      outstandingAmount,
      creditLimit,
      availableCredit: Math.max(0, availableCredit),
      creditDays,
      paymentTermsDays: creditDays,
      oldestUnpaidDate,
      dueDate,
      daysLeft,
      isOverdue,
      statusText,
    };
  }

  private getMockBuyers(type?: BuyerType) {
    const all = [
      {
        id: 'b-1',
        buyerId: 'BUY-DIS-001',
        businessName: 'Apex Water Systems Pvt Ltd',
        buyerType: 'DISTRIBUTOR',
        loyaltyTier: 'DIAMOND',
        accountStatus: 'ACTIVE',
        user: { fullName: 'Rajesh Verma', email: 'rajesh@apexwater.com', phone: '+919811122233' },
        assignedSalesman: { user: { fullName: 'Amit Sharma' } },
        creditAccount: { creditLimit: 2000000, currentBalance: 350000, availableCredit: 1650000 },
        _count: { orders: 24, quotations: 28 },
        dueSummary: { outstandingAmount: 350000, daysLeft: 12, isOverdue: false, statusText: '12 days left', paymentTermsDays: 30 },
      },
      {
        id: 'b-2',
        buyerId: 'BUY-WHO-002',
        businessName: 'National RO Spares & Machinery',
        buyerType: 'WHOLESALER',
        loyaltyTier: 'PLATINUM',
        accountStatus: 'ACTIVE',
        user: { fullName: 'Suresh Patel', email: 'suresh@nationalro.com', phone: '+919822233344' },
        assignedSalesman: { user: { fullName: 'Amit Sharma' } },
        creditAccount: { creditLimit: 1000000, currentBalance: 180000, availableCredit: 820000 },
        _count: { orders: 18, quotations: 21 },
        dueSummary: { outstandingAmount: 180000, daysLeft: -3, isOverdue: true, statusText: 'Overdue by 3 days', paymentTermsDays: 30 },
      },
      {
        id: 'b-3',
        buyerId: 'BUY-DEA-003',
        businessName: 'Aqua Pure Care & Retail',
        buyerType: 'DEALER',
        loyaltyTier: 'GOLD',
        accountStatus: 'ACTIVE',
        user: { fullName: 'Vikram Joshi', email: 'vikram@aquapurecare.in', phone: '+919833344455' },
        assignedSalesman: { user: { fullName: 'Pooja Iyer' } },
        creditAccount: { creditLimit: 300000, currentBalance: 45000, availableCredit: 255000 },
        _count: { orders: 12, quotations: 15 },
        dueSummary: { outstandingAmount: 45000, daysLeft: 7, isOverdue: false, statusText: '7 days left', paymentTermsDays: 30 },
      },
      {
        id: 'b-4',
        buyerId: 'BUY-CUS-004',
        businessName: 'Individual Customer',
        buyerType: 'CUSTOMER',
        loyaltyTier: 'NONE',
        accountStatus: 'ACTIVE',
        user: { fullName: 'Anita Singh', email: 'anita.singh@gmail.com', phone: '+919844455566' },
        assignedSalesman: null,
        creditAccount: null,
        _count: { orders: 2, quotations: 2 },
        dueSummary: { outstandingAmount: 0, daysLeft: null, isOverdue: false, statusText: 'No Pending Dues', paymentTermsDays: 30 },
      },
    ];

    const filtered = type ? all.filter((b) => b.buyerType === type) : all;
    return {
      buyers: filtered,
      pagination: { total: filtered.length, page: 1, limit: 20, totalPages: 1 },
    };
  }

  async findOne(id: string) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id },
      include: {
        user: true,
        addresses: true,
        assignedSalesman: {
          include: { user: true },
        },
        creditAccount: {
          include: {
            transactions: {
              orderBy: { createdAt: 'desc' },
              take: 20,
            },
          },
        },
        quotations: {
          orderBy: { createdAt: 'desc' },
          take: 10,
        },
        orders: {
          orderBy: { createdAt: 'desc' },
          take: 50,
          include: {
            items: {
              include: {
                product: true,
              },
            },
          },
        },
        payments: {
          orderBy: { paymentDate: 'desc' },
          take: 50,
        },
        typeHistory: {
          orderBy: { changedAt: 'desc' },
        },
        loyaltyHistory: {
          orderBy: { changedAt: 'desc' },
        },
        voucherRedemptions: {
          include: { voucher: true },
        },
      },
    });

    if (!buyer) {
      throw new NotFoundException(`Buyer with ID "${id}" not found`);
    }

    const dueSummary = this.calculateDueSummary(buyer);

    return {
      ...buyer,
      dueSummary,
    };
  }

  async create(dto: {
    fullName: string;
    username?: string;
    phone: string;
    email?: string;
    password?: string;
    businessName?: string;
    businessType?: string;
    gstin?: string;
    billingAddress?: string;
    shippingAddress?: string;
    district?: string;
    state?: string;
    pinCode?: string;
    buyerType?: BuyerType;
    loyaltyTier?: LoyaltyTierLevel;
    creditLimit?: number;
    creditDays?: number;
    ownerPhoto?: string;
    shopPhoto?: string;
    assignedSalesmanId?: string;
  }, adminId?: string) {
    if (!dto.fullName || !dto.phone) {
      throw new BadRequestException('Full name and mobile number are required');
    }

    if (dto.username && dto.username.trim()) {
      const cleanUsername = dto.username.trim().toLowerCase();
      const existingUser = await this.prisma.user.findUnique({ where: { username: cleanUsername } });
      if (existingUser) {
        throw new BadRequestException(`Username '${dto.username}' is already taken`);
      }
    }

    const existingPhone = await this.prisma.user.findUnique({ where: { phone: dto.phone.trim() } });
    if (existingPhone) {
      throw new BadRequestException(`A user with phone ${dto.phone} already exists`);
    }
    if (dto.email && dto.email.trim()) {
      const existingEmail = await this.prisma.user.findUnique({ where: { email: dto.email.trim().toLowerCase() } });
      if (existingEmail) {
        throw new BadRequestException(`A user with email ${dto.email} already exists`);
      }
    }

    const salt = await bcrypt.genSalt(10);
    const password = dto.password || 'GrandAqua@Buyer2026';
    const passwordHash = await bcrypt.hash(password, salt);

    const buyerCode = `GA-B-${Math.floor(1000 + Math.random() * 9000)}`;
    const buyerType = dto.buyerType || BuyerType.CUSTOMER;
    const loyaltyTier = dto.loyaltyTier || LoyaltyTierLevel.NONE;
    const creditLimit = Number(dto.creditLimit) || 0;
    const creditDays = Number(dto.creditDays) || 30;

    return this.prisma.$transaction(async (tx) => {
      // 1. Create User
      const user = await tx.user.create({
        data: {
          fullName: dto.fullName.trim(),
          username: dto.username && dto.username.trim() ? dto.username.trim().toLowerCase() : null,
          phone: dto.phone.trim(),
          email: dto.email ? dto.email.trim().toLowerCase() : null,
          passwordHash,
          role: UserRoleType.BUYER,
          profilePhoto: dto.ownerPhoto || null,
        },
      });

      // 2. Create BuyerProfile
      const buyerProfile = await tx.buyerProfile.create({
        data: {
          buyerId: buyerCode,
          userId: user.id,
          businessName: dto.businessName?.trim() || dto.fullName.trim(),
          businessType: dto.businessType?.trim() || 'Retail Customer / Dealer',
          gstin: dto.gstin?.trim() || null,
          billingAddress: dto.billingAddress?.trim() || null,
          shippingAddress: dto.shippingAddress?.trim() || dto.billingAddress?.trim() || null,
          district: dto.district?.trim() || null,
          state: dto.state?.trim() || null,
          pinCode: dto.pinCode?.trim() || null,
          buyerType,
          loyaltyTier,
          creditLimit,
          outstandingBalance: 0,
          creditDays,
          ownerPhoto: dto.ownerPhoto || null,
          shopPhoto: dto.shopPhoto || null,
          assignedSalesmanId: dto.assignedSalesmanId || null,
          verificationStatus: 'VERIFIED',
          accountStatus: AccountStatus.ACTIVE,
        },
        include: {
          user: true,
          assignedSalesman: { include: { user: true } },
        },
      });

      // 3. Create initial CreditAccount
      await tx.creditAccount.create({
        data: {
          buyerProfileId: buyerProfile.id,
          creditLimit,
          utilizedCredit: 0,
          availableCredit: creditLimit,
          paymentTermsDays: creditDays,
          status: 'ACTIVE',
        },
      });

      // 4. Audit Log
      if (adminId) {
        await tx.auditLog.create({
          data: {
            actorId: adminId,
            actorType: 'ADMIN',
            action: 'CREATE_BUYER',
            module: 'buyers',
            entityId: buyerProfile.id,
            afterState: { buyerCode, buyerType, loyaltyTier, creditLimit },
          },
        });
      }

      return buyerProfile;
    });
  }

  async update(id: string, dto: {
    fullName?: string;
    username?: string;
    phone?: string;
    email?: string;
    password?: string;
    businessName?: string;
    businessType?: string;
    gstin?: string;
    billingAddress?: string;
    shippingAddress?: string;
    district?: string;
    state?: string;
    pinCode?: string;
    buyerType?: BuyerType;
    loyaltyTier?: LoyaltyTierLevel;
    creditLimit?: number;
    creditDays?: number;
    ownerPhoto?: string;
    shopPhoto?: string;
    assignedSalesmanId?: string;
    accountStatus?: AccountStatus;
  }, adminId?: string) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id },
      include: { user: true, creditAccount: true },
    });
    if (!buyer) throw new NotFoundException('Buyer profile not found');

    if (dto.username !== undefined) {
      const cleanUsername = dto.username ? dto.username.trim().toLowerCase() : null;
      if (cleanUsername && cleanUsername !== buyer.user?.username) {
        const existing = await this.prisma.user.findUnique({ where: { username: cleanUsername } });
        if (existing && existing.id !== buyer.userId) {
          throw new BadRequestException(`Username '${dto.username}' already belongs to another user`);
        }
      }
    }

    if (dto.phone && dto.phone.trim() !== buyer.user?.phone) {
      const existing = await this.prisma.user.findUnique({ where: { phone: dto.phone.trim() } });
      if (existing && existing.id !== buyer.userId) {
        throw new BadRequestException(`Phone ${dto.phone} already belongs to another user`);
      }
    }
    if (dto.email && dto.email.trim() && dto.email.trim().toLowerCase() !== buyer.user?.email) {
      const existing = await this.prisma.user.findUnique({ where: { email: dto.email.trim().toLowerCase() } });
      if (existing && existing.id !== buyer.userId) {
        throw new BadRequestException(`Email ${dto.email} already belongs to another user`);
      }
    }

    const creditLimit = dto.creditLimit !== undefined ? Number(dto.creditLimit) : buyer.creditLimit;
    const creditDays = dto.creditDays !== undefined ? Number(dto.creditDays) : (buyer.creditDays || 30);

    let passwordHash: string | undefined = undefined;
    if (dto.password && dto.password.trim()) {
      const salt = await bcrypt.genSalt(10);
      passwordHash = await bcrypt.hash(dto.password.trim(), salt);
    }

    return this.prisma.$transaction(async (tx) => {
      // 1. Update User
      await tx.user.update({
        where: { id: buyer.userId },
        data: {
          fullName: dto.fullName?.trim() || buyer.user?.fullName,
          username: dto.username !== undefined ? (dto.username ? dto.username.trim().toLowerCase() : null) : buyer.user?.username,
          phone: dto.phone?.trim() || buyer.user?.phone,
          email: dto.email !== undefined ? (dto.email ? dto.email.trim().toLowerCase() : null) : buyer.user?.email,
          profilePhoto: dto.ownerPhoto !== undefined ? dto.ownerPhoto : buyer.user?.profilePhoto,
          ...(passwordHash ? { passwordHash } : {}),
        },
      });

      // 2. Update BuyerProfile
      const updated = await tx.buyerProfile.update({
        where: { id },
        data: {
          businessName: dto.businessName !== undefined ? dto.businessName.trim() : buyer.businessName,
          businessType: dto.businessType !== undefined ? dto.businessType.trim() : buyer.businessType,
          gstin: dto.gstin !== undefined ? (dto.gstin ? dto.gstin.trim() : null) : buyer.gstin,
          billingAddress: dto.billingAddress !== undefined ? dto.billingAddress.trim() : buyer.billingAddress,
          shippingAddress: dto.shippingAddress !== undefined ? dto.shippingAddress.trim() : buyer.shippingAddress,
          district: dto.district !== undefined ? dto.district.trim() : buyer.district,
          state: dto.state !== undefined ? dto.state.trim() : buyer.state,
          pinCode: dto.pinCode !== undefined ? dto.pinCode.trim() : buyer.pinCode,
          buyerType: dto.buyerType || buyer.buyerType,
          loyaltyTier: dto.loyaltyTier || buyer.loyaltyTier,
          creditLimit,
          creditDays,
          ownerPhoto: dto.ownerPhoto !== undefined ? dto.ownerPhoto : buyer.ownerPhoto,
          shopPhoto: dto.shopPhoto !== undefined ? dto.shopPhoto : buyer.shopPhoto,
          assignedSalesmanId: dto.assignedSalesmanId !== undefined ? (dto.assignedSalesmanId || null) : buyer.assignedSalesmanId,
          accountStatus: dto.accountStatus || buyer.accountStatus,
        },
        include: {
          user: true,
          assignedSalesman: { include: { user: true } },
          creditAccount: true,
        },
      });

      // 3. Update CreditAccount if exists
      if (buyer.creditAccount) {
        const utilized = Number(buyer.creditAccount.utilizedCredit) || 0;
        await tx.creditAccount.update({
          where: { id: buyer.creditAccount.id },
          data: {
            creditLimit,
            paymentTermsDays: creditDays,
            availableCredit: Math.max(0, creditLimit - utilized),
          },
        });
      }

      if (adminId) {
        await tx.auditLog.create({
          data: {
            actorId: adminId,
            actorType: 'ADMIN',
            action: 'UPDATE_BUYER',
            module: 'buyers',
            entityId: id,
            afterState: { creditLimit, buyerType: dto.buyerType, loyaltyTier: dto.loyaltyTier },
          },
        });
      }

      return updated;
    });
  }

  async remove(id: string, adminId?: string) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id },
      include: {
        creditAccount: true,
        orders: { where: { status: { notIn: ['DELIVERED', 'CANCELLED'] } } },
      },
    });
    if (!buyer) throw new NotFoundException('Buyer profile not found');

    if (buyer.orders && buyer.orders.length > 0) {
      throw new BadRequestException('Cannot delete buyer with pending active orders. Please fulfill or cancel orders first.');
    }

    return this.prisma.$transaction(async (tx) => {
      if (buyer.creditAccount) {
        await tx.creditTransaction.deleteMany({ where: { creditAccountId: buyer.creditAccount.id } });
      }
      await tx.creditAccount.deleteMany({ where: { buyerProfileId: id } });
      await tx.buyerAddress.deleteMany({ where: { buyerProfileId: id } });
      await tx.buyerTypeHistory.deleteMany({ where: { buyerProfileId: id } });
      await tx.loyaltyHistory.deleteMany({ where: { buyerProfileId: id } });
      await tx.buyerAssignmentHistory.deleteMany({ where: { buyerProfileId: id } });

      await tx.buyerProfile.delete({ where: { id } });
      if (buyer.userId) {
        await tx.user.delete({ where: { id: buyer.userId } });
      }

      if (adminId) {
        await tx.auditLog.create({
          data: {
            actorId: adminId,
            actorType: 'ADMIN',
            action: 'DELETE_BUYER',
            module: 'buyers',
            entityId: id,
          },
        });
      }

      return { success: true, message: 'Buyer profile deleted successfully' };
    });
  }

  async promoteOrChangeBuyerType(
    buyerProfileId: string,
    dto: {
      newType: BuyerType;
      reason: string;
      changedByAdminId: string;
      notifySalesman?: boolean;
    },
  ) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id: buyerProfileId },
      include: { user: true, assignedSalesman: { include: { user: true } } },
    });

    if (!buyer) {
      throw new NotFoundException('Buyer profile not found');
    }

    if (buyer.buyerType === dto.newType) {
      throw new BadRequestException(`Buyer is already a ${dto.newType}`);
    }

    const previousType = buyer.buyerType;

    return this.prisma.$transaction(async (tx) => {
      // 1. Update buyer profile
      const updated = await tx.buyerProfile.update({
        where: { id: buyerProfileId },
        data: {
          buyerType: dto.newType,
        },
        include: { user: true },
      });

      // 2. Record in BuyerTypeHistory
      await tx.buyerTypeHistory.create({
        data: {
          buyerProfileId,
          previousType,
          newType: dto.newType,
          reason: dto.reason,
          changedBy: dto.changedByAdminId,
        },
      });

      // 3. Record in central AuditLog
      await tx.auditLog.create({
        data: {
          actorId: dto.changedByAdminId,
          actorType: 'ADMIN',
          action: 'CHANGE_BUYER_TYPE',
          module: 'buyers',
          entityId: buyerProfileId,
          beforeState: { buyerType: previousType },
          afterState: { buyerType: dto.newType, reason: dto.reason },
        },
      });

      // 4. Send in-app notification to the buyer
      await tx.notification.create({
        data: {
          userId: buyer.userId,
          title: 'Account Category Updated',
          body: `Your Grand Aqua business account has been updated to ${dto.newType}. Your product catalogue and checkout pricing will reflect your new category rates.`,
          type: 'BUYER_TYPE_CHANGE',
          referenceType: 'BUYER',
          referenceId: buyerProfileId,
        },
      });

      // 5. Notify assigned salesman if applicable
      if (buyer.assignedSalesman?.userId) {
        await tx.notification.create({
          data: {
            userId: buyer.assignedSalesman.userId,
            title: 'Assigned Shop Category Changed',
            body: `${buyer.businessName || buyer.user.fullName} has been updated to ${dto.newType}. Future quotations will use ${dto.newType} pricing.`,
            type: 'BUYER_TYPE_CHANGE',
            referenceType: 'BUYER',
            referenceId: buyerProfileId,
          },
        });
      }

      return updated;
    });
  }

  async changeLoyaltyTier(
    buyerProfileId: string,
    dto: {
      newTier: LoyaltyTierLevel;
      reason: string;
      effectiveDate?: Date;
      expiryDate?: Date;
      changedByAdminId: string;
    },
  ) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id: buyerProfileId },
      include: { user: true, assignedSalesman: { include: { user: true } } },
    });

    if (!buyer) {
      throw new NotFoundException('Buyer profile not found');
    }

    const previousTier = buyer.loyaltyTier;

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.buyerProfile.update({
        where: { id: buyerProfileId },
        data: { loyaltyTier: dto.newTier },
        include: { user: true },
      });

      await tx.loyaltyHistory.create({
        data: {
          buyerProfileId,
          fromTier: previousTier,
          toTier: dto.newTier,
          reason: dto.reason,
          changedBy: dto.changedByAdminId,
        },
      });

      await tx.auditLog.create({
        data: {
          actorId: dto.changedByAdminId,
          actorType: 'ADMIN',
          action: 'CHANGE_LOYALTY_TIER',
          module: 'loyalty',
          entityId: buyerProfileId,
          beforeState: { loyaltyTier: previousTier },
          afterState: { loyaltyTier: dto.newTier, reason: dto.reason },
        },
      });

      // Mandatory Grand Aqua buyer tier upgrade notification
      if (dto.newTier !== LoyaltyTierLevel.NONE) {
        const tierName = dto.newTier.charAt(0) + dto.newTier.slice(1).toLowerCase();
        const typeName = buyer.buyerType.charAt(0) + buyer.buyerType.slice(1).toLowerCase();

        await tx.notification.create({
          data: {
            userId: buyer.userId,
            title: `Congratulations! Tier Upgraded to ${tierName}`,
            body: `Congratulations! Your Grand Aqua account has been upgraded to ${tierName} ${typeName}. You are now eligible for your assigned ${tierName} benefits, special offers, and approved credit facilities.`,
            type: 'LOYALTY_UPGRADE',
            referenceType: 'LOYALTY',
            referenceId: buyerProfileId,
          },
        });

        if (buyer.assignedSalesman?.userId) {
          await tx.notification.create({
            data: {
              userId: buyer.assignedSalesman.userId,
              title: `Assigned Buyer Upgraded to ${tierName}`,
              body: `${buyer.businessName || buyer.user.fullName} is now ${tierName} ${typeName}. Check active tier offers when preparing their next quotation.`,
              type: 'LOYALTY_UPGRADE',
              referenceType: 'BUYER',
              referenceId: buyerProfileId,
            },
          });
        }
      }

      return updated;
    });
  }

  async assignSalesman(
    buyerProfileId: string,
    salesmanProfileId: string,
    adminId: string,
    reason?: string,
  ) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id: buyerProfileId },
    });

    if (!buyer) throw new NotFoundException('Buyer not found');

    const salesman = await this.prisma.salesmanProfile.findUnique({
      where: { id: salesmanProfileId },
      include: { user: true },
    });

    if (!salesman) throw new NotFoundException('Salesman not found');

    const previousSalesmanId = buyer.assignedSalesmanId;

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.buyerProfile.update({
        where: { id: buyerProfileId },
        data: { assignedSalesmanId: salesmanProfileId },
      });

      await tx.buyerAssignmentHistory.create({
        data: {
          buyerProfileId,
          fromSalesmanId: previousSalesmanId,
          toSalesmanId: salesmanProfileId,
          reason: reason || 'Admin assignment',
          changedBy: adminId,
        },
      });

      // Recalculate active shops count for salesman
      const count = await tx.buyerProfile.count({
        where: { assignedSalesmanId: salesmanProfileId, accountStatus: 'ACTIVE' },
      });
      await tx.salesmanProfile.update({
        where: { id: salesmanProfileId },
        data: { activeShopsCount: count },
      });

      return updated;
    });
  }

  async updateAccountStatus(
    buyerProfileId: string,
    status: AccountStatus,
    adminId: string,
    reason?: string,
  ) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id: buyerProfileId },
    });
    if (!buyer) throw new NotFoundException('Buyer not found');

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.buyerProfile.update({
        where: { id: buyerProfileId },
        data: { accountStatus: status },
      });

      await tx.user.update({
        where: { id: buyer.userId },
        data: { status },
      });

      await tx.auditLog.create({
        data: {
          actorId: adminId,
          actorType: 'ADMIN',
          action: 'UPDATE_ACCOUNT_STATUS',
          module: 'buyers',
          entityId: buyerProfileId,
          beforeState: { status: buyer.accountStatus },
          afterState: { status, reason },
        },
      });

      return updated;
    });
  }
}
