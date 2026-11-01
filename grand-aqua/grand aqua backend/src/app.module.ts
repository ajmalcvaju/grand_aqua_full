import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { ProductsModule } from './products/products.module';
import { BuyersModule } from './buyers/buyers.module';
import { QuotationsModule } from './quotations/quotations.module';
import { OrdersModule } from './orders/orders.module';
import { PaymentsModule } from './payments/payments.module';
import { SalesmenModule } from './salesmen/salesmen.module';
import { OffersModule } from './offers/offers.module';
import { CreditModule } from './credit/credit.module';
import { ReportsModule } from './reports/reports.module';
import { NotificationsModule } from './notifications/notifications.module';
import { ReviewsModule } from './reviews/reviews.module';
import { SearchAnalyticsModule } from './search-analytics/search-analytics.module';
import { BannersModule } from './banners/banners.module';
import { SettingsModule } from './settings/settings.module';
import { PdfModule } from './pdf/pdf.module';
import { UploadModule } from './upload/upload.module';
import { LoyaltyModule } from './loyalty/loyalty.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    UploadModule,
    LoyaltyModule,
    ProductsModule,
    BuyersModule,
    QuotationsModule,
    OrdersModule,
    PaymentsModule,
    SalesmenModule,
    OffersModule,
    CreditModule,
    ReportsModule,
    NotificationsModule,
    ReviewsModule,
    SearchAnalyticsModule,
    BannersModule,
    SettingsModule,
    PdfModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
