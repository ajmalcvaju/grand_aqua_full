import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BannerAudienceType } from '@prisma/client';

@Injectable()
export class BannersService {
  constructor(private prisma: PrismaService) {}

  /**
   * Admin: Create a new promotional banner with audience targeting
   */
  async createBanner(data: {
    title: string;
    subtitle?: string;
    imageUrl: string;
    actionUrl?: string;
    targetType?: string;
    targetId?: string;
    audienceType: BannerAudienceType;
    selectedBuyerIds?: string[];
    displayOrder?: number;
    isActive?: boolean;
    startDate?: string;
    endDate?: string;
  }) {
    if (!data.title || !data.imageUrl) {
      throw new BadRequestException('Title and Image URL are required');
    }

    if (
      (data.audienceType === BannerAudienceType.SPECIFIC_BUYERS ||
        data.audienceType === BannerAudienceType.EXCLUDE_BUYERS) &&
      (!data.selectedBuyerIds || data.selectedBuyerIds.length === 0)
    ) {
      throw new BadRequestException('Please select at least one buyer for this audience type');
    }

    return this.prisma.banner.create({
      data: {
        title: data.title,
        subtitle: data.subtitle,
        imageUrl: data.imageUrl,
        actionUrl: data.actionUrl,
        targetType: data.targetType || 'NONE',
        targetId: data.targetId,
        audienceType: data.audienceType || BannerAudienceType.ALL_BUYERS,
        selectedBuyerIds: data.selectedBuyerIds || [],
        displayOrder: Number(data.displayOrder) || 0,
        isActive: data.isActive !== undefined ? Boolean(data.isActive) : true,
        startDate: data.startDate ? new Date(data.startDate) : null,
        endDate: data.endDate ? new Date(data.endDate) : null,
      },
    });
  }

  /**
   * Admin: Get all banners with details
   */
  async getAllBanners() {
    const banners = await this.prisma.banner.findMany({
      orderBy: [{ displayOrder: 'asc' }, { createdAt: 'desc' }],
    });

    // Populate selected buyer names for convenience
    const allBuyerIds = new Set<string>();
    banners.forEach((b) => {
      (b.selectedBuyerIds || []).forEach((id) => allBuyerIds.add(id));
    });

    const buyers = await this.prisma.buyerProfile.findMany({
      where: { id: { in: Array.from(allBuyerIds) } },
      include: { user: { select: { fullName: true, phone: true } } },
    });

    const buyerMap = new Map<string, { id: string; name: string; businessName: string; buyerType: string }>();
    buyers.forEach((b) => {
      buyerMap.set(b.id, {
        id: b.id,
        name: b.user.fullName,
        businessName: b.businessName || b.user.fullName,
        buyerType: b.buyerType,
      });
    });

    return banners.map((b) => ({
      ...b,
      selectedBuyers: (b.selectedBuyerIds || []).map((id) => buyerMap.get(id)).filter(Boolean),
    }));
  }

  /**
   * Admin: Get a single banner by ID
   */
  async getBannerById(id: string) {
    const banner = await this.prisma.banner.findUnique({
      where: { id },
    });
    if (!banner) throw new NotFoundException(`Banner ${id} not found`);
    return banner;
  }

  /**
   * Admin: Update an existing banner
   */
  async updateBanner(
    id: string,
    data: {
      title?: string;
      subtitle?: string;
      imageUrl?: string;
      actionUrl?: string;
      targetType?: string;
      targetId?: string;
      audienceType?: BannerAudienceType;
      selectedBuyerIds?: string[];
      displayOrder?: number;
      isActive?: boolean;
      startDate?: string;
      endDate?: string;
    },
  ) {
    await this.getBannerById(id);

    return this.prisma.banner.update({
      where: { id },
      data: {
        ...(data.title !== undefined && { title: data.title }),
        ...(data.subtitle !== undefined && { subtitle: data.subtitle }),
        ...(data.imageUrl !== undefined && { imageUrl: data.imageUrl }),
        ...(data.actionUrl !== undefined && { actionUrl: data.actionUrl }),
        ...(data.targetType !== undefined && { targetType: data.targetType }),
        ...(data.targetId !== undefined && { targetId: data.targetId }),
        ...(data.audienceType !== undefined && { audienceType: data.audienceType }),
        ...(data.selectedBuyerIds !== undefined && { selectedBuyerIds: data.selectedBuyerIds }),
        ...(data.displayOrder !== undefined && { displayOrder: Number(data.displayOrder) }),
        ...(data.isActive !== undefined && { isActive: Boolean(data.isActive) }),
        ...(data.startDate !== undefined && { startDate: data.startDate ? new Date(data.startDate) : null }),
        ...(data.endDate !== undefined && { endDate: data.endDate ? new Date(data.endDate) : null }),
      },
    });
  }

  /**
   * Admin: Delete a banner
   */
  async deleteBanner(id: string) {
    await this.getBannerById(id);
    return this.prisma.banner.delete({ where: { id } });
  }

  /**
   * Buyer Feed: Returns active banners strictly targeted to the logged-in buyer
   */
  async getBuyerFeed(userId: string) {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { userId },
    });

    const now = new Date();

    const activeBanners = await this.prisma.banner.findMany({
      where: {
        isActive: true,
      },
      orderBy: [{ displayOrder: 'asc' }, { createdAt: 'desc' }],
    });

    return activeBanners.filter((b) => {
      // 1. Date range filter
      if (b.startDate && new Date(b.startDate) > now) return false;
      if (b.endDate && new Date(b.endDate) < now) return false;

      // If user has no buyer profile yet, only show ALL_BUYERS
      if (!buyer) {
        return b.audienceType === BannerAudienceType.ALL_BUYERS;
      }

      // 2. Audience targeting rules
      switch (b.audienceType) {
        case BannerAudienceType.ALL_BUYERS:
          return true;

        case BannerAudienceType.ALL_WHOLESALERS:
          return buyer.buyerType === 'WHOLESALER';

        case BannerAudienceType.ALL_DISTRIBUTORS:
          return buyer.buyerType === 'DISTRIBUTOR';

        case BannerAudienceType.ALL_DEALERS:
          return buyer.buyerType === 'DEALER';

        case BannerAudienceType.ALL_CUSTOMERS:
          return buyer.buyerType === 'CUSTOMER';

        case BannerAudienceType.SPECIFIC_BUYERS:
          return Array.isArray(b.selectedBuyerIds) && b.selectedBuyerIds.includes(buyer.id);

        case BannerAudienceType.EXCLUDE_BUYERS:
          return !Array.isArray(b.selectedBuyerIds) || !b.selectedBuyerIds.includes(buyer.id);

        default:
          return true;
      }
    });
  }
}
