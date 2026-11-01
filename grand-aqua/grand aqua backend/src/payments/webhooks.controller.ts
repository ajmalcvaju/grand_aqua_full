import {
  Controller,
  Post,
  Body,
  Headers,
  HttpCode,
  HttpStatus,
  BadRequestException,
  Logger,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { PaymentsService } from './payments.service';
import { RazorpayService } from './gateways/razorpay.service';
import { CashfreeService } from './gateways/cashfree.service';

@ApiTags('Payment Gateway Webhooks')
@Controller('payments')
export class WebhooksController {
  private readonly logger = new Logger(WebhooksController.name);

  constructor(
    private paymentsService: PaymentsService,
    private razorpayService: RazorpayService,
    private cashfreeService: CashfreeService,
  ) {}

  /**
   * Razorpay Webhook Handler
   * Listens for payment.captured, order.paid
   */
  @Post('webhooks/razorpay')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Webhook listener for Razorpay payment captures' })
  async handleRazorpayWebhook(
    @Body() payload: any,
    @Headers('x-razorpay-signature') signature: string,
  ) {
    this.logger.log(`Received Razorpay webhook event: ${payload?.event}`);

    // 1. Verify signature
    const isValid = this.razorpayService.verifyWebhookSignature(payload, signature);
    if (!isValid) {
      this.logger.error('Invalid Razorpay webhook signature');
      throw new BadRequestException('Invalid signature');
    }

    // 2. Process payment.captured or order.paid
    const event = payload?.event;
    if (event === 'payment.captured' || event === 'order.paid') {
      const paymentEntity = payload?.payload?.payment?.entity || {};
      const orderEntity = payload?.payload?.order?.entity || {};

      const gatewayPaymentId = paymentEntity.id;
      const gatewayOrderId = paymentEntity.order_id || orderEntity.id;
      const amountInInr = (paymentEntity.amount || 0) / 100; // Razorpay amounts are in paise

      const notes = paymentEntity.notes || orderEntity.notes || {};
      const orderId = notes.orderId;
      const orderNumber = notes.orderNumber;
      const buyerProfileId = notes.buyerProfileId;

      this.logger.log(
        `Processing Razorpay payment ${gatewayPaymentId} of ₹${amountInInr} for Order ${orderNumber || orderId || 'N/A'}`,
      );

      const result = await this.paymentsService.handleGatewayPayment({
        provider: 'RAZORPAY',
        gatewayPaymentId,
        gatewayOrderId,
        amountInInr,
        orderId,
        orderNumber,
        buyerProfileId,
        rawPayload: payload,
        notes: `Razorpay payment ${gatewayPaymentId} (Method: ${paymentEntity.method || 'online'})`,
      });

      return { status: 'ok', event, result };
    }

    return { status: 'ignored', event };
  }

  /**
   * Cashfree Webhook Handler
   * Listens for PAYMENT_SUCCESS_WEBHOOK
   */
  @Post('webhooks/cashfree')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Webhook listener for Cashfree payment success' })
  async handleCashfreeWebhook(
    @Body() payload: any,
    @Headers('x-webhook-signature') signature: string,
    @Headers('x-webhook-timestamp') timestamp: string,
  ) {
    const eventType = payload?.type || payload?.event;
    this.logger.log(`Received Cashfree webhook event: ${eventType}`);

    // 1. Verify signature
    const isValid = this.cashfreeService.verifyWebhookSignature(payload, signature, timestamp);
    if (!isValid) {
      this.logger.error('Invalid Cashfree webhook signature');
      throw new BadRequestException('Invalid signature');
    }

    // 2. Process Success Event
    if (
      eventType === 'PAYMENT_SUCCESS_WEBHOOK' ||
      payload?.data?.payment?.payment_status === 'SUCCESS'
    ) {
      const data = payload?.data || {};
      const paymentData = data.payment || {};
      const orderData = data.order || {};

      const gatewayPaymentId = String(paymentData.cf_payment_id || `cf_pay_${Date.now()}`);
      const gatewayOrderId = String(orderData.order_id || '');
      const amountInInr = Number(paymentData.payment_amount || orderData.order_amount || 0);

      const tags = orderData.order_tags || {};
      const orderId = tags.orderId;
      const orderNumber = tags.orderNumber;
      const buyerProfileId = tags.buyerProfileId;

      this.logger.log(
        `Processing Cashfree payment ${gatewayPaymentId} of ₹${amountInInr} for Order ${orderNumber || orderId || 'N/A'}`,
      );

      const result = await this.paymentsService.handleGatewayPayment({
        provider: 'CASHFREE',
        gatewayPaymentId,
        gatewayOrderId,
        amountInInr,
        orderId,
        orderNumber,
        buyerProfileId,
        rawPayload: payload,
        notes: `Cashfree collection ${gatewayPaymentId} (Method: ${paymentData.payment_group || 'online'})`,
      });

      return { status: 'ok', eventType, result };
    }

    return { status: 'ignored', eventType };
  }

  /**
   * Simulate a Gateway Webhook (For Super Admin testing & verification)
   */
  @Post('webhooks/simulate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Simulate a gateway webhook callback for test verification' })
  async simulateGatewayWebhook(
    @Body()
    body: {
      provider: 'RAZORPAY' | 'CASHFREE';
      amount: number;
      orderId?: string;
      orderNumber?: string;
      buyerProfileId?: string;
    },
  ) {
    const provider = body.provider || 'RAZORPAY';
    const gatewayPaymentId =
      provider === 'RAZORPAY'
        ? `pay_sim_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 6)}`
        : `cf_sim_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 6)}`;

    const result = await this.paymentsService.handleGatewayPayment({
      provider,
      gatewayPaymentId,
      gatewayOrderId: `ord_sim_${Date.now()}`,
      amountInInr: Number(body.amount),
      orderId: body.orderId,
      orderNumber: body.orderNumber,
      buyerProfileId: body.buyerProfileId,
      rawPayload: { simulated: true, ...body },
      notes: `Simulated ${provider} test payment collection`,
    });

    return {
      success: true,
      simulated: true,
      provider,
      gatewayPaymentId,
      result,
    };
  }

  /**
   * Create Gateway Checkout Session for Razorpay or Cashfree
   */
  @Post('checkout-session')
  @ApiOperation({ summary: 'Create Razorpay or Cashfree checkout session for order payment' })
  async createCheckoutSession(
    @Body()
    body: {
      gateway: 'RAZORPAY' | 'CASHFREE';
      orderId: string;
      amount?: number;
      notes?: Record<string, string>;
    },
  ) {
    const order = await (this.paymentsService as any).prisma.order.findUnique({
      where: { id: body.orderId },
      include: { buyer: { include: { user: true } } },
    });

    if (!order) {
      throw new BadRequestException('Order not found');
    }

    const payableAmount = Number(body.amount || order.outstandingAmount || order.finalAmount);
    const metadata = {
      orderId: order.id,
      orderNumber: order.orderNumber,
      buyerProfileId: order.buyerProfileId,
      ...(body.notes || {}),
    };

    if (body.gateway === 'CASHFREE') {
      return this.cashfreeService.createOrder({
        orderId: order.id,
        amountInInr: payableAmount,
        customerDetails: {
          id: order.buyer.userId || order.buyerProfileId,
          phone: order.buyer.user?.phone || '9999999999',
          name: order.buyer.user?.fullName || order.buyer.businessName,
          email: order.buyer.user?.email || undefined,
        },
        notes: metadata,
      });
    }

    // Default to Razorpay
    return this.razorpayService.createOrder({
      amountInInr: payableAmount,
      receipt: `RCP_${order.orderNumber}`,
      notes: metadata,
    });
  }
}
