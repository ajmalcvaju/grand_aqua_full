import { Module } from '@nestjs/common';
import { SalesmenService } from './salesmen.service';
import { SalesmenController } from './salesmen.controller';

@Module({
  providers: [SalesmenService],
  controllers: [SalesmenController],
  exports: [SalesmenService],
})
export class SalesmenModule {}
