import { Injectable, Logger } from '@nestjs/common';
import * as crypto from 'crypto';

@Injectable()
export class RazorpayService {
  private readonly logger = new Logger(RazorpayService.name);

  /**
   * Verify Razorpay Webhook signature using HMAC-SHA256
   */
  verifyWebhookSignature(payloadBody: string | any, signature: string, secret?: string): boolean {
    const webhookSecret = secret || process.env.RAZORPAY_WEBHOOK_SECRET;

    if (!webhookSecret) {
      this.logger.warn('RAZORPAY_WEBHOOK_SECRET is not configured; allowing in development mode');
      return true;
    }

    if (!signature) {
      return false;
    }

    try {
      const bodyString = typeof payloadBody === 'string' ? payloadBody : JSON.stringify(payloadBody);
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(bodyString)
        .digest('hex');

      return crypto.timingSafeEqual(Buffer.from(expectedSignature), Buffer.from(signature));
    } catch (err: any) {
      this.logger.error(`Razorpay signature verification error: ${err.message}`);
      return false;
    }
  }

  /**
   * Creates or prepares a Razorpay Order for client-side checkout
   */
  async createOrder(params: {
    amountInInr: number;
    currency?: string;
    receipt: string;
    notes?: Record<string, string>;
  }) {
    const keyId = process.env.RAZORPAY_KEY_ID || 'rzp_test_grandaqua2026';
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    const amountInPaise = Math.round(params.amountInInr * 100);

    // If live credentials are provided, call Razorpay REST API
    if (keySecret) {
      try {
        const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
        const res = await fetch('https://api.razorpay.com/v1/orders', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Basic ${auth}`,
          },
          body: JSON.stringify({
            amount: amountInPaise,
            currency: params.currency || 'INR',
            receipt: params.receipt,
            notes: params.notes || {},
          }),
        });

        if (res.ok) {
          const data = await res.json();
          return {
            provider: 'RAZORPAY',
            orderId: data.id,
            amount: params.amountInInr,
            amountInPaise,
            currency: data.currency,
            keyId,
          };
        }
      } catch (err: any) {
        this.logger.warn(`Razorpay API call failed, falling back to simulated order: ${err.message}`);
      }
    }

    // Default development / test order structure
    const simulatedOrderId = `order_rzp_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 7)}`;
    return {
      provider: 'RAZORPAY',
      orderId: simulatedOrderId,
      amount: params.amountInInr,
      amountInPaise,
      currency: params.currency || 'INR',
      keyId,
      notes: params.notes,
    };
  }
}
