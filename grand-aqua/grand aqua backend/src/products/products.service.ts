import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BuyerType } from '@prisma/client';

@Injectable()
export class ProductsService {
  constructor(private prisma: PrismaService) {}

  async findAll(query: {
    search?: string;
    categoryId?: string;
    status?: string;
    isFeatured?: boolean;
    buyerType?: BuyerType;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query.page) || 1;
    const limit = Number(query.limit) || 20;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query.status) {
      where.status = query.status;
    } else {
      where.status = 'ACTIVE';
    }

    if (query.isFeatured !== undefined) {
      where.isFeatured = String(query.isFeatured) === 'true';
    }

    if (query.categoryId) {
      where.categoryId = query.categoryId;
    }

    if (query.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { sku: { contains: query.search, mode: 'insensitive' } },
        { brand: { contains: query.search, mode: 'insensitive' } },
        { shortDescription: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    const [total, products] = await Promise.all([
      this.prisma.product.count({ where }),
      this.prisma.product.findMany({
        where,
        skip,
        take: limit,
        include: {
          category: true,
          pricing: true,
          media: {
            orderBy: { displayOrder: 'asc' },
          },
          inventory: true,
          reviews: {
            where: { isApproved: true },
            select: { rating: true },
          },
          _count: {
            select: { orderItems: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    // Format products with applicable price if buyerType is specified
    const formattedProducts = products.map((prod) => {
      let applicablePrice = Number(prod.pricing?.customerPrice || 0);
      if (query.buyerType) {
        if (query.buyerType === BuyerType.DISTRIBUTOR) {
          applicablePrice = Number(prod.pricing?.distributorPrice || applicablePrice);
        } else if (query.buyerType === BuyerType.WHOLESALER) {
          applicablePrice = Number(prod.pricing?.wholesalerPrice || applicablePrice);
        } else if (query.buyerType === BuyerType.DEALER) {
          applicablePrice = Number(prod.pricing?.dealerPrice || applicablePrice);
        }
      }

      const reviews = (prod as any).reviews || [];
      const reviewCount = reviews.length;
      const totalRating = reviews.reduce((sum: number, r: any) => sum + (r.rating || 0), 0);
      const avgRating = reviewCount > 0 ? Number((totalRating / reviewCount).toFixed(1)) : 0;
      const popularity = (prod as any)._count?.orderItems || 0;

      const isBuyerQuery = Boolean(query.buyerType);
      const purchasePrice = isBuyerQuery ? undefined : Number(prod.purchasePrice ?? prod.pricing?.purchasePrice ?? 0);
      let sanitizedPricing = prod.pricing;
      if (isBuyerQuery && sanitizedPricing) {
        const { purchasePrice: _discard, ...rest } = sanitizedPricing as any;
        sanitizedPricing = rest;
      }

      return {
        ...prod,
        purchasePrice,
        pricing: sanitizedPricing,
        applicablePrice,
        stockQuantity: prod.stockQuantity ?? prod.inventory?.currentStock ?? 0,
        isQuantityPricingEnabled: Boolean(prod.isQuantityPricingEnabled),
        quantityPricingSlabs: prod.quantityPricingSlabs || [],
        avgRating,
        reviewCount,
        popularity,
      };
    });

    return {
      products: formattedProducts,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findOne(id: string, buyerType?: BuyerType) {
    const product = await this.prisma.product.findUnique({
      where: { id },
      include: {
        category: true,
        pricing: true,
        media: {
          orderBy: { displayOrder: 'asc' },
        },
        inventory: true,
        reviews: {
          where: { isApproved: true },
          include: {
            buyer: {
              include: { user: true },
            },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!product) {
      throw new NotFoundException(`Product with ID "${id}" not found`);
    }

    let applicablePrice = Number(product.pricing?.customerPrice || 0);
    if (buyerType) {
      if (buyerType === BuyerType.DISTRIBUTOR) {
        applicablePrice = Number(product.pricing?.distributorPrice || applicablePrice);
      } else if (buyerType === BuyerType.WHOLESALER) {
        applicablePrice = Number(product.pricing?.wholesalerPrice || applicablePrice);
      } else if (buyerType === BuyerType.DEALER) {
        applicablePrice = Number(product.pricing?.dealerPrice || applicablePrice);
      }
    }

    const isBuyerQuery = Boolean(buyerType);
    const purchasePrice = isBuyerQuery ? undefined : Number(product.purchasePrice ?? product.pricing?.purchasePrice ?? 0);
    let sanitizedPricing = product.pricing;
    if (isBuyerQuery && sanitizedPricing) {
      const { purchasePrice: _discard, ...rest } = sanitizedPricing as any;
      sanitizedPricing = rest;
    }

    return {
      ...product,
      purchasePrice,
      pricing: sanitizedPricing,
      applicablePrice,
      stockQuantity: product.stockQuantity ?? product.inventory?.currentStock ?? 0,
      isQuantityPricingEnabled: Boolean(product.isQuantityPricingEnabled),
      quantityPricingSlabs: product.quantityPricingSlabs || [],
    };
  }

  async create(data: {
    sku?: string;
    name: string;
    brand?: string;
    categoryId: string;
    shortDescription?: string;
    fullDescription?: string;
    technicalSpecifications?: any;
    modelNumber?: string;
    unitOfMeasurement?: string;
    warrantyDetails?: string;
    isFeatured?: boolean;
    distributorPrice: number;
    wholesalerPrice: number;
    dealerPrice: number;
    customerPrice: number;
    purchasePrice?: number;
    minOrderQuantity?: number;
    taxRate?: number;
    initialStock?: number;
    stock?: number;
    stockQuantity?: number;
    isQuantityPricingEnabled?: boolean;
    quantityPricingSlabs?: any;
    imageUrl?: string;
    videoUrl?: string;
    model3dUrl?: string;
    mediaUrls?: { url: string; mediaType: string; isPrimary: boolean }[];
  }) {
    const sku = data.sku && data.sku.trim().length > 0 
      ? data.sku.trim().toUpperCase() 
      : `GA-${Math.random().toString(36).substring(2, 7).toUpperCase()}`;

    const existing = await this.prisma.product.findUnique({ where: { sku } });
    if (existing) {
      throw new BadRequestException(`Product with SKU "${sku}" already exists`);
    }

    const stockCount = Number(data.stockQuantity ?? data.stock ?? data.initialStock ?? 50);
    let parsedSlabs: any = [];
    if (data.quantityPricingSlabs) {
      try {
        parsedSlabs = typeof data.quantityPricingSlabs === 'string' 
          ? JSON.parse(data.quantityPricingSlabs) 
          : data.quantityPricingSlabs;
      } catch {
        parsedSlabs = [];
      }
    }
    const isQtyEnabled = String(data.isQuantityPricingEnabled) === 'true' || data.isQuantityPricingEnabled === true;

    const assembledMedia: { url: string; mediaType: string; isPrimary: boolean }[] = data.mediaUrls ? [...data.mediaUrls] : [];
    if (data.imageUrl && !assembledMedia.some(m => m.url === data.imageUrl)) {
      assembledMedia.unshift({ url: data.imageUrl, mediaType: 'IMAGE', isPrimary: true });
    }
    if (data.videoUrl && !assembledMedia.some(m => m.url === data.videoUrl)) {
      assembledMedia.push({ url: data.videoUrl, mediaType: 'VIDEO', isPrimary: false });
    }
    if (data.model3dUrl && !assembledMedia.some(m => m.url === data.model3dUrl)) {
      assembledMedia.push({ url: data.model3dUrl, mediaType: '3D_MODEL', isPrimary: false });
    }

    return this.prisma.$transaction(async (tx) => {
      const product = await tx.product.create({
        data: {
          sku,
          name: data.name,
          brand: data.brand || 'Grand Aqua',
          categoryId: data.categoryId,
          shortDescription: data.shortDescription,
          fullDescription: data.fullDescription,
          technicalSpecifications: data.technicalSpecifications,
          modelNumber: data.modelNumber,
          unitOfMeasurement: data.unitOfMeasurement || 'Piece',
          warrantyDetails: data.warrantyDetails || '1 Year Manufacturer Warranty',
          stockQuantity: stockCount,
          isQuantityPricingEnabled: isQtyEnabled,
          quantityPricingSlabs: parsedSlabs,
          isFeatured: data.isFeatured || false,
          purchasePrice: data.purchasePrice !== undefined ? Number(data.purchasePrice) : 0,
          pricing: {
            create: {
              distributorPrice: Number(data.distributorPrice || 0),
              wholesalerPrice: Number(data.wholesalerPrice || 0),
              dealerPrice: Number(data.dealerPrice || 0),
              customerPrice: Number(data.customerPrice || 0),
              purchasePrice: data.purchasePrice !== undefined ? Number(data.purchasePrice) : 0,
              minOrderQuantity: data.minOrderQuantity || 1,
              taxRate: data.taxRate !== undefined ? Number(data.taxRate) : 18.0,
            },
          },
          inventory: {
            create: {
              currentStock: stockCount,
              reorderLevel: 5,
            },
          },
          media: assembledMedia.length
            ? {
                create: assembledMedia.map((m, idx) => ({
                  url: m.url,
                  mediaType: m.mediaType || 'IMAGE',
                  isPrimary: m.isPrimary || idx === 0,
                  displayOrder: idx,
                })),
              }
            : undefined,
        },
        include: {
          category: true,
          pricing: true,
          media: true,
          inventory: true,
        },
      });

      return product;
    });
  }

  async updatePricing(
    productId: string,
    pricingData: {
      distributorPrice?: number;
      wholesalerPrice?: number;
      dealerPrice?: number;
      customerPrice?: number;
      purchasePrice?: number;
      reason?: string;
      changedBy?: string;
    },
  ) {
    const currentPrice = await this.prisma.productPrice.findUnique({
      where: { productId },
    });

    if (!currentPrice) {
      throw new NotFoundException('Product pricing not found');
    }

    // Save price history
    const updates: any = {};
    if (pricingData.distributorPrice !== undefined) {
      updates.distributorPrice = pricingData.distributorPrice;
      await this.prisma.productPriceHistory.create({
        data: {
          productId,
          priceType: BuyerType.DISTRIBUTOR,
          oldPrice: currentPrice.distributorPrice,
          newPrice: pricingData.distributorPrice,
          reason: pricingData.reason || 'Admin pricing update',
          changedBy: pricingData.changedBy || 'Admin',
        },
      });
    }

    if (pricingData.wholesalerPrice !== undefined) {
      updates.wholesalerPrice = pricingData.wholesalerPrice;
      await this.prisma.productPriceHistory.create({
        data: {
          productId,
          priceType: BuyerType.WHOLESALER,
          oldPrice: currentPrice.wholesalerPrice,
          newPrice: pricingData.wholesalerPrice,
          reason: pricingData.reason || 'Admin pricing update',
          changedBy: pricingData.changedBy || 'Admin',
        },
      });
    }

    if (pricingData.dealerPrice !== undefined) {
      updates.dealerPrice = pricingData.dealerPrice;
      await this.prisma.productPriceHistory.create({
        data: {
          productId,
          priceType: BuyerType.DEALER,
          oldPrice: currentPrice.dealerPrice,
          newPrice: pricingData.dealerPrice,
          reason: pricingData.reason || 'Admin pricing update',
          changedBy: pricingData.changedBy || 'Admin',
        },
      });
    }

    if (pricingData.customerPrice !== undefined) {
      updates.customerPrice = pricingData.customerPrice;
      await this.prisma.productPriceHistory.create({
        data: {
          productId,
          priceType: BuyerType.CUSTOMER,
          oldPrice: currentPrice.customerPrice,
          newPrice: pricingData.customerPrice,
          reason: pricingData.reason || 'Admin pricing update',
          changedBy: pricingData.changedBy || 'Admin',
        },
      });
    }

    if (pricingData.purchasePrice !== undefined) {
      updates.purchasePrice = Number(pricingData.purchasePrice);
      await this.prisma.product.update({
        where: { id: productId },
        data: { purchasePrice: Number(pricingData.purchasePrice) },
      });
    }

    return this.prisma.productPrice.update({
      where: { productId },
      data: updates,
    });
  }

  async getCategories() {
    const categories = await this.prisma.productCategory.findMany({
      orderBy: { name: 'asc' },
    });

    const categoriesWithCount = await Promise.all(
      categories.map(async (cat) => {
        const count = await this.prisma.product.count({
          where: { categoryId: cat.id },
        });
        return {
          ...cat,
          _count: { products: count },
        };
      }),
    );

    return categoriesWithCount;
  }

  async getCategoryById(id: string) {
    const category = await this.prisma.productCategory.findUnique({
      where: { id },
    });
    if (!category) throw new NotFoundException('Category not found');
    const count = await this.prisma.product.count({
      where: { categoryId: id },
    });
    return {
      ...category,
      _count: { products: count },
    };
  }

  async createCategory(data: {
    name: string;
    slug?: string;
    description?: string;
    image?: string;
    isActive?: boolean;
    parentId?: string;
  }) {
    let slug = data.slug?.trim();
    if (!slug) {
      slug = data.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)+/g, '');
    }
    const existing = await this.prisma.productCategory.findUnique({ where: { slug } });
    if (existing) {
      slug = `${slug}-${Date.now().toString().slice(-4)}`;
    }

    return this.prisma.productCategory.create({
      data: {
        name: data.name.trim(),
        slug,
        description: data.description?.trim() || null,
        image: data.image?.trim() || null,
        isActive: data.isActive !== undefined ? data.isActive : true,
        parentId: data.parentId?.trim() || null,
      },
      include: {
        _count: { select: { products: true } },
      },
    });
  }

  async updateCategory(
    id: string,
    data: {
      name?: string;
      slug?: string;
      description?: string;
      image?: string;
      isActive?: boolean;
      parentId?: string;
    },
  ) {
    const existing = await this.prisma.productCategory.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Category not found');

    let slug = data.slug?.trim();
    if (slug && slug !== existing.slug) {
      const duplicate = await this.prisma.productCategory.findUnique({ where: { slug } });
      if (duplicate && duplicate.id !== id) {
        slug = `${slug}-${Date.now().toString().slice(-4)}`;
      }
    }

    return this.prisma.productCategory.update({
      where: { id },
      data: {
        ...(data.name ? { name: data.name.trim() } : {}),
        ...(slug ? { slug } : {}),
        ...(data.description !== undefined ? { description: data.description } : {}),
        ...(data.image !== undefined ? { image: data.image } : {}),
        ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
        ...(data.parentId !== undefined ? { parentId: data.parentId || null } : {}),
      },
      include: {
        _count: { select: { products: true } },
      },
    });
  }

  async deleteCategory(id: string) {
    const existing = await this.prisma.productCategory.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('Category not found');

    const productCount = await this.prisma.product.count({
      where: { categoryId: id },
    });

    if (productCount > 0) {
      throw new BadRequestException(
        `Cannot delete category "${existing.name}" because it contains ${productCount} products. Please reassign or delete these products first.`,
      );
    }

    return this.prisma.productCategory.delete({
      where: { id },
    });
  }

  async updateProduct(id: string, data: any) {
    const existing = await this.prisma.product.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Product not found');

    return this.prisma.$transaction(async (tx) => {
      let parsedSlabs: any = undefined;
      if (data.quantityPricingSlabs !== undefined) {
        try {
          parsedSlabs = typeof data.quantityPricingSlabs === 'string'
            ? JSON.parse(data.quantityPricingSlabs)
            : data.quantityPricingSlabs;
        } catch {
          parsedSlabs = [];
        }
      }

      const stockCount = data.stockQuantity !== undefined
        ? Number(data.stockQuantity)
        : data.stock !== undefined
        ? Number(data.stock)
        : data.currentStock !== undefined
        ? Number(data.currentStock)
        : data.initialStock !== undefined
        ? Number(data.initialStock)
        : undefined;

      const isQtyEnabled = data.isQuantityPricingEnabled !== undefined
        ? (String(data.isQuantityPricingEnabled) === 'true' || data.isQuantityPricingEnabled === true)
        : undefined;

      // 1. Update core product details
      const product = await tx.product.update({
        where: { id },
        data: {
          name: data.name ?? existing.name,
          categoryId: data.categoryId ?? existing.categoryId,
          shortDescription: data.shortDescription ?? existing.shortDescription,
          fullDescription: data.fullDescription ?? existing.fullDescription,
          brand: data.brand ?? existing.brand,
          status: data.status ?? existing.status,
          stockQuantity: stockCount !== undefined ? stockCount : undefined,
          isQuantityPricingEnabled: isQtyEnabled !== undefined ? isQtyEnabled : undefined,
          quantityPricingSlabs: parsedSlabs !== undefined ? parsedSlabs : undefined,
          isFeatured: data.isFeatured !== undefined ? data.isFeatured : existing.isFeatured,
          purchasePrice: data.purchasePrice !== undefined ? Number(data.purchasePrice) : undefined,
        },
      });

      // 2. Update pricing if provided
      if (
        data.distributorPrice !== undefined ||
        data.wholesalerPrice !== undefined ||
        data.dealerPrice !== undefined ||
        data.customerPrice !== undefined ||
        data.purchasePrice !== undefined
      ) {
        await tx.productPrice.upsert({
          where: { productId: id },
          create: {
            productId: id,
            distributorPrice: Number(data.distributorPrice || 0),
            wholesalerPrice: Number(data.wholesalerPrice || 0),
            dealerPrice: Number(data.dealerPrice || 0),
            customerPrice: Number(data.customerPrice || 0),
            purchasePrice: data.purchasePrice !== undefined ? Number(data.purchasePrice) : 0,
          },
          update: {
            distributorPrice: data.distributorPrice !== undefined ? Number(data.distributorPrice) : undefined,
            wholesalerPrice: data.wholesalerPrice !== undefined ? Number(data.wholesalerPrice) : undefined,
            dealerPrice: data.dealerPrice !== undefined ? Number(data.dealerPrice) : undefined,
            customerPrice: data.customerPrice !== undefined ? Number(data.customerPrice) : undefined,
            purchasePrice: data.purchasePrice !== undefined ? Number(data.purchasePrice) : undefined,
          },
        });
      }

      // 3. Update stock/inventory if provided
      if (stockCount !== undefined) {
        await tx.inventoryItem.upsert({
          where: { productId: id },
          create: {
            productId: id,
            currentStock: stockCount,
            reorderLevel: 5,
          },
          update: {
            currentStock: stockCount,
          },
        });
      }

      // 4. Update media if provided (either mediaUrls array or direct imageUrl/videoUrl/model3dUrl)
      let assembledMedia: { url: string; mediaType: string; isPrimary: boolean }[] | null = null;
      if (data.mediaUrls && Array.isArray(data.mediaUrls)) {
        assembledMedia = [...data.mediaUrls];
      } else if (data.imageUrl !== undefined || data.videoUrl !== undefined || data.model3dUrl !== undefined) {
        assembledMedia = [];
        if (data.imageUrl) {
          assembledMedia.push({ url: data.imageUrl, mediaType: 'IMAGE', isPrimary: true });
        }
        if (data.videoUrl) {
          assembledMedia.push({ url: data.videoUrl, mediaType: 'VIDEO', isPrimary: false });
        }
        if (data.model3dUrl) {
          assembledMedia.push({ url: data.model3dUrl, mediaType: '3D_MODEL', isPrimary: false });
        }
      }

      if (assembledMedia !== null) {
        await tx.productMedia.deleteMany({ where: { productId: id } });
        for (let idx = 0; idx < assembledMedia.length; idx++) {
          const m = assembledMedia[idx];
          if (m.url && m.url.trim().length > 0) {
            await tx.productMedia.create({
              data: {
                productId: id,
                url: m.url.trim(),
                mediaType: m.mediaType || 'IMAGE',
                isPrimary: m.isPrimary || idx === 0,
                displayOrder: idx,
              },
            });
          }
        }
      }

      const updated = await tx.product.findUnique({
        where: { id },
        include: { category: true, pricing: true, media: true, inventory: true },
      });
      return {
        ...updated,
        stockQuantity: updated?.stockQuantity ?? updated?.inventory?.currentStock ?? 0,
        isQuantityPricingEnabled: Boolean(updated?.isQuantityPricingEnabled),
        quantityPricingSlabs: updated?.quantityPricingSlabs || [],
      };
    });
  }

  async deleteProduct(id: string) {
    const existing = await this.prisma.product.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Product not found');

    return this.prisma.$transaction(async (tx) => {
      await tx.productMedia.deleteMany({ where: { productId: id } });
      await tx.productPrice.deleteMany({ where: { productId: id } });
      await tx.productPriceHistory.deleteMany({ where: { productId: id } });
      await tx.inventoryItem.deleteMany({ where: { productId: id } });
      await tx.productReview.deleteMany({ where: { productId: id } });
      await tx.quotationItem.deleteMany({ where: { productId: id } });
      await tx.orderItem.deleteMany({ where: { productId: id } });
      return tx.product.delete({ where: { id } });
    });
  }
}
