import { Injectable, Logger } from '@nestjs/common';
import * as crypto from 'crypto';

@Injectable()
export class CashfreeService {
  private readonly logger = new Logger(CashfreeService.name);

  /**
   * Verify Cashfree Webhook signature using HMAC-SHA256 (timestamp + rawBody)
   */
  verifyWebhookSignature(
    payloadBody: string | any,
    signature: string,
    timestamp: string,
    secret?: string,
  ): boolean {
    const webhookSecret = secret || process.env.CASHFREE_CLIENT_SECRET;

    if (!webhookSecret) {
      this.logger.warn('CASHFREE_CLIENT_SECRET is not configured; allowing in development mode');
      return true;
    }

    if (!signature || !timestamp) {
      return false;
    }

    try {
      const bodyString = typeof payloadBody === 'string' ? payloadBody : JSON.stringify(payloadBody);
      const dataToSign = timestamp + bodyString;
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(dataToSign)
        .digest('base64');

      return expectedSignature === signature;
    } catch (err: any) {
      this.logger.error(`Cashfree signature verification error: ${err.message}`);
      return false;
    }
  }

  /**
   * Creates or prepares a Cashfree PG Order for client-side checkout
   */
  async createOrder(params: {
    orderId: string;
    amountInInr: number;
    customerDetails: {
      id: string;
      phone: string;
      name?: string;
      email?: string;
    };
    notes?: Record<string, string>;
  }) {
    const appId = process.env.CASHFREE_APP_ID || 'cf_test_grandaqua2026';
    const clientSecret = process.env.CASHFREE_CLIENT_SECRET;
    const isProd = process.env.NODE_ENV === 'production';
    const baseUrl = isProd ? 'https://api.cashfree.com/pg' : 'https://sandbox.cashfree.com/pg';

    const cfOrderId = `CF_${params.orderId.replace(/[^a-zA-Z0-9_-]/g, '')}_${Date.now().toString(36)}`;

    if (clientSecret) {
      try {
        const res = await fetch(`${baseUrl}/orders`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-client-id': appId,
            'x-client-secret': clientSecret,
            'x-api-version': '2023-08-01',
          },
          body: JSON.stringify({
            order_id: cfOrderId,
            order_amount: params.amountInInr,
            order_currency: 'INR',
            customer_details: {
              customer_id: params.customerDetails.id,
              customer_phone: params.customerDetails.phone.replace(/[^0-9]/g, '').slice(-10),
              customer_name: params.customerDetails.name || 'Grand Aqua Customer',
              customer_email: params.customerDetails.email || 'customer@grandaqua.com',
            },
            order_meta: {
              return_url: `${process.env.APP_BASE_URL || 'http://localhost:3000'}/dashboard/orders?payment_status={order_status}`,
            },
            order_tags: params.notes,
          }),
        });

        if (res.ok) {
          const data = await res.json();
          return {
            provider: 'CASHFREE',
            orderId: data.order_id,
            paymentSessionId: data.payment_session_id,
            amount: params.amountInInr,
            currency: 'INR',
            appId,
          };
        }
      } catch (err: any) {
        this.logger.warn(`Cashfree API call failed, falling back to simulated order: ${err.message}`);
      }
    }

    const simulatedSessionId = `session_cf_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 8)}`;
    return {
      provider: 'CASHFREE',
      orderId: cfOrderId,
      paymentSessionId: simulatedSessionId,
      amount: params.amountInInr,
      currency: 'INR',
      appId,
      notes: params.notes,
    };
  }
}
