# Grand Aqua — System Architecture & Data Flow

## 1. Executive Summary

Grand Aqua is a comprehensive business management, B2B sales automation, and B2C e-commerce ecosystem designed for water purification and water treatment systems.

The platform architecture follows a **single, secure multi-tenant backend** model serving **five independent frontend applications**:
1. **Super Admin Web App** (Next.js 14 App Router, Tailwind CSS, TanStack Query, Recharts)
2. **Super Admin Android App** (Flutter 3.x, Material 3, Riverpod 3, Dio, GoRouter)
3. **Salesman Web App** (Next.js 14 App Router, Tailwind CSS, Quotation Builder, Payout Ledger)
4. **Salesman Android App** (Flutter 3.x, Field Sales Visit Logging, Quotations, Incentives)
5. **Buyer Android App** (Flutter 3.x, Mobile OTP login, Tiered Catalog, Trade Credit Checkout)

---

## 2. Architecture Diagram

```text
┌───────────────────────────────┐     ┌───────────────────────────────┐
│  Grand Aqua Super Admin Web   │     │ Grand Aqua Super Admin Android│
│       (Next.js 14 Web)        │     │       (Flutter Mobile)        │
└───────────────┬───────────────┘     └───────────────┬───────────────┘
                │                                     │
                │        REST API /api/v1 (JWT)       │
                ├─────────────────────────────────────┤
                │                                     │
┌───────────────┴───────────────┐     ┌───────────────┴───────────────┐
│   Grand Aqua Salesman Web     │     │  Grand Aqua Salesman Android  │
│       (Next.js 14 Web)        │     │       (Flutter Mobile)        │
└───────────────┬───────────────┘     └───────────────┬───────────────┘
                │                                     │
                │        REST API /api/v1 (JWT)       │
                ├─────────────────────────────────────┤
                │                                     │
                │                     ┌───────────────┴───────────────┐
                │                     │   Grand Aqua Buyer Android    │
                │                     │    (Flutter Mobile + OTP)     │
                │                     └───────────────┬───────────────┘
                │                                     │
                └──────────────────┬──────────────────┘
                                   │
               ┌───────────────────▼───────────────────┐
               │         Grand Aqua Backend            │
               │   (NestJS + TypeScript + REST v1)     │
               └───────────────────┬───────────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         │                         │                         │
┌────────▼────────┐       ┌────────▼────────┐       ┌────────▼────────┐
│   PostgreSQL    │       │ Redis & Queues  │       │ Object Storage  │
│  (Prisma ORM)   │       │ (Notifications) │       │   (S3 / Media)  │
└─────────────────┘       └─────────────────┘       └─────────────────┘
```

---

## 3. Four-Tier Pricing Model & Buyer Lifecycle

The business operates with strict role and tier-based pricing for all catalog items:

```text
      ┌────────────────────────────────────────────────────────┐
      │                   Product Master                       │
      │  ┌───────────────┬───────────────┬──────────────┬────┐ │
      │  │  Distributor  │   Wholesaler  │    Dealer    │Cust│ │
      │  │     Price     │     Price     │    Price     │Price │
      │  └───────────────┴───────────────┴──────────────┴────┘ │
      └───────────────────────────┬────────────────────────────┘
                                  │
    ┌─────────────────────────────┼────────────────────────────┐
    ▼                             ▼                            ▼
Distributor Price           Wholesaler Price              Dealer Price
• Minimum order slabs       • Regional volume pricing     • Retail shop replenishment
• 30-day Trade Credit       • 15-day Trade Credit         • 7-day Trade Credit / UPI
```

### Automatic Classification Rules:
- **Default Registration:** Every new self-registration from the Buyer Android app is automatically initialized as **`CUSTOMER`** with loyalty tier **`NONE`**.
- **Admin Promotion Workflow:** Only authorized Super Admins can upgrade a buyer to `DEALER`, `WHOLESALER`, or `DISTRIBUTOR`.
- **Price Freezing (Snapshot):** When a quotation is generated or an order is submitted, the price is irrevocably snapshotted. Subsequent product price changes or tier promotions do not affect existing quotations or placed orders.

---

## 4. Loyalty Program & Benefits

Loyalty tiers operate independently of buyer business classifications:

| Loyalty Tier | Eligibility Criteria | Core Benefits |
|---|---|---|
| **NONE** | All new signups | Standard base pricing for category |
| **GOLD** | > ₹1,00,000 quarterly spend | 2% additional cashback, standard credit period |
| **PLATINUM**| > ₹5,00,000 quarterly spend | 5% additional cashback, +7 days credit buffer |
| **DIAMOND** | > ₹15,00,000 quarterly spend| 8% additional cashback, priority fulfillment, zero credit interest |

---

## 5. Security & Authentication Model

1. **Super Admin & Salesmen:**
   - Email/Username + Argon2/Bcrypt Password.
   - Throttling & Account lockout (5 failed attempts locks account for 15 minutes).
   - Stateless signed JWT Bearer tokens with configurable expiration.

2. **Buyers (Mobile OTP Flow):**
   - 10-digit mobile number authentication.
   - 6-digit OTP delivery via SMS gateway (with mock sandbox fallback in dev).
   - Automatic account provisioning on first verification.

3. **Trade Credit Risk Engine:**
   - Each approved dealer/wholesaler/distributor has an assigned credit limit.
   - Order placement checks: `(Current Outstanding + New Order Total) <= Credit Limit`.
   - Payment allocations automatically replenish available credit balance in an ACID database transaction.

---

## 6. Commercial Proposal & Document Generation Engine

### Quotation Pipeline & Lifecycle
```text
┌──────────────────────┐     ┌────────────────────────┐     ┌──────────────────────┐
│  Salesman / Admin    │────►│  Super Admin Approval  │────►│    Buyer Review &    │
│  Creates Quotation   │     │ (for special discount) │     │  One-Click Acceptance│
└──────────────────────┘     └────────────────────────┘     └──────────┬───────────┘
                                                                       │
                                                            ┌──────────▼───────────┐
                                                            │ Converted to Order / │
                                                            │ Download Official PDF│
                                                            └──────────────────────┘
```

1. **Itemized Format**: Standardized across all 5 applications with columns `#`, `Image`, `Product`, `Qty`, `Price`, and `Total`.
2. **Visual Fallback**: Seamless fallback to circular camera glyph with diagonal slash when product image is unavailable.
3. **Automated Quotation PDF Generation**: Native high-speed PDF streaming via PDFKit, including company logo, GSTIN, payment terms, buyer details, itemized breakdown, and signature blocks.
4. **Salesman Target Decoupling**: Super Admin focuses purely on order flow, product margins, and customer satisfaction without monthly/quarterly sales targets or internal incentive calculations.

---

## 7. Order Dispatch & Official GST Tax Invoice Engine

### Dispatch & Invoicing Flow
```text
┌────────────────────────┐     ┌─────────────────────────┐     ┌────────────────────────┐
│ Order Placed/Accepted  │────►│ Super Admin Dispatches  │────►│ Auto-Generated GST     │
│ (Credit Check Verified)│     │ (Carrier + Docket No.)  │     │ Tax Invoice (PDFKit)   │
└────────────────────────┘     └─────────────────────────┘     └───────────┬────────────┘
                                                                           │
                                                               ┌───────────▼────────────┐
                                                               │ Streamed directly via  │
                                                               │ Web Apps & Mobile Apps │
                                                               └────────────────────────┘
```

1. **Dispatch Flow**: Super Admin assigns a logistics partner (Delhivery, Blue Dart, V-Trans, DTDC, etc.) and tracking docket number via `PUT /orders/:id/dispatch`. The order transitions to `SHIPPED`, buyer notifications are dispatched, and an immutable `Invoice` entity is auto-provisioned.
2. **Standardized GST Tax Invoice Layout**:
   - Header with official Grand Aqua logo, GSTIN (`24AAACG1234F1Z5`), PAN, and corporate address.
   - Title: `TAX INVOICE (ORIGINAL FOR RECIPIENT)` in deep navy.
   - Two-column dispatch metadata: Invoice Number, Invoice Date, Place of Supply (`24-Gujarat`), Order No, Order Date, Carrier Name, Tracking Docket No.
   - Billed To and Shipped To buyer blocks with GSTIN and State Code.
   - Standardized Itemized Goods table: `#`, `Image` (or circle camera placeholder), `Description of Goods` (Name, SKU, HSN `84212190`), `Qty`, `Rate`, `Total`.
   - Tax Breakdown: Subtotal, CGST @ 9%, SGST @ 9%, Grand Total, and Amount Chargeable in words (`numberToWords`).
   - Payment Banking Details (RTGS/NEFT to HDFC Bank) and Authorized Signatory stamp box.
3. **Omnichannel Access**: The invoice is available instantly across Super Admin Web & Mobile, Salesman Web & Mobile, and Buyer Mobile via direct streaming (`GET /orders/:id/invoice-pdf`).

---

## 8. Automated WhatsApp & SMS Dispatch Notifications

```text
┌──────────────────────┐     ┌──────────────────────────────────────────────────┐     ┌──────────────────────┐
│  Order Dispatched /  │────►│ CommunicationsService Formats WhatsApp & SMS     │────►│ Delivered to Buyer   │
│  Fulfilled by Admin  │     │ Includes Carrier Tracking + Direct PDF Invoice   │     │ (WhatsApp & SMS)     │
└──────────────────────┘     └──────────────────────────────────────────────────┘     └──────────────────────┘
```

1. **Carrier Tracking URL Resolver**:
   - Delhivery: `https://www.delhivery.com/track/package/${trackingNumber}`
   - Blue Dart: `https://www.bluedart.com/tracking?trackNumber=${trackingNumber}`
   - DTDC: `https://www.dtdc.in/tracking/shipment-tracking.asp?strCnno=${trackingNumber}`
   - V-Trans: `https://vtransgroup.com/track-consignment/?lrno=${trackingNumber}`
2. **Direct GST Invoice PDF**: Included directly in WhatsApp and SMS notifications (`/orders/:id/invoice-pdf`).
3. **Dispatch Notification Log**: Every notification recorded in `DispatchNotificationLog` with recipient, carrier, tracking URL, invoice URL, SMS status, WhatsApp status, and full message payload.
4. **Resend Capability**: Admins and Salesmen can resend alerts on demand via `POST /orders/:id/resend-dispatch-notification`.

---

## 9. Payment Gateway Webhook Architecture (Razorpay & Cashfree)

```text
┌─────────────────────────────────┐
│ Inbound Webhook Event           │
│ (Razorpay / Cashfree Gateway)   │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│ Signature Verification (HMAC)   │
│ (x-razorpay-signature /         │
│  x-webhook-signature)           │
└────────────────┬────────────────┘
                 │ Valid Signature
                 ▼
┌─────────────────────────────────┐
│ PaymentsService Reconciler      │
│ • Allocates Payment to Order    │
│ • Settle Outstanding Balance    │
│ • Replenish Trade Credit Limit  │
│ • Dispatch In-App Notifications │
│ • Log Cryptographic Audit Trail │
└─────────────────────────────────┘
```

1. **Razorpay Webhooks (`/api/v1/payments/webhooks/razorpay`)**: Listens for `payment.captured` and `order.paid`, verifies HMAC SHA256 signature, converts paise to INR, and reconciles payments against matching orders.
2. **Cashfree Webhooks (`/api/v1/payments/webhooks/cashfree`)**: Listens for `PAYMENT_SUCCESS_WEBHOOK`, verifies HMAC SHA256 signature with timestamp, and reconciles payments against matching orders.
3. **Automated Reconciliation**: Automatically sets payment status `PAID`, marks order payment status, settles buyer dues, replenishes available credit on `CreditAccount`, and triggers notifications.
4. **Test Webhook Simulator (`/api/v1/payments/webhooks/simulate`)**: Allows Super Admins to simulate live inbound webhook callbacks for testing without real card charges.



