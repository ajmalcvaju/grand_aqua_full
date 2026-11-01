import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BuyerType, LoyaltyTierLevel } from '@prisma/client';

@Injectable()
export class OffersService {
  constructor(private prisma: PrismaService) {}

  async getAllTiers() {
    return this.prisma.loyaltyTier.findMany({
      include: {
        _count: {
          select: { memberships: true },
        },
      },
      orderBy: { minPurchaseValue: 'asc' },
    });
  }

  async getAllOffers(query?: { buyerType?: BuyerType; loyaltyTier?: LoyaltyTierLevel }) {
    const where: any = { isActive: true };
    if (query?.buyerType) {
      where.OR = [{ targetBuyerType: null }, { targetBuyerType: query.buyerType }];
    }
    if (query?.loyaltyTier) {
      where.OR = [{ targetLoyaltyTier: null }, { targetLoyaltyTier: query.loyaltyTier }];
    }

    return this.prisma.offer.findMany({
      where,
      orderBy: { endDate: 'asc' },
    });
  }

  async getAllVouchers() {
    return this.prisma.giftVoucher.findMany({
      orderBy: { validUntil: 'asc' },
      include: {
        _count: {
          select: { redemptions: true },
        },
      },
    });
  }

  async validateVoucher(code: string, buyerProfileId: string, orderSubtotal: number) {
    const cleanCode = code.trim().toUpperCase();
    const voucher = await this.prisma.giftVoucher.findUnique({
      where: { code: cleanCode },
    });

    if (!voucher) {
      throw new NotFoundException('Invalid voucher code');
    }

    if (voucher.status !== 'ACTIVE') {
      throw new BadRequestException('This voucher is no longer active');
    }

    const now = new Date();
    if (now < voucher.validFrom || now > voucher.validUntil) {
      throw new BadRequestException('Voucher has expired or is not yet valid');
    }

    if (voucher.currentUses >= voucher.maxUsesTotal) {
      throw new BadRequestException('Voucher redemption limit has been reached');
    }

    if (orderSubtotal < Number(voucher.minOrderValue)) {
      throw new BadRequestException(
        `Minimum order subtotal of ₹${voucher.minOrderValue} required for this voucher`,
      );
    }

    // Check per-buyer redemption limit
    const buyerRedemptions = await this.prisma.voucherRedemption.count({
      where: { voucherId: voucher.id, buyerProfileId },
    });

    if (buyerRedemptions >= voucher.maxUsesPerBuyer) {
      throw new BadRequestException('You have already redeemed this voucher the maximum allowed times');
    }

    // Calculate discount
    let discountAmount = 0;
    if (voucher.isPercentage) {
      discountAmount = (orderSubtotal * Number(voucher.voucherValue)) / 100;
    } else {
      discountAmount = Number(voucher.voucherValue);
    }

    return {
      isValid: true,
      voucherId: voucher.id,
      code: voucher.code,
      title: voucher.title,
      discountAmount,
    };
  }

  async createVoucher(data: {
    code: string;
    title: string;
    voucherValue: number;
    isPercentage?: boolean;
    minOrderValue?: number;
    maxUsesTotal?: number;
    maxUsesPerBuyer?: number;
    validFrom: Date;
    validUntil: Date;
    targetBuyerType?: BuyerType;
    targetLoyaltyTier?: LoyaltyTierLevel;
  }) {
    const code = data.code.trim().toUpperCase();
    const existing = await this.prisma.giftVoucher.findUnique({ where: { code } });
    if (existing) {
      throw new BadRequestException(`Voucher code "${code}" already exists`);
    }

    return this.prisma.giftVoucher.create({
      data: {
        code,
        title: data.title,
        voucherValue: data.voucherValue,
        isPercentage: data.isPercentage || false,
        minOrderValue: data.minOrderValue || 0,
        maxUsesTotal: data.maxUsesTotal || 100,
        maxUsesPerBuyer: data.maxUsesPerBuyer || 1,
        validFrom: new Date(data.validFrom),
        validUntil: new Date(data.validUntil),
        targetBuyerType: data.targetBuyerType,
        targetLoyaltyTier: data.targetLoyaltyTier,
      },
    });
  }
}
