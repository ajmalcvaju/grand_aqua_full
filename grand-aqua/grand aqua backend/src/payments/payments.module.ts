import { Module } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { WebhooksController } from './webhooks.controller';
import { RazorpayService } from './gateways/razorpay.service';
import { CashfreeService } from './gateways/cashfree.service';

@Module({
  providers: [PaymentsService, RazorpayService, CashfreeService],
  controllers: [PaymentsController, WebhooksController],
  exports: [PaymentsService, RazorpayService, CashfreeService],
})
export class PaymentsModule {}
