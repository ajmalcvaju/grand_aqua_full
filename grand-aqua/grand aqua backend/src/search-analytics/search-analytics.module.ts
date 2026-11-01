import { Module } from '@nestjs/common';
import { SearchAnalyticsController } from './search-analytics.controller';
import { SearchAnalyticsService } from './search-analytics.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [SearchAnalyticsController],
  providers: [SearchAnalyticsService],
  exports: [SearchAnalyticsService],
})
export class SearchAnalyticsModule {}
