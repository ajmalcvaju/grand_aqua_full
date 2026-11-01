import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  UpdateLoyaltyConfigDto,
  AdjustPointsDto,
  CreateGiftDto,
  UpdateGiftDto,
  RedeemGiftDto,
  UpdateRedemptionStatusDto,
} from './dto/loyalty.dto';

@Injectable()
export class LoyaltyService {
  constructor(private prisma: PrismaService) {}

  // 1. Loyalty Configuration
  async getConfig() {
    const [enabledSetting, pctSetting, rateSetting] = await Promise.all([
      this.prisma.companySettings.findUnique({ where: { key: 'loyalty_program_enabled' } }),
      this.prisma.companySettings.findUnique({ where: { key: 'loyalty_percentage' } }),
      this.prisma.companySettings.findUnique({ where: { key: 'loyalty_point_rupee_rate' } }),
    ]);

    const isEnabled = enabledSetting ? enabledSetting.value === 'true' : true;
    const pct = pctSetting ? parseFloat(pctSetting.value) || 0.5 : 0.5;
    const rate = rateSetting ? parseFloat(rateSetting.value) || 1.0 : 1.0;

    return {
      enabled: isEnabled,
      programEnabled: isEnabled,
      percentage: pct,
      rupeePerPoint: rate,
      pointRupeeRate: rate,
    };
  }

  async updateConfig(dto: UpdateLoyaltyConfigDto) {
    const isEnabled = dto.enabled !== undefined ? dto.enabled : (dto.programEnabled !== undefined ? dto.programEnabled : true);
    const pct = dto.percentage !== undefined ? dto.percentage : 0.5;
    const rate = dto.rupeePerPoint !== undefined ? dto.rupeePerPoint : (dto.pointRupeeRate !== undefined ? dto.pointRupeeRate : 1.0);

    await Promise.all([
      this.prisma.companySettings.upsert({
        where: { key: 'loyalty_program_enabled' },
        create: {
          key: 'loyalty_program_enabled',
          value: isEnabled ? 'true' : 'false',
          description: 'Global toggle for Grand Aqua loyalty points program',
        },
        update: { value: isEnabled ? 'true' : 'false' },
      }),
      this.prisma.companySettings.upsert({
        where: { key: 'loyalty_percentage' },
        create: {
          key: 'loyalty_percentage',
          value: pct.toString(),
          description: 'Percentage of purchase value awarded as loyalty points',
        },
        update: { value: pct.toString() },
      }),
      this.prisma.companySettings.upsert({
        where: { key: 'loyalty_point_rupee_rate' },
        create: {
          key: 'loyalty_point_rupee_rate',
          value: rate.toString(),
          description: 'Rupee value per loyalty point',
        },
        update: { value: rate.toString() },
      }),
    ]);

    return this.getConfig();
  }

  // 2. Buyer Loyalty Accounts (Super Admin)
  async getAllBuyersLoyalty(search?: string) {
    const buyers = await this.prisma.buyerProfile.findMany({
      where: search
        ? {
            OR: [
              { businessName: { contains: search, mode: 'insensitive' } },
              { user: { fullName: { contains: search, mode: 'insensitive' } } },
              { user: { phone: { contains: search } } },
            ],
          }
        : undefined,
      include: {
        user: { select: { id: true, fullName: true, phone: true, email: true, username: true } },
        _count: { select: { pointLedgers: true, giftRedemptions: true } },
      },
      orderBy: { loyaltyPoints: 'desc' },
    });

    return buyers.map((b) => ({
      id: b.id,
      buyerProfileId: b.id,
      buyerName: b.user?.fullName || b.businessName || 'Valued Buyer',
      businessName: b.businessName || b.user?.fullName || 'Valued Buyer',
      phone: b.user?.phone,
      email: b.user?.email,
      buyerType: b.buyerType,
      loyaltyTier: b.loyaltyTier,
      points: b.loyaltyPoints ?? 0,
      loyaltyPoints: b.loyaltyPoints ?? 0,
      loyaltyRupeeValue: b.loyaltyPoints ?? 0, // 1 pt = 1 INR
      rupeeValue: b.loyaltyPoints ?? 0,
      loyaltyEnabled: b.loyaltyEnabled ?? true,
      enabled: b.loyaltyEnabled ?? true,
      totalPurchaseValue: b.totalPurchaseValue ?? 0,
      totalOrders: b.totalOrders ?? 0,
      transactionsCount: b._count?.pointLedgers ?? 0,
      redemptionsCount: b._count?.giftRedemptions ?? 0,
    }));
  }

  async toggleBuyerLoyalty(buyerProfileId: string, enabled: boolean) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id: buyerProfileId },
    });
    if (!buyer) throw new NotFoundException('Buyer profile not found');

    const updated = await this.prisma.buyerProfile.update({
      where: { id: buyerProfileId },
      data: { loyaltyEnabled: enabled },
      include: { user: true },
    });

    return {
      id: updated.id,
      buyerProfileId: updated.id,
      buyerName: updated.user?.fullName || updated.businessName,
      loyaltyEnabled: updated.loyaltyEnabled,
      enabled: updated.loyaltyEnabled,
      loyaltyPoints: updated.loyaltyPoints,
      points: updated.loyaltyPoints,
    };
  }

  async adjustBuyerPoints(buyerProfileId: string, dto: AdjustPointsDto, adminName: string) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { id: buyerProfileId },
      include: { user: true },
    });
    if (!buyer) throw new NotFoundException('Buyer profile not found');

    const currentPoints = buyer.loyaltyPoints ?? 0;
    let newPoints = currentPoints;
    const rawAmt = dto.amount !== undefined ? dto.amount : (dto.points !== undefined ? dto.points : 0);
    let delta = Math.abs(rawAmt);
    if (delta <= 0) {
      throw new BadRequestException('Please provide a valid points amount');
    }

    if (dto.type === 'DEBIT') {
      if (currentPoints < delta) {
        throw new BadRequestException(
          `Cannot deduct ${delta} points. Buyer only has ${currentPoints} points available.`,
        );
      }
      newPoints = currentPoints - delta;
      delta = -delta;
    } else {
      newPoints = currentPoints + delta;
    }

    // Update buyer balance
    await this.prisma.buyerProfile.update({
      where: { id: buyerProfileId },
      data: { loyaltyPoints: newPoints },
    });

    // Record ledger entry
    const ledger = await this.prisma.loyaltyPointLedger.create({
      data: {
        buyerProfileId,
        points: delta,
        balanceAfter: newPoints,
        transactionType: dto.type === 'CREDIT' ? 'ADMIN_CREDIT' : 'ADMIN_DEBIT',
        description: dto.reason || (dto.type === 'CREDIT' ? 'Points added by Super Admin' : 'Points deducted by Super Admin'),
        performedBy: adminName || 'Super Admin',
      },
    });

    return {
      success: true,
      buyerProfileId,
      previousBalance: currentPoints,
      currentBalance: newPoints,
      transaction: ledger,
    };
  }

  async getBuyerPointHistory(buyerProfileId: string) {
    const [buyer, history] = await Promise.all([
      this.prisma.buyerProfile.findUnique({
        where: { id: buyerProfileId },
        include: { user: true },
      }),
      this.prisma.loyaltyPointLedger.findMany({
        where: { buyerProfileId },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    if (!buyer) throw new NotFoundException('Buyer profile not found');

    return {
      buyer: {
        id: buyer.id,
        name: buyer.user?.fullName || buyer.businessName || 'Buyer',
        phone: buyer.user?.phone,
        loyaltyPoints: buyer.loyaltyPoints ?? 0,
        loyaltyEnabled: buyer.loyaltyEnabled ?? true,
      },
      history,
    };
  }

  // 3. Buyer Self-Service
  async getBuyerSummary(buyerProfileId: string) {
    const [config, buyer, ledgers, redemptions] = await Promise.all([
      this.getConfig(),
      this.prisma.buyerProfile.findUnique({
        where: { id: buyerProfileId },
        include: { user: true },
      }),
      this.prisma.loyaltyPointLedger.findMany({
        where: { buyerProfileId },
        select: { points: true, transactionType: true },
      }),
      this.prisma.loyaltyGiftRedemption.count({
        where: { buyerProfileId },
      }),
    ]);

    if (!buyer) throw new NotFoundException('Buyer profile not found');

    const totalEarned = ledgers
      .filter((l) => l.points > 0)
      .reduce((sum, l) => sum + l.points, 0);

    const totalRedeemed = Math.abs(
      ledgers
        .filter((l) => l.points < 0)
        .reduce((sum, l) => sum + l.points, 0),
    );

    return {
      loyaltyPoints: buyer.loyaltyPoints ?? 0,
      rupeeValue: (buyer.loyaltyPoints ?? 0) * config.rupeePerPoint,
      loyaltyEnabled: (buyer.loyaltyEnabled ?? true) && config.enabled,
      isGlobalEnabled: config.enabled,
      accrualPercentage: config.percentage,
      rupeePerPoint: config.rupeePerPoint,
      totalEarned,
      totalRedeemed,
      redemptionsCount: redemptions,
      tier: buyer.loyaltyTier,
    };
  }

  async getMyHistory(buyerProfileId: string) {
    return this.prisma.loyaltyPointLedger.findMany({
      where: { buyerProfileId },
      orderBy: { createdAt: 'desc' },
    });
  }

  // 4. Gift Rewards Catalog (Super Admin & Buyer)
  async getGifts(activeOnly = false) {
    const gifts = await this.prisma.loyaltyGift.findMany({
      where: activeOnly ? { isActive: true, stockQuantity: { gt: 0 } } : undefined,
      orderBy: { pointsRequired: 'asc' },
    });
    return gifts.map(g => ({
      ...g,
      stock: g.stockQuantity,
      stockQuantity: g.stockQuantity,
    }));
  }

  async createGift(dto: CreateGiftDto) {
    const stock = dto.stockQuantity !== undefined ? dto.stockQuantity : (dto.stock !== undefined ? dto.stock : 100);
    const created = await this.prisma.loyaltyGift.create({
      data: {
        title: dto.title,
        description: dto.description || null,
        imageUrl: dto.imageUrl || '/uploads/products/sample-ro.jpg',
        pointsRequired: dto.pointsRequired,
        stockQuantity: stock,
        isActive: dto.isActive ?? true,
      },
    });
    return {
      ...created,
      stock: created.stockQuantity,
      stockQuantity: created.stockQuantity,
    };
  }

  async updateGift(id: string, dto: UpdateGiftDto) {
    const gift = await this.prisma.loyaltyGift.findUnique({ where: { id } });
    if (!gift) throw new NotFoundException('Gift not found');

    const stock = dto.stockQuantity !== undefined ? dto.stockQuantity : (dto.stock !== undefined ? dto.stock : undefined);

    const updated = await this.prisma.loyaltyGift.update({
      where: { id },
      data: {
        ...(dto.title !== undefined && { title: dto.title }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.imageUrl !== undefined && { imageUrl: dto.imageUrl }),
        ...(dto.pointsRequired !== undefined && { pointsRequired: dto.pointsRequired }),
        ...(stock !== undefined && { stockQuantity: stock }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
      },
    });
    return {
      ...updated,
      stock: updated.stockQuantity,
      stockQuantity: updated.stockQuantity,
    };
  }

  async deleteGift(id: string) {
    const gift = await this.prisma.loyaltyGift.findUnique({ where: { id } });
    if (!gift) throw new NotFoundException('Gift not found');

    return this.prisma.loyaltyGift.delete({ where: { id } });
  }

  // 5. Gift Redemption
  async redeemGift(buyerProfileId: string, dto: RedeemGiftDto, buyerName: string) {
    const config = await this.getConfig();
    if (!config.enabled) {
      throw new BadRequestException('Loyalty points program is currently suspended by management.');
    }

    const [buyer, gift] = await Promise.all([
      this.prisma.buyerProfile.findUnique({
        where: { id: buyerProfileId },
        include: { user: true },
      }),
      this.prisma.loyaltyGift.findUnique({
        where: { id: dto.giftId },
      }),
    ]);

    if (!buyer) throw new NotFoundException('Buyer profile not found');
    if (!gift) throw new NotFoundException('Selected gift not found');

    if (!buyer.loyaltyEnabled) {
      throw new BadRequestException('Loyalty rewards are currently disabled for your account. Please contact Super Admin.');
    }

    if (!gift.isActive || gift.stockQuantity <= 0) {
      throw new BadRequestException('This gift item is currently out of stock or unavailable.');
    }

    const currentPoints = buyer.loyaltyPoints ?? 0;
    if (currentPoints < gift.pointsRequired) {
      throw new BadRequestException(
        `Insufficient loyalty points. You have ${currentPoints} points, but this gift requires ${gift.pointsRequired} points.`,
      );
    }

    const newPoints = currentPoints - gift.pointsRequired;

    // Deduct points from buyer and decrement gift stock
    await Promise.all([
      this.prisma.buyerProfile.update({
        where: { id: buyerProfileId },
        data: { loyaltyPoints: newPoints },
      }),
      this.prisma.loyaltyGift.update({
        where: { id: gift.id },
        data: { stockQuantity: { decrement: 1 } },
      }),
    ]);

    // Create redemption record
    const redemption = await this.prisma.loyaltyGiftRedemption.create({
      data: {
        giftId: gift.id,
        buyerProfileId,
        pointsSpent: gift.pointsRequired,
        status: 'REQUESTED',
        deliveryNotes: dto.deliveryNotes || dto.notes || `Delivery requested to ${buyer.shippingAddress || 'registered address'}`,
      },
      include: { gift: true },
    });

    // Record ledger transaction
    await this.prisma.loyaltyPointLedger.create({
      data: {
        buyerProfileId,
        points: -gift.pointsRequired,
        balanceAfter: newPoints,
        transactionType: 'GIFT_REDEEMED',
        referenceId: redemption.id,
        description: `Redeemed for Gift: ${gift.title}`,
        performedBy: buyerName || buyer.user.fullName || 'Buyer',
      },
    });

    return {
      success: true,
      message: `Gift "${gift.title}" redeemed successfully! Points deducted: ${gift.pointsRequired}.`,
      remainingPoints: newPoints,
      redemption,
    };
  }

  async getMyRedemptions(buyerProfileId: string) {
    return this.prisma.loyaltyGiftRedemption.findMany({
      where: { buyerProfileId },
      include: { gift: true },
      orderBy: { redeemedAt: 'desc' },
    });
  }

  async getAllRedemptions() {
    return this.prisma.loyaltyGiftRedemption.findMany({
      include: {
        gift: true,
        buyer: {
          include: {
            user: { select: { fullName: true, phone: true, email: true } },
          },
        },
      },
      orderBy: { redeemedAt: 'desc' },
    });
  }

  async updateRedemptionStatus(id: string, dto: UpdateRedemptionStatusDto) {
    const redemption = await this.prisma.loyaltyGiftRedemption.findUnique({
      where: { id },
      include: { gift: true, buyer: { include: { user: true } } },
    });
    if (!redemption) throw new NotFoundException('Redemption request not found');

    const previousStatus = redemption.status;

    // If changing to REJECTED from non-rejected, refund points back to buyer
    if (dto.status === 'REJECTED' && previousStatus !== 'REJECTED') {
      const currentPoints = redemption.buyer.loyaltyPoints ?? 0;
      const refundedPoints = currentPoints + redemption.pointsSpent;

      await Promise.all([
        this.prisma.buyerProfile.update({
          where: { id: redemption.buyerProfileId },
          data: { loyaltyPoints: refundedPoints },
        }),
        this.prisma.loyaltyGift.update({
          where: { id: redemption.giftId },
          data: { stockQuantity: { increment: 1 } },
        }),
        this.prisma.loyaltyPointLedger.create({
          data: {
            buyerProfileId: redemption.buyerProfileId,
            points: redemption.pointsSpent,
            balanceAfter: refundedPoints,
            transactionType: 'REDEMPTION_REFUND',
            referenceId: redemption.id,
            description: `Points refunded for rejected gift request: ${redemption.gift.title} (${dto.adminRemarks || 'Rejected by Admin'})`,
            performedBy: 'SUPER_ADMIN',
          },
        }),
      ]);
    }

    const updated = await this.prisma.loyaltyGiftRedemption.update({
      where: { id },
      data: {
        status: dto.status,
        ...(dto.adminRemarks !== undefined && { adminRemarks: dto.adminRemarks }),
      },
      include: {
        gift: true,
        buyer: { include: { user: true } },
      },
    });

    return updated;
  }

  // 6. Automatic Points Accrual on Orders
  async awardPointsForOrder(orderId: string, finalTotal: number, buyerProfileId: string, orderNumber: string) {
    try {
      const config = await this.getConfig();
      if (!config.enabled) return null;

      const buyer = await this.prisma.buyerProfile.findUnique({
        where: { id: buyerProfileId },
      });
      if (!buyer || buyer.loyaltyEnabled === false) return null;

      // Check if points were already credited for this order
      const existingLedger = await this.prisma.loyaltyPointLedger.findFirst({
        where: {
          buyerProfileId,
          referenceId: orderId,
          transactionType: 'ORDER_EARNED',
        },
      });
      if (existingLedger) return null;

      // Points calculation: finalTotal * (percentage / 100)
      const earned = Math.round(finalTotal * (config.percentage / 100) * 100) / 100;
      if (earned <= 0) return null;

      const currentPoints = buyer.loyaltyPoints ?? 0;
      const newPoints = currentPoints + earned;

      await this.prisma.buyerProfile.update({
        where: { id: buyerProfileId },
        data: { loyaltyPoints: newPoints },
      });

      const ledger = await this.prisma.loyaltyPointLedger.create({
        data: {
          buyerProfileId,
          points: earned,
          balanceAfter: newPoints,
          transactionType: 'ORDER_EARNED',
          referenceId: orderId,
          description: `Earned on Order #${orderNumber} (${config.percentage}% of ₹${finalTotal.toLocaleString('en-IN')})`,
          performedBy: 'SYSTEM',
        },
      });

      return ledger;
    } catch (err) {
      console.warn('Failed to award loyalty points for order:', err?.message || err);
      return null;
    }
  }
}
