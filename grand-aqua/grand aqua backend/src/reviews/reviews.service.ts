import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReviewsService {
  constructor(private prisma: PrismaService) {}

  async getProductReviews(productId: string) {
    return this.prisma.productReview.findMany({
      where: { productId, isApproved: true },
      include: {
        buyer: {
          include: { user: { select: { fullName: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async checkReviewEligibility(userId: string, productId: string) {
    const buyer = await this.prisma.buyerProfile.findUnique({ where: { userId } });
    if (!buyer) return { canReview: false, reason: 'BUYER_NOT_FOUND' };

    const orders = await this.prisma.order.findMany({
      where: {
        buyerProfileId: buyer.id,
        status: { not: 'CANCELLED' },
      },
      select: { id: true, orderNumber: true, status: true },
    });
    const orderIds = orders.map((o) => o.id);

    const purchase = orderIds.length > 0
      ? await this.prisma.orderItem.findFirst({
          where: {
            productId,
            orderId: { in: orderIds },
          },
        })
      : null;

    const matchedOrder = purchase ? orders.find((o) => o.id === purchase.orderId) : null;

    const existingReview = await this.prisma.productReview.findFirst({
      where: { productId, buyerProfileId: buyer.id },
    });

    return {
      canReview: !!purchase,
      hasPurchased: !!purchase,
      orderNumber: matchedOrder?.orderNumber,
      orderId: purchase?.orderId,
      existingReview: existingReview || null,
    };
  }

  async getMyPurchasedProducts(userId: string) {
    const buyer = await this.prisma.buyerProfile.findUnique({ where: { userId } });
    if (!buyer) return [];

    const orders = await this.prisma.order.findMany({
      where: {
        buyerProfileId: buyer.id,
        status: { not: 'CANCELLED' },
      },
      select: { id: true },
    });
    const orderIds = orders.map((o) => o.id);
    if (orderIds.length === 0) return [];

    const items = await this.prisma.orderItem.findMany({
      where: {
        orderId: { in: orderIds },
      },
      select: { productId: true },
    });

    return [...new Set(items.map((i) => i.productId))];
  }

  async addReview(
    userId: string,
    data: {
      productId: string;
      rating: number;
      title: string;
      comment: string;
      orderId?: string;
    },
  ) {
    const buyer = await this.prisma.buyerProfile.findUnique({ where: { userId } });
    if (!buyer) throw new NotFoundException('Buyer profile required to submit reviews');

    if (data.rating < 1 || data.rating > 5) {
      throw new BadRequestException('Rating must be between 1 and 5 stars');
    }

    if (!data.comment || data.comment.trim().length < 5) {
      throw new BadRequestException('Review comment must be at least 5 characters');
    }

    // Strictly enforce: ONLY available if product has been purchased
    const orders = await this.prisma.order.findMany({
      where: {
        buyerProfileId: buyer.id,
        status: { not: 'CANCELLED' },
      },
      select: { id: true, orderNumber: true, status: true },
    });
    const orderIds = orders.map((o) => o.id);

    const purchase = orderIds.length > 0
      ? await this.prisma.orderItem.findFirst({
          where: {
            productId: data.productId,
            orderId: { in: orderIds },
          },
        })
      : null;

    if (!purchase) {
      throw new BadRequestException('Rating & Review is only available for products you have purchased.');
    }

    // Check if review already exists from this buyer for this product
    const existing = await this.prisma.productReview.findFirst({
      where: {
        productId: data.productId,
        buyerProfileId: buyer.id,
      },
    });

    if (existing) {
      return this.prisma.productReview.update({
        where: { id: existing.id },
        data: {
          rating: data.rating,
          title: data.title || 'Verified Buyer Review',
          comment: data.comment,
          orderId: data.orderId || purchase.orderId,
          isVerifiedPurchase: true,
          isApproved: true,
        },
      });
    }

    return this.prisma.productReview.create({
      data: {
        productId: data.productId,
        buyerProfileId: buyer.id,
        orderId: data.orderId || purchase.orderId,
        rating: data.rating,
        title: data.title || 'Verified Buyer Review',
        comment: data.comment,
        isVerifiedPurchase: true,
        isApproved: true,
      },
    });
  }
}
