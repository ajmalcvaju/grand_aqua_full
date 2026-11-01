import { PrismaClient, BuyerType, LoyaltyTierLevel, UserRoleType, AccountStatus, QuotationStatus, OrderStatus, PaymentStatus, PaymentMethod } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding Grand Aqua database with production-grade test data...');

  const passwordHash = await bcrypt.hash('GrandAqua@Admin2026', 10);
  const salesmanPasswordHash = await bcrypt.hash('Salesman@2026', 10);

  // 1. Company Settings
  await prisma.companySettings.upsert({
    where: { key: 'COMPANY_NAME' },
    update: {},
    create: { key: 'COMPANY_NAME', value: 'Grand Aqua', description: 'Official Business Name' },
  });
  await prisma.companySettings.upsert({
    where: { key: 'COMPANY_TAGLINE' },
    update: {},
    create: { key: 'COMPANY_TAGLINE', value: 'Pure | Safe | Healthy - Wholesale & Retail', description: 'Tagline' },
  });
  await prisma.companySettings.upsert({
    where: { key: 'COMPANY_GSTIN' },
    update: {},
    create: { key: 'COMPANY_GSTIN', value: '07AAAAA0000A1Z5', description: 'Registered GSTIN' },
  });
  await prisma.companySettings.upsert({
    where: { key: 'COMPANY_PHONE' },
    update: {},
    create: { key: 'COMPANY_PHONE', value: '+91 98765 43210', description: 'Support Phone' },
  });
  await prisma.companySettings.upsert({
    where: { key: 'COMPANY_EMAIL' },
    update: {},
    create: { key: 'COMPANY_EMAIL', value: 'support@grandaqua.com', description: 'Support Email' },
  });

  // 2. Loyalty Tiers
  const diamondTier = await prisma.loyaltyTier.upsert({
    where: { tierLevel: LoyaltyTierLevel.DIAMOND },
    update: {},
    create: {
      tierLevel: LoyaltyTierLevel.DIAMOND,
      name: 'Diamond Member',
      minPurchaseValue: 1000000,
      minOrderCount: 15,
      benefitsDescription: '5% extra discount on catalogue orders, priority dispatch within 12 hours, dedicated credit facility, free annual service spares',
      colorHex: '#0284c7',
    },
  });

  const goldTier = await prisma.loyaltyTier.upsert({
    where: { tierLevel: LoyaltyTierLevel.GOLD },
    update: {},
    create: {
      tierLevel: LoyaltyTierLevel.GOLD,
      name: 'Gold Member',
      minPurchaseValue: 500000,
      minOrderCount: 10,
      benefitsDescription: '3% extra discount on catalogue orders, 15-day credit cycle, discounted spare parts kits',
      colorHex: '#eab308',
    },
  });

  const platinumTier = await prisma.loyaltyTier.upsert({
    where: { tierLevel: LoyaltyTierLevel.PLATINUM },
    update: {},
    create: {
      tierLevel: LoyaltyTierLevel.PLATINUM,
      name: 'Platinum Member',
      minPurchaseValue: 200000,
      minOrderCount: 5,
      benefitsDescription: '2% bonus savings, seasonal promotional vouchers, standard warranty upgrades',
      colorHex: '#64748b',
    },
  });

  // 3. Super Admin User
  const superAdmin = await prisma.user.upsert({
    where: { email: 'admin@grandaqua.com' },
    update: {},
    create: {
      email: 'admin@grandaqua.com',
      phone: '+919999900000',
      fullName: 'Super Administrator',
      passwordHash,
      role: UserRoleType.SUPER_ADMIN,
      status: AccountStatus.ACTIVE,
    },
  });

  // 4. Salesmen
  const smUser1 = await prisma.user.upsert({
    where: { email: 'amit.sharma@grandaqua.com' },
    update: {},
    create: {
      email: 'amit.sharma@grandaqua.com',
      phone: '+919876500001',
      fullName: 'Amit Sharma',
      passwordHash: salesmanPasswordHash,
      role: UserRoleType.SALESMAN,
      status: AccountStatus.ACTIVE,
      salesmanProfile: {
        create: {
          employeeCode: 'GA-SM-001',
          assignedTerritory: 'North Delhi & NCR',
          monthlySalesTarget: 600000,
          quarterlySalesTarget: 1800000,
          activeShopsCount: 12,
        },
      },
    },
    include: { salesmanProfile: true },
  });

  const smUser2 = await prisma.user.upsert({
    where: { email: 'vikram.singh@grandaqua.com' },
    update: {},
    create: {
      email: 'vikram.singh@grandaqua.com',
      phone: '+919876500002',
      fullName: 'Vikram Singh',
      passwordHash: salesmanPasswordHash,
      role: UserRoleType.SALESMAN,
      status: AccountStatus.ACTIVE,
      salesmanProfile: {
        create: {
          employeeCode: 'GA-SM-002',
          assignedTerritory: 'Mumbai South & Suburbs',
          monthlySalesTarget: 750000,
          quarterlySalesTarget: 2200000,
          activeShopsCount: 15,
        },
      },
    },
    include: { salesmanProfile: true },
  });

  // 5. Product Categories
  const catDomestic = await prisma.productCategory.upsert({
    where: { slug: 'domestic-ro' },
    update: {},
    create: { name: 'Domestic RO Systems', slug: 'domestic-ro', description: 'Advanced domestic RO+UV+UF+Alkaline water purifiers' },
  });

  const catCommercial = await prisma.productCategory.upsert({
    where: { slug: 'commercial-ro' },
    update: {},
    create: { name: 'Commercial RO Plants', slug: 'commercial-ro', description: 'High-capacity 25-500 LPH plants for offices and factories' },
  });

  const catSpares = await prisma.productCategory.upsert({
    where: { slug: 'spares-filters' },
    update: {},
    create: { name: 'Membranes & Spare Filters', slug: 'spares-filters', description: 'Original RO membranes, sediment filters, and booster pumps' },
  });

  // 6. Products with 4-Tier Pricing
  const prod1 = await prisma.product.upsert({
    where: { sku: 'GA-RO-12L-ALK' },
    update: {},
    create: {
      sku: 'GA-RO-12L-ALK',
      name: 'Grand Aqua Alkaline Mineral RO+UV+UF 12L',
      brand: 'Grand Aqua',
      categoryId: catDomestic.id,
      shortDescription: '12-stage purification with natural alkaline mineralizer and copper enrichment',
      fullDescription: 'Equipped with heavy-duty 100 GPD membrane, UV disinfection chamber, and 12-litre food-grade antibacterial storage tank.',
      modelNumber: 'GA-DOM-2026',
      unitOfMeasurement: 'Piece',
      isFeatured: true,
      pricing: {
        create: {
          distributorPrice: 5500,
          wholesalerPrice: 6500,
          dealerPrice: 7800,
          customerPrice: 12999,
          taxRate: 18.0,
        },
      },
      inventory: { create: { currentStock: 85, reorderLevel: 10 } },
      media: {
        create: [
          { url: 'https://images.unsplash.com/photo-1542013936693-884638332954?auto=format&fit=crop&w=600&q=80', mediaType: 'IMAGE', isPrimary: true, displayOrder: 0 },
        ],
      },
    },
  });

  const prod2 = await prisma.product.upsert({
    where: { sku: 'GA-COMM-50LPH' },
    update: {},
    create: {
      sku: 'GA-COMM-50LPH',
      name: 'Grand Aqua Commercial 50 LPH Stainless Steel RO Plant',
      brand: 'Grand Aqua',
      categoryId: catCommercial.id,
      shortDescription: 'Heavy-duty 50 litres per hour commercial RO plant for schools, offices, and restaurants',
      fullDescription: 'Includes dual 150 GPD pumps, stainless steel frame skid, pressure gauge meters, and automatic flush valve.',
      modelNumber: 'GA-COM-50',
      unitOfMeasurement: 'Unit',
      isFeatured: true,
      pricing: {
        create: {
          distributorPrice: 18000,
          wholesalerPrice: 22000,
          dealerPrice: 26000,
          customerPrice: 38000,
          taxRate: 18.0,
        },
      },
      inventory: { create: { currentStock: 25, reorderLevel: 5 } },
      media: {
        create: [
          { url: 'https://images.unsplash.com/photo-1585829365295-ab7cd400c167?auto=format&fit=crop&w=600&q=80', mediaType: 'IMAGE', isPrimary: true, displayOrder: 0 },
        ],
      },
    },
  });

  const prod3 = await prisma.product.upsert({
    where: { sku: 'GA-MEMB-100GPD' },
    update: {},
    create: {
      sku: 'GA-MEMB-100GPD',
      name: 'Grand Aqua 100 GPD High-TDS RO Membrane (Pack of 10)',
      brand: 'Grand Aqua',
      categoryId: catSpares.id,
      shortDescription: 'Advanced polyamide thin-film composite membrane supporting up to 2500 ppm TDS',
      fullDescription: 'High salt rejection rate of 97%, optimal for hard water conditions across all regions.',
      modelNumber: 'GA-MEM-10X',
      unitOfMeasurement: 'Pack',
      pricing: {
        create: {
          distributorPrice: 4500,
          wholesalerPrice: 5200,
          dealerPrice: 6000,
          customerPrice: 8500,
          taxRate: 18.0,
        },
      },
      inventory: { create: { currentStock: 150, reorderLevel: 20 } },
      media: {
        create: [
          { url: 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=600&q=80', mediaType: 'IMAGE', isPrimary: true, displayOrder: 0 },
        ],
      },
    },
  });

  // 7. Business Buyers across categories
  // 7a. Distributor
  const buyerUser1 = await prisma.user.upsert({
    where: { email: 'apex.distributors@gmail.com' },
    update: {},
    create: {
      email: 'apex.distributors@gmail.com',
      phone: '+919811122233',
      fullName: 'Apex Water Systems (Distributor)',
      role: UserRoleType.BUYER,
      status: AccountStatus.ACTIVE,
      buyerProfile: {
        create: {
          buyerId: 'GA-B-1001',
          businessName: 'Apex Water Systems Distribution Pvt Ltd',
          businessType: 'Regional Water Treatment Distributor',
          gstin: '07AAACA1234A1Z1',
          district: 'New Delhi',
          state: 'Delhi',
          pinCode: '110020',
          buyerType: BuyerType.DISTRIBUTOR,
          loyaltyTier: LoyaltyTierLevel.DIAMOND,
          assignedSalesmanId: smUser1.salesmanProfile?.id,
          creditLimit: 500000,
          outstandingBalance: 125000,
          paymentTerms: '30 Days Net Credit',
          creditAccount: {
            create: {
              creditLimit: 500000,
              utilizedCredit: 125000,
              availableCredit: 375000,
              paymentTermsDays: 30,
              status: 'ACTIVE',
            },
          },
        },
      },
    },
    include: { buyerProfile: true },
  });

  // 7b. Wholesaler
  const buyerUser2 = await prisma.user.upsert({
    where: { email: 'jal.wholesale@gmail.com' },
    update: {},
    create: {
      email: 'jal.wholesale@gmail.com',
      phone: '+919822233344',
      fullName: 'Jal Purifier Traders (Wholesaler)',
      role: UserRoleType.BUYER,
      status: AccountStatus.ACTIVE,
      buyerProfile: {
        create: {
          buyerId: 'GA-B-1002',
          businessName: 'Jal Purifier & Electricals Wholesale',
          businessType: 'Wholesale Distributor',
          gstin: '27AAACB2345B1Z2',
          district: 'Mumbai Suburbs',
          state: 'Maharashtra',
          pinCode: '400050',
          buyerType: BuyerType.WHOLESALER,
          loyaltyTier: LoyaltyTierLevel.GOLD,
          assignedSalesmanId: smUser2.salesmanProfile?.id,
          creditLimit: 200000,
          outstandingBalance: 45000,
          paymentTerms: '15 Days Net Credit',
          creditAccount: {
            create: {
              creditLimit: 200000,
              utilizedCredit: 45000,
              availableCredit: 155000,
              paymentTermsDays: 15,
              status: 'ACTIVE',
            },
          },
        },
      },
    },
    include: { buyerProfile: true },
  });

  // 7c. Dealer
  const buyerUser3 = await prisma.user.upsert({
    where: { email: 'shree.enterprises@gmail.com' },
    update: {},
    create: {
      email: 'shree.enterprises@gmail.com',
      phone: '+919833344455',
      fullName: 'Shree Enterprise (Dealer)',
      role: UserRoleType.BUYER,
      status: AccountStatus.ACTIVE,
      buyerProfile: {
        create: {
          buyerId: 'GA-B-1003',
          businessName: 'Shree Aqua Care & Spares Retail Shop',
          businessType: 'Retail & Service Dealer',
          gstin: '07AAACC3456C1Z3',
          district: 'North Delhi',
          state: 'Delhi',
          pinCode: '110007',
          buyerType: BuyerType.DEALER,
          loyaltyTier: LoyaltyTierLevel.PLATINUM,
          assignedSalesmanId: smUser1.salesmanProfile?.id,
          creditLimit: 100000,
          outstandingBalance: 15000,
          paymentTerms: '7 Days Net Credit',
          creditAccount: {
            create: {
              creditLimit: 100000,
              utilizedCredit: 15000,
              availableCredit: 85000,
              paymentTermsDays: 7,
              status: 'ACTIVE',
            },
          },
        },
      },
    },
    include: { buyerProfile: true },
  });

  // 7d. Retail Customer
  const buyerUser4 = await prisma.user.upsert({
    where: { email: 'rahul.verma@gmail.com' },
    update: {},
    create: {
      email: 'rahul.verma@gmail.com',
      phone: '+919844455566',
      fullName: 'Rahul Verma',
      role: UserRoleType.BUYER,
      status: AccountStatus.ACTIVE,
      buyerProfile: {
        create: {
          buyerId: 'GA-B-1004',
          businessName: 'Individual Household',
          businessType: 'Retail Customer',
          district: 'South Delhi',
          state: 'Delhi',
          pinCode: '110017',
          buyerType: BuyerType.CUSTOMER,
          loyaltyTier: LoyaltyTierLevel.NONE,
          creditLimit: 0,
          outstandingBalance: 0,
          paymentTerms: 'Immediate Payment',
        },
      },
    },
    include: { buyerProfile: true },
  });

  // 8. Gift Vouchers
  await prisma.giftVoucher.upsert({
    where: { code: 'AQUA500' },
    update: {},
    create: {
      code: 'AQUA500',
      title: 'Flat ₹500 off on water purifiers',
      voucherValue: 500,
      isPercentage: false,
      minOrderValue: 5000,
      maxUsesTotal: 500,
      maxUsesPerBuyer: 2,
      validFrom: new Date(),
      validUntil: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000),
      status: 'ACTIVE',
    },
  });

  await prisma.giftVoucher.upsert({
    where: { code: 'DIAMOND5' },
    update: {},
    create: {
      code: 'DIAMOND5',
      title: '5% bonus savings for Diamond members',
      voucherValue: 5,
      isPercentage: true,
      minOrderValue: 25000,
      maxUsesTotal: 200,
      maxUsesPerBuyer: 5,
      validFrom: new Date(),
      validUntil: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
      status: 'ACTIVE',
      targetLoyaltyTier: LoyaltyTierLevel.DIAMOND,
    },
  });

  // 9. Sample Quotations
  if (buyerUser1.buyerProfile && smUser1.salesmanProfile) {
    const q1 = await prisma.quotation.upsert({
      where: { quotationNumber: 'GA-QT-2026-0001' },
      update: {},
      create: {
        quotationNumber: 'GA-QT-2026-0001',
        buyerProfileId: buyerUser1.buyerProfile.id,
        salesmanProfileId: smUser1.salesmanProfile.id,
        status: QuotationStatus.ISSUED,
        validUntil: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000),
        subtotal: 55000,
        taxAmount: 9900,
        finalTotal: 64900,
        additionalDiscountApproved: 0,
        paymentTerms: '30 Days Net Credit',
        items: {
          create: [
            {
              productId: prod1.id,
              sku: prod1.sku,
              productName: prod1.name,
              quantity: 10,
              unitPrice: 5500, // Distributor price snapshot
              taxRate: 18.0,
              taxAmount: 9900,
              totalPrice: 64900,
            },
          ],
        },
      },
    });
  }

  // Sample Quotation awaiting discount approval
  if (buyerUser3.buyerProfile && smUser1.salesmanProfile) {
    await prisma.quotation.upsert({
      where: { quotationNumber: 'GA-QT-2026-0002' },
      update: {},
      create: {
        quotationNumber: 'GA-QT-2026-0002',
        buyerProfileId: buyerUser3.buyerProfile.id,
        salesmanProfileId: smUser1.salesmanProfile.id,
        status: QuotationStatus.PENDING_DISCOUNT_APPROVAL,
        validUntil: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000),
        subtotal: 39000,
        taxAmount: 7020,
        additionalDiscountRequested: 2000,
        discountApprovalStatus: 'PENDING',
        discountReason: 'Dealer ordering 5 units in single shipment; requested ₹2,000 seasonal dealer concession',
        finalTotal: 44020,
        paymentTerms: 'Payment on Delivery',
        items: {
          create: [
            {
              productId: prod1.id,
              sku: prod1.sku,
              productName: prod1.name,
              quantity: 5,
              unitPrice: 7800, // Dealer price snapshot
              taxRate: 18.0,
              taxAmount: 7020,
              totalPrice: 46020,
            },
          ],
        },
        discountApprovals: {
          create: {
            requestedDiscount: 2000,
            proposedTotal: 44020,
            reason: 'Dealer bulk order concession',
            status: 'PENDING',
          },
        },
      },
    });
  }

  console.log('✅ Grand Aqua database seeded successfully!');
  console.log('Credentials:');
  console.log('Super Admin: admin@grandaqua.com / GrandAqua@Admin2026');
  console.log('Salesman: amit.sharma@grandaqua.com / Salesman@2026');
  console.log('Buyer Phone Login: +919811122233 (OTP: 123456)');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

