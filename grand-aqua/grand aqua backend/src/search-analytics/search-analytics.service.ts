import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SearchAnalyticsService {
  constructor(private prisma: PrismaService) {}

  /**
   * Log or increment a keyword searched by a logged-in buyer
   */
  async logKeyword(userId: string, rawKeyword: string, explicitBuyerProfileId?: string) {
    if (!rawKeyword || typeof rawKeyword !== 'string') {
      return { success: false, message: 'Invalid keyword' };
    }

    const keyword = rawKeyword.trim().toLowerCase();
    if (keyword.length < 2) {
      return { success: false, message: 'Keyword too short' };
    }

    let buyer: any = null;
    if (explicitBuyerProfileId) {
      buyer = await this.prisma.buyerProfile.findUnique({
        where: { id: explicitBuyerProfileId },
      });
    }

    if (!buyer && userId) {
      buyer = await this.prisma.buyerProfile.findUnique({
        where: { userId },
      });
    }

    if (!buyer && userId) {
      // Auto-create buyerProfile if user exists without one
      const user = await this.prisma.user.findUnique({ where: { id: userId } });
      if (user) {
        const count = await this.prisma.buyerProfile.count();
        const buyerId = `GA-B-${1000 + count + 1}`;
        buyer = await this.prisma.buyerProfile.create({
          data: {
            buyerId,
            userId: user.id,
            businessName: user.fullName || 'Customer',
            businessType: 'Retail',
            buyerType: 'CUSTOMER',
            loyaltyTier: 'NONE',
          },
        });
      }
    }

    if (!buyer) {
      return { success: false, message: 'Buyer profile not found for user' };
    }

    const record = await (this.prisma as any).buyerSearchKeyword.upsert({
      where: {
        buyerProfileId_keyword: {
          buyerProfileId: buyer.id,
          keyword,
        },
      },
      create: {
        buyerProfileId: buyer.id,
        keyword,
        searchCount: 1,
        lastSearchedAt: new Date(),
      },
      update: {
        searchCount: { increment: 1 },
        lastSearchedAt: new Date(),
      },
    });

    return record;
  }

  /**
   * Get all buyers who have performed searches, with aggregated search statistics
   */
  async getBuyersWithSearches(search?: string) {
    // 1. Get all search keywords grouped or fetched
    const allKeywords = await (this.prisma as any).buyerSearchKeyword.findMany({
      orderBy: { lastSearchedAt: 'desc' },
    });

    if (!allKeywords || allKeywords.length === 0) {
      return [];
    }

    // 2. Group keywords by buyerProfileId
    const buyerMap = new Map<string, any[]>();
    for (const kw of allKeywords) {
      const list = buyerMap.get(kw.buyerProfileId) || [];
      list.push(kw);
      buyerMap.set(kw.buyerProfileId, list);
    }

    const buyerProfileIds = Array.from(buyerMap.keys());

    // 3. Fetch buyer profiles
    const buyers = await this.prisma.buyerProfile.findMany({
      where: {
        id: { in: buyerProfileIds },
      },
      include: {
        user: true,
      },
    });

    let mapped = buyers.map((b: any) => {
      const keywords: any[] = buyerMap.get(b.id) || [];
      const totalSearches = keywords.reduce((sum: number, k: any) => sum + (k.searchCount || 1), 0);
      const uniqueKeywordsCount = keywords.length;
      const lastSearchedAt = keywords.reduce((latest: Date, k: any) => {
        const d = new Date(k.lastSearchedAt);
        return d > latest ? d : latest;
      }, new Date(0));

      const sortedKeywords = [...keywords].sort((k1, k2) => (k2.searchCount || 1) - (k1.searchCount || 1));
      const topKeywords = sortedKeywords.slice(0, 3).map((k) => ({
        keyword: k.keyword,
        count: k.searchCount,
      }));

      return {
        id: b.id,
        buyerId: b.buyerId,
        businessName: b.businessName || b.user?.fullName || 'Buyer',
        businessType: b.businessType,
        buyerType: b.buyerType,
        fullName: b.user?.fullName || 'Unknown',
        phone: b.user?.phone || '',
        email: b.user?.email || '',
        totalSearches,
        uniqueKeywordsCount,
        lastSearchedAt: lastSearchedAt.getTime() > 0 ? lastSearchedAt.toISOString() : b.updatedAt.toISOString(),
        topKeywords,
      };
    });

    if (search && search.trim().length > 0) {
      const q = search.toLowerCase().trim();
      mapped = mapped.filter((b) =>
        b.fullName.toLowerCase().includes(q) ||
        b.businessName.toLowerCase().includes(q) ||
        b.phone.toLowerCase().includes(q) ||
        b.buyerId.toLowerCase().includes(q) ||
        b.email.toLowerCase().includes(q)
      );
    }

    // Sort by latest search descending
    mapped.sort((a, b) => new Date(b.lastSearchedAt).getTime() - new Date(a.lastSearchedAt).getTime());

    return mapped;
  }

  /**
   * Get all keywords searched by a specific buyer and the frequency/count for each keyword
   */
  async getBuyerSearchKeywords(buyerProfileId: string) {
    const buyer: any = await this.prisma.buyerProfile.findUnique({
      where: { id: buyerProfileId },
      include: {
        user: true,
      },
    });

    if (!buyer) {
      throw new NotFoundException(`Buyer with ID ${buyerProfileId} not found`);
    }

    const keywords: any[] = await (this.prisma as any).buyerSearchKeyword.findMany({
      where: { buyerProfileId },
      orderBy: [
        { searchCount: 'desc' },
        { lastSearchedAt: 'desc' },
      ],
    });

    const totalSearches = keywords.reduce((sum: number, k: any) => sum + (k.searchCount || 1), 0);

    return {
      buyer: {
        id: buyer.id,
        buyerId: buyer.buyerId,
        businessName: buyer.businessName || buyer.user?.fullName,
        buyerType: buyer.buyerType,
        fullName: buyer.user?.fullName,
        phone: buyer.user?.phone,
        email: buyer.user?.email,
      },
      totalSearches,
      uniqueKeywordsCount: keywords.length,
      keywords: keywords.map((k) => ({
        id: k.id,
        keyword: k.keyword,
        searchCount: k.searchCount,
        lastSearchedAt: k.lastSearchedAt,
        createdAt: k.createdAt,
      })),
    };
  }
}
