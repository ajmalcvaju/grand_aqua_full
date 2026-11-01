import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { UserRoleType, AccountStatus, OrderStatus } from '@prisma/client';

@Injectable()
export class SalesmenService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    const salesmen = await this.prisma.salesmanProfile.findMany({
      include: {
        user: true,
        salesTargets: {
          orderBy: { periodStart: 'desc' },
          take: 1,
        },
        _count: {
          select: {
            assignedBuyers: true,
            quotations: true,
            orders: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return salesmen;
  }

  async findOne(id: string) {
    const salesman = await this.prisma.salesmanProfile.findUnique({
      where: { id },
      include: {
        user: true,
        assignedBuyers: {
          include: { user: true, creditAccount: true },
        },
        salesTargets: true,
        incentiveLedger: {
          orderBy: { createdAt: 'desc' },
        },
        quotations: {
          orderBy: { createdAt: 'desc' },
          take: 15,
        },
        orders: {
          orderBy: { createdAt: 'desc' },
          take: 15,
        },
      },
    });

    if (!salesman) throw new NotFoundException('Salesman not found');
    return salesman;
  }

  async create(data: {
    fullName: string;
    username?: string;
    email?: string;
    phone: string;
    password?: string;
    profilePhoto?: string;
    imageUrl?: string;
    avatarUrl?: string;
    employeeCode?: string;
    designation?: string;
    assignedTerritory?: string;
    monthlySalesTarget?: number;
    quarterlySalesTarget?: number;
    address?: string;
  }) {
    if (!data.fullName || !data.phone) {
      throw new BadRequestException('Full name and mobile number are required');
    }

    // Check if username, phone, or email already in use
    if (data.username && data.username.trim()) {
      const cleanUsername = data.username.trim().toLowerCase();
      const existingUser = await this.prisma.user.findUnique({ where: { username: cleanUsername } });
      if (existingUser) {
        throw new BadRequestException(`Username '${data.username}' is already taken`);
      }
    }

    const existingPhone = await this.prisma.user.findUnique({ where: { phone: data.phone } });
    if (existingPhone) {
      throw new BadRequestException(`User with phone ${data.phone} already exists`);
    }
    if (data.email) {
      const existingEmail = await this.prisma.user.findUnique({ where: { email: data.email } });
      if (existingEmail) {
        throw new BadRequestException(`User with email ${data.email} already exists`);
      }
    }

    const salt = await bcrypt.genSalt(10);
    const password = data.password || 'GrandAqua@Sales2026';
    const passwordHash = await bcrypt.hash(password, salt);

    const employeeCode = data.employeeCode && data.employeeCode.trim().length > 0
      ? data.employeeCode.trim().toUpperCase()
      : `GA-SLS-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;

    const existingCode = await this.prisma.salesmanProfile.findUnique({ where: { employeeCode } });
    if (existingCode) {
      throw new BadRequestException(`Employee code ${employeeCode} already exists`);
    }

    const territory = data.assignedTerritory || data.designation || 'General Area Sales';
    const monthlyTarget = Number(data.monthlySalesTarget) || 500000;
    const quarterlyTarget = Number(data.quarterlySalesTarget) || 1500000;

    return this.prisma.$transaction(async (tx) => {
      const photo = data.profilePhoto || data.imageUrl || data.avatarUrl || null;
      const user = await tx.user.create({
        data: {
          fullName: data.fullName.trim(),
          username: data.username && data.username.trim() ? data.username.trim().toLowerCase() : null,
          phone: data.phone.trim(),
          email: data.email ? data.email.trim().toLowerCase() : null,
          passwordHash,
          role: UserRoleType.SALESMAN,
          status: AccountStatus.ACTIVE,
          profilePhoto: photo ? photo.trim() : null,
        },
      });

      const profile = await tx.salesmanProfile.create({
        data: {
          userId: user.id,
          employeeCode,
          assignedTerritory: territory,
          address: data.address,
          monthlySalesTarget: monthlyTarget,
          quarterlySalesTarget: quarterlyTarget,
          employmentStatus: 'ACTIVE',
        },
        include: {
          user: true,
          salesTargets: true,
        },
      });

      // Create initial monthly sales target
      const now = new Date();
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

      await tx.salesTarget.create({
        data: {
          salesmanProfileId: profile.id,
          targetPeriod: 'MONTHLY',
          periodStart: startOfMonth,
          periodEnd: endOfMonth,
          targetAmount: monthlyTarget,
          achievedAmount: 0,
        },
      });

      return profile;
    });
  }

  async update(
    id: string,
    data: {
      fullName?: string;
      username?: string;
      email?: string;
      phone?: string;
      profilePhoto?: string;
      imageUrl?: string;
      avatarUrl?: string;
      designation?: string;
      assignedTerritory?: string;
      monthlySalesTarget?: number;
      quarterlySalesTarget?: number;
      address?: string;
      employmentStatus?: string;
    },
  ) {
    const profile = await this.prisma.salesmanProfile.findUnique({
      where: { id },
      include: { user: true },
    });
    if (!profile) throw new NotFoundException('Salesman not found');

    if (data.username !== undefined) {
      const cleanUsername = data.username ? data.username.trim().toLowerCase() : null;
      if (cleanUsername && cleanUsername !== profile.user.username) {
        const existing = await this.prisma.user.findUnique({ where: { username: cleanUsername } });
        if (existing && existing.id !== profile.userId) {
          throw new BadRequestException(`Username '${data.username}' is already taken`);
        }
      }
    }

    const photo = data.profilePhoto !== undefined
      ? data.profilePhoto
      : (data.imageUrl !== undefined ? data.imageUrl : data.avatarUrl);

    return this.prisma.$transaction(async (tx) => {
      // 1. Update User details
      if (
        data.fullName ||
        data.username !== undefined ||
        data.email !== undefined ||
        data.phone ||
        photo !== undefined
      ) {
        await tx.user.update({
          where: { id: profile.userId },
          data: {
            fullName: data.fullName ? data.fullName.trim() : undefined,
            username: data.username !== undefined ? (data.username ? data.username.trim().toLowerCase() : null) : undefined,
            email: data.email !== undefined ? (data.email ? data.email.trim().toLowerCase() : null) : undefined,
            phone: data.phone ? data.phone.trim() : undefined,
            ...(photo !== undefined && { profilePhoto: photo ? photo.trim() : null }),
          },
        });
      }

      // 2. Update SalesmanProfile details
      const updatedProfile = await tx.salesmanProfile.update({
        where: { id },
        data: {
          assignedTerritory: data.assignedTerritory ?? data.designation ?? profile.assignedTerritory,
          monthlySalesTarget: data.monthlySalesTarget !== undefined ? Number(data.monthlySalesTarget) : undefined,
          quarterlySalesTarget: data.quarterlySalesTarget !== undefined ? Number(data.quarterlySalesTarget) : undefined,
          address: data.address !== undefined ? data.address : profile.address,
          employmentStatus: data.employmentStatus !== undefined ? data.employmentStatus : profile.employmentStatus,
        },
        include: {
          user: true,
          salesTargets: {
            orderBy: { periodStart: 'desc' },
            take: 1,
          },
        },
      });

      return updatedProfile;
    });
  }

  async toggleBlock(id: string, reason?: string) {
    const profile = await this.prisma.salesmanProfile.findUnique({
      where: { id },
      include: { user: true },
    });
    if (!profile) throw new NotFoundException('Salesman not found');

    const isCurrentlyBlocked = profile.user.status === AccountStatus.BLOCKED || profile.employmentStatus === 'BLOCKED';
    const newStatus = isCurrentlyBlocked ? AccountStatus.ACTIVE : AccountStatus.BLOCKED;
    const newEmploymentStatus = isCurrentlyBlocked ? 'ACTIVE' : 'BLOCKED';

    return this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: profile.userId },
        data: { status: newStatus },
      });

      const updated = await tx.salesmanProfile.update({
        where: { id },
        data: { employmentStatus: newEmploymentStatus },
        include: { user: true },
      });

      return {
        ...updated,
        message: isCurrentlyBlocked ? 'Salesman unblocked successfully' : 'Salesman blocked successfully',
      };
    });
  }

  async deleteSalesman(id: string) {
    const profile = await this.prisma.salesmanProfile.findUnique({
      where: { id },
      include: { orders: true },
    });
    if (!profile) throw new NotFoundException('Salesman not found');

    return this.prisma.$transaction(async (tx) => {
      // Unassign all buyers
      await tx.buyerProfile.updateMany({
        where: { assignedSalesmanId: id },
        data: { assignedSalesmanId: null },
      });

      // Disassociate assignments, targets, ledger
      await tx.buyerAssignment.deleteMany({ where: { salesmanProfileId: id } });
      await tx.salesTarget.deleteMany({ where: { salesmanProfileId: id } });
      await tx.incentiveLedger.deleteMany({ where: { salesmanProfileId: id } });

      // If no orders, delete profile and user
      await tx.salesmanProfile.delete({ where: { id } });
      await tx.user.delete({ where: { id: profile.userId } });

      return { success: true, message: 'Salesman deleted successfully' };
    });
  }

  async getAssignedBuyers(salesmanProfileId: string) {
    const profile = await this.prisma.salesmanProfile.findUnique({ where: { id: salesmanProfileId } });
    if (!profile) throw new NotFoundException('Salesman not found');

    return this.prisma.buyerProfile.findMany({
      where: { assignedSalesmanId: salesmanProfileId },
      include: {
        user: true,
        creditAccount: true,
        addresses: { where: { isDefault: true }, take: 1 },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async assignBuyer(salesmanProfileId: string, buyerProfileId: string) {
    const profile = await this.prisma.salesmanProfile.findUnique({ where: { id: salesmanProfileId } });
    if (!profile) throw new NotFoundException('Salesman not found');

    const buyer = await this.prisma.buyerProfile.findUnique({ where: { id: buyerProfileId } });
    if (!buyer) throw new NotFoundException('Buyer not found');

    return this.prisma.$transaction(async (tx) => {
      await tx.buyerProfile.update({
        where: { id: buyerProfileId },
        data: { assignedSalesmanId: salesmanProfileId },
      });

      await tx.buyerAssignment.create({
        data: {
          buyerProfileId,
          salesmanProfileId,
          assignedBy: 'SUPER_ADMIN',
          status: 'ACTIVE',
        },
      });

      const updatedCount = await tx.buyerProfile.count({
        where: { assignedSalesmanId: salesmanProfileId },
      });

      await tx.salesmanProfile.update({
        where: { id: salesmanProfileId },
        data: { activeShopsCount: updatedCount },
      });

      return { success: true, assignedCount: updatedCount };
    });
  }

  async unassignBuyer(salesmanProfileId: string, buyerProfileId: string) {
    return this.prisma.$transaction(async (tx) => {
      await tx.buyerProfile.update({
        where: { id: buyerProfileId },
        data: { assignedSalesmanId: null },
      });

      await tx.buyerAssignment.deleteMany({
        where: { buyerProfileId, salesmanProfileId },
      });

      const updatedCount = await tx.buyerProfile.count({
        where: { assignedSalesmanId: salesmanProfileId },
      });

      await tx.salesmanProfile.update({
        where: { id: salesmanProfileId },
        data: { activeShopsCount: updatedCount },
      });

      return { success: true, assignedCount: updatedCount };
    });
  }

  async getSalesHistory(
    salesmanProfileId: string,
    query: {
      startDate?: string;
      endDate?: string;
      buyerProfileId?: string;
      page?: number;
      limit?: number;
    },
  ) {
    const profile = await this.prisma.salesmanProfile.findUnique({ where: { id: salesmanProfileId } });
    if (!profile) throw new NotFoundException('Salesman not found');

    const where: any = { salesmanProfileId };

    if (query.buyerProfileId) {
      where.buyerProfileId = query.buyerProfileId;
    }

    if (query.startDate || query.endDate) {
      where.createdAt = {};
      if (query.startDate) {
        where.createdAt.gte = new Date(query.startDate);
      }
      if (query.endDate) {
        // include entire end date
        const end = new Date(query.endDate);
        end.setHours(23, 59, 59, 999);
        where.createdAt.lte = end;
      }
    }

    const page = Number(query.page) || 1;
    const limit = Number(query.limit) || 50;
    const skip = (page - 1) * limit;

    const [totalOrders, orders] = await Promise.all([
      this.prisma.order.count({ where }),
      this.prisma.order.findMany({
        where,
        skip,
        take: limit,
        include: {
          buyer: { include: { user: true } },
          items: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    // Aggregate summary metrics across matched orders
    const allMatching = await this.prisma.order.findMany({
      where,
      select: {
        finalAmount: true,
        paidAmount: true,
        outstandingAmount: true,
        status: true,
      },
    });

    const totalSales = allMatching.reduce((acc, o) => acc + Number(o.finalAmount || 0), 0);
    const totalPaid = allMatching.reduce((acc, o) => acc + Number(o.paidAmount || 0), 0);
    const totalOutstanding = allMatching.reduce((acc, o) => acc + Number(o.outstandingAmount || 0), 0);
    const deliveredCount = allMatching.filter((o) => o.status === OrderStatus.DELIVERED).length;
    const provisionalCommission = (totalSales * 0.03); // 3% commission rule

    return {
      orders,
      summary: {
        totalOrders,
        totalSales,
        totalPaid,
        totalOutstanding,
        deliveredCount,
        provisionalCommission,
      },
      pagination: {
        page,
        limit,
        totalPages: Math.ceil(totalOrders / limit),
      },
    };
  }

  async getPerformance(salesmanProfileId: string) {
    const salesman = await this.prisma.salesmanProfile.findUnique({
      where: { id: salesmanProfileId },
      include: {
        user: true,
        assignedBuyers: true,
        salesTargets: {
          orderBy: { periodStart: 'desc' },
          take: 1,
        },
      },
    });

    if (!salesman) throw new NotFoundException('Salesman not found');

    const [quotationsCount, acceptedQuotations, orders, incentives] = await Promise.all([
      this.prisma.quotation.count({ where: { salesmanProfileId } }),
      this.prisma.quotation.count({
        where: { salesmanProfileId, status: { in: ['ACCEPTED', 'CONVERTED_TO_ORDER'] } },
      }),
      this.prisma.order.findMany({
        where: { salesmanProfileId },
        select: { finalAmount: true, status: true, paidAmount: true },
      }),
      this.prisma.incentiveLedger.findMany({
        where: { salesmanProfileId },
      }),
    ]);

    const totalSales = orders.reduce((acc, o) => acc + Number(o.finalAmount), 0);
    const collections = orders.reduce((acc, o) => acc + Number(o.paidAmount), 0);
    const conversionRate = quotationsCount > 0 ? (acceptedQuotations / quotationsCount) * 100 : 0;

    const totalIncentivesEarned = incentives.reduce(
      (acc, inc) => acc + Number(inc.calculatedAmount),
      0,
    );
    const approvedIncentives = incentives
      .filter((inc) => inc.status === 'APPROVED' || inc.status === 'PAID')
      .reduce((acc, inc) => acc + Number(inc.approvedAmount), 0);
    const paidIncentives = incentives
      .filter((inc) => inc.status === 'PAID')
      .reduce((acc, inc) => acc + Number(inc.approvedAmount), 0);
    const pendingIncentives = totalIncentivesEarned - paidIncentives;

    return {
      salesman: {
        id: salesman.id,
        name: salesman.user.fullName,
        code: salesman.employeeCode,
        territory: salesman.assignedTerritory,
        monthlyTarget: Number(salesman.monthlySalesTarget),
        profilePhoto: salesman.user.profilePhoto || null,
        imageUrl: salesman.user.profilePhoto || null,
      },
      metrics: {
        assignedShopsCount: salesman.assignedBuyers.length,
        totalQuotations: quotationsCount,
        acceptedQuotations,
        conversionRate: Number(conversionRate.toFixed(1)),
        totalOrdersCount: orders.length,
        totalSalesValue: totalSales,
        collectionsValue: collections,
        targetAchievementPercent:
          Number(salesman.monthlySalesTarget) > 0
            ? Number(((totalSales / Number(salesman.monthlySalesTarget)) * 100).toFixed(1))
            : 0,
        incentives: {
          totalEarned: totalIncentivesEarned,
          approved: approvedIncentives,
          paid: paidIncentives,
          pending: pendingIncentives,
        },
      },
    };
  }

  async getIncentiveLedger(salesmanProfileId: string) {
    return this.prisma.incentiveLedger.findMany({
      where: { salesmanProfileId },
      orderBy: { createdAt: 'desc' },
      include: {
        incentivePlan: true,
      },
    });
  }

  async approveIncentive(ledgerId: string, adminId: string, approvedAmount?: number) {
    const entry = await this.prisma.incentiveLedger.findUnique({ where: { id: ledgerId } });
    if (!entry) throw new NotFoundException('Incentive ledger record not found');

    return this.prisma.incentiveLedger.update({
      where: { id: ledgerId },
      data: {
        status: 'APPROVED',
        approvedAmount: approvedAmount !== undefined ? approvedAmount : entry.calculatedAmount,
        approvedBy: adminId,
        approvedAt: new Date(),
      },
    });
  }

  async markIncentivePaid(ledgerId: string) {
    return this.prisma.incentiveLedger.update({
      where: { id: ledgerId },
      data: {
        status: 'PAID',
        paidAt: new Date(),
      },
    });
  }
}
