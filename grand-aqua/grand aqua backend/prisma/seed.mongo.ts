import { PrismaClient, BuyerType, LoyaltyTierLevel, UserRoleType, AccountStatus } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding MongoDB database (grand_aqua_db) with initial data...');

  const passwordHash = await bcrypt.hash('GrandAqua@Admin2026', 10);
  const salesmanPasswordHash = await bcrypt.hash('Salesman@2026', 10);

  // 1. Super Admin User
  const existingAdmin = await prisma.user.findFirst({ where: { email: 'admin@grandaqua.com' } });
  if (!existingAdmin) {
    await prisma.user.create({
      data: {
        email: 'admin@grandaqua.com',
        phone: '+919999999999',
        fullName: 'Super Administrator',
        passwordHash,
        role: UserRoleType.SUPER_ADMIN,
        status: AccountStatus.ACTIVE,
      },
    });
    console.log('✅ Super Admin created in MongoDB: admin@grandaqua.com');
  } else {
    console.log('ℹ️ Super Admin already exists in MongoDB');
  }

  // 2. Salesman User & Profile
  const existingSalesman = await prisma.user.findFirst({ where: { email: 'amit.sharma@grandaqua.com' } });
  let salesmanProfileId: string;
  if (!existingSalesman) {
    const salesmanUser = await prisma.user.create({
      data: {
        email: 'amit.sharma@grandaqua.com',
        phone: '+919876543210',
        fullName: 'Amit Sharma',
        passwordHash: salesmanPasswordHash,
        role: UserRoleType.SALESMAN,
        status: AccountStatus.ACTIVE,
      },
    });
    const sProfile = await prisma.salesmanProfile.create({
      data: {
        userId: salesmanUser.id,
        employeeCode: 'SLS-DEL-001',
        assignedTerritory: 'Delhi NCR & North Zone',
        monthlySalesTarget: 500000,
        quarterlySalesTarget: 1500000,
      },
    });
    salesmanProfileId = sProfile.id;
    console.log('✅ Salesman created in MongoDB: amit.sharma@grandaqua.com');
  } else {
    const sp = await prisma.salesmanProfile.findFirst({ where: { userId: existingSalesman.id } });
    salesmanProfileId = sp!.id;
  }

  // 3. Categories
  const catNames = [
    { name: 'Domestic Water Purifiers', slug: 'domestic-purifiers' },
    { name: 'Commercial RO Systems', slug: 'commercial-ro' },
    { name: 'Industrial Softeners', slug: 'industrial-softeners' },
    { name: 'Spare Parts & Filters', slug: 'spare-parts' },
  ];
  const catMap = new Map<string, string>();
  for (const cat of catNames) {
    let c = await prisma.productCategory.findFirst({ where: { slug: cat.slug } });
    if (!c) {
      c = await prisma.productCategory.create({
        data: { name: cat.name, slug: cat.slug, description: `${cat.name} range` },
      });
    }
    catMap.set(cat.slug, c.id);
  }

  // 4. Products with 4-Tier Pricing
  const products = [
    {
      name: 'Grand Aqua Pro RO+UV+UF+TDS Water Purifier',
      sku: 'GA-DOM-001',
      catSlug: 'domestic-purifiers',
      distPrice: 10500,
      whoPrice: 12000,
      deaPrice: 13800,
      cusPrice: 16499,
    },
    {
      name: 'Grand Aqua Commercial RO Plant 250 LPH',
      sku: 'GA-COM-250',
      catSlug: 'commercial-ro',
      distPrice: 68000,
      whoPrice: 75000,
      deaPrice: 85000,
      cusPrice: 99000,
    },
    {
      name: 'Grand Aqua 100 GPD RO Membrane (High TDS)',
      sku: 'GA-SPR-001',
      catSlug: 'spare-parts',
      distPrice: 950,
      whoPrice: 1100,
      deaPrice: 1350,
      cusPrice: 1899,
    },
  ];

  for (const p of products) {
    const existing = await prisma.product.findFirst({ where: { sku: p.sku } });
    if (!existing) {
      const prod = await prisma.product.create({
        data: {
          name: p.name,
          sku: p.sku,
          shortDescription: `${p.name} - official Grand Aqua certified water purification technology.`,
          categoryId: catMap.get(p.catSlug)!,
          status: 'ACTIVE',
          isFeatured: true,
        },
      });

      await prisma.productPrice.create({
        data: {
          productId: prod.id,
          distributorPrice: p.distPrice,
          wholesalerPrice: p.whoPrice,
          dealerPrice: p.deaPrice,
          customerPrice: p.cusPrice,
          minOrderQuantity: 1,
        },
      });

      await prisma.inventoryItem.create({
        data: {
          productId: prod.id,
          currentStock: 150,
          reorderLevel: 20,
        },
      });
      console.log(`✅ Product created in MongoDB: ${p.sku}`);
    }
  }

  // 5. Buyers across categories
  const sampleBuyers = [
    {
      name: 'Rajesh Verma',
      business: 'Apex Water Systems Pvt Ltd',
      phone: '+919811122233',
      email: 'rajesh@apexwater.com',
      buyerType: BuyerType.DISTRIBUTOR,
      loyalty: LoyaltyTierLevel.DIAMOND,
      creditLimit: 2000000,
      buyerId: 'BUY-DIS-001',
    },
    {
      name: 'Suresh Patel',
      business: 'National RO Spares & Machinery',
      phone: '+919822233344',
      email: 'suresh@nationalro.com',
      buyerType: BuyerType.WHOLESALER,
      loyalty: LoyaltyTierLevel.PLATINUM,
      creditLimit: 1000000,
      buyerId: 'BUY-WHO-002',
    },
    {
      name: 'Vikram Joshi',
      business: 'Aqua Pure Care & Retail',
      phone: '+919833344455',
      email: 'vikram@aquapurecare.in',
      buyerType: BuyerType.DEALER,
      loyalty: LoyaltyTierLevel.GOLD,
      creditLimit: 300000,
      buyerId: 'BUY-DEA-003',
    },
    {
      name: 'Anita Singh',
      business: 'Household Customer',
      phone: '+919844455566',
      email: 'anita.singh@gmail.com',
      buyerType: BuyerType.CUSTOMER,
      loyalty: LoyaltyTierLevel.NONE,
      creditLimit: 0,
      buyerId: 'BUY-CUS-004',
    },
  ];

  for (const b of sampleBuyers) {
    const existing = await prisma.user.findFirst({ where: { phone: b.phone } });
    if (!existing) {
      const u = await prisma.user.create({
        data: {
          email: b.email,
          phone: b.phone,
          fullName: b.name,
          role: UserRoleType.BUYER,
          status: AccountStatus.ACTIVE,
        },
      });

      const bp = await prisma.buyerProfile.create({
        data: {
          buyerId: b.buyerId,
          userId: u.id,
          businessName: b.business,
          buyerType: b.buyerType,
          loyaltyTier: b.loyalty,
          assignedSalesmanId: b.buyerType !== BuyerType.CUSTOMER ? salesmanProfileId : null,
          accountStatus: AccountStatus.ACTIVE,
        },
      });

      if (b.creditLimit > 0) {
        await prisma.creditAccount.create({
          data: {
            buyerProfileId: bp.id,
            creditLimit: b.creditLimit,
            utilizedCredit: b.creditLimit * 0.15,
            availableCredit: b.creditLimit * 0.85,
            paymentTermsDays: b.buyerType === BuyerType.DISTRIBUTOR ? 30 : 15,
          },
        });
      }
      console.log(`✅ Buyer created in MongoDB: ${b.business} (${b.buyerType})`);
    }
  }

  console.log('\n🎉 MongoDB database (grand_aqua_db) successfully initialized and seeded!');
}

main()
  .catch((e) => {
    console.error('Seeding error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
