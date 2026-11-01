# Grand Aqua REST API Reference (`/api/v1`)

The backend exposes a unified REST API documented interactively with Swagger at `http://localhost:4000/api/v1/docs`.

---

## 1. Authentication Endpoints (`/api/v1/auth`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `POST` | `/auth/admin/login` | Administrative credentials login (identifier [username / email / phone] & password) | Public |
| `POST` | `/auth/buyer/request-otp` | Sends 6-digit SMS OTP to buyer mobile | Public |
| `POST` | `/auth/buyer/verify-otp` | Verifies OTP; returns JWT and auto-registers new buyers | Public |
| `GET` | `/auth/me` | Fetches current user profile and role details | Authenticated |

---

## 2. Product Categories (`/api/v1/products/categories`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `GET` | `/products/categories` | List all categories with product counts (`_count.products`) | All |
| `GET` | `/products/categories/:id` | Get single category details | All |
| `POST` | `/products/categories` | Create category (name, auto-derived slug, description, image, active) | Super Admin |
| `PUT` | `/products/categories/:id` | Update category details and visibility | Super Admin |
| `DELETE`| `/products/categories/:id` | Delete category (safe delete, prevents deletion if products assigned) | Super Admin |

---

## 3. Product Catalog & 4-Tier Pricing (`/api/v1/products`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `GET` | `/products` | Catalog search and filter (`search`, `categoryId`, `buyerType`, `isFeatured`) | All |
| `GET` | `/products/:id` | Returns product details, full 4-tier prices, media, stock, and quantity pricing | Authenticated |
| `POST` | `/products` | Create product with stock, quantity slabs, media, and 4-tier pricing | Super Admin |
| `PUT` | `/products/:id` | Update product specs, inventory stock, quantity pricing toggle/slabs, and tier prices | Super Admin |
| `DELETE`| `/products/:id` | Delete or archive product | Super Admin |

---

## 4. File & Media Upload (`/api/v1/upload`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `POST` | `/upload` | Multipart file upload for Product Images, Videos, 3D Models (`.glb`/`.gltf`), Owner and Shop photos | Authenticated |

---

## 5. Buyer Management (`/api/v1/buyers`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `GET` | `/buyers` | Paginated search, filter by category (`CUSTOMER`, `DEALER`, `WHOLESALER`, `DISTRIBUTOR`) | Admin / Salesman |
| `GET` | `/buyers/:id` | 360-degree buyer profile: purchase history with items, payment ledger, dues | Admin / Salesman |
| `POST` | `/buyers` | Register buyer with optional username, owner & shop photos, credit limit, credit days, and tier | Super Admin |
| `PUT` | `/buyers/:id` | Update buyer profile, username, photos, assigned salesman, and trade category | Super Admin |
| `DELETE`| `/buyers/:id` | Delete buyer profile and clean up associated records | Super Admin |
| `POST` | `/buyers/:id/change-type` | Change buyer trade category | Super Admin |
| `POST` | `/buyers/:id/assign-salesman` | Assign or reassign regional sales representative | Super Admin |
| `POST` | `/buyers/:id/status` | Activate, suspend, or block buyer account | Super Admin |

---

## 6. Credit Management (`/api/v1/credit`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `GET` | `/credit/accounts` | Live credit facilities: approved limit, utilized credit, available balance, cycle days | Super Admin |
| `GET` | `/credit/buyer/:buyerProfileId` | Single buyer credit ledger, available balance, and transaction history | Super Admin |
| `PUT` | `/credit/buyer/:buyerProfileId/limit` | Adjust approved credit limit and custom payment cycle days with audit reason | Super Admin |
| `POST` | `/credit/apply` | Buyer or salesman submits credit enhancement application | Authenticated |

---

## 7. Quotations Engine (`/api/v1/quotations`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `GET` | `/quotations` | List quotations filtered by status, buyer, salesman | Admin / Salesman |
| `POST` | `/quotations` | Create quotation with item rows, tier prices, extra discount request | Salesman / Admin |
| `PUT` | `/quotations/:id` | Update quotation details and line items | Super Admin |
| `POST` | `/quotations/:id/approve` | Approve discount exceeding threshold | Super Admin |
| `POST` | `/quotations/:id/reject` | Reject quote with reason note | Super Admin |
| `POST` | `/quotations/:id/convert-to-order` | Convert accepted quote into a confirmed order | Admin / Salesman |
| `GET` | `/quotations/:id/pdf` | Generate and stream branded PDF quotation | Authenticated |

---

## 8. Orders & Fulfillment (`/api/v1/orders`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `GET` | `/orders` | Filter orders by status (`PENDING`, `CONFIRMED`, `PROCESSING`, `SHIPPED`, `DELIVERED`, `CANCELLED`). Auto-scoped for Salesman & Buyer. | Authenticated |
| `GET` | `/orders/my-orders` | Fetch current buyer's order history with items and tracking | Buyer |
| `POST` | `/orders` | Submit purchase order with credit limit checks | Buyer / Salesman |
| `PUT` | `/orders/:id/status` | Update fulfillment status with tracking number and dispatch reason | Super Admin |
| `PUT` | `/orders/:id/dispatch` | Dispatch order with carrier name, tracking docket no, delivery date, auto-invoice generation & automated WhatsApp/SMS notifications with tracking and PDF invoice links | Super Admin |
| `POST` | `/orders/:id/resend-dispatch-notification` | Resend automated WhatsApp & SMS dispatch alert with live tracking and PDF invoice links | Super Admin / Salesman |
| `GET` | `/orders/:id/dispatch-logs` | Fetch dispatch notification logs, delivery statuses, tracking URLs and invoice links | Authenticated |
| `GET` | `/orders/:id/invoice-pdf` | Stream official GST Tax Invoice as PDF (Original for Recipient, logo, HSN, bank details, authorized signatory) | Public / Direct Link |
| `GET` | `/orders/:id/invoice/pdf` | Alias endpoint to stream official GST Tax Invoice as PDF | Public / Direct Link |

---

## 9. Payments & Receivables (`/api/v1/payments`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `GET` | `/payments` | List payments with buyer details, order references, methods | Super Admin |
| `GET` | `/payments/receivables-summary` | Aggregated receivables, outstanding balances, and total collections | Super Admin |
| `POST` | `/payments` | Record settlement (Cash, UPI, Bank Transfer, Cheque) and reconcile dues | Super Admin |
| `POST` | `/payments/checkout-session` | Create Razorpay order or Cashfree session for customer checkout | Authenticated |
| `POST` | `/payments/webhooks/razorpay` | Inbound webhook for Razorpay captures (`payment.captured`, `order.paid`) | Public (HMAC Verified) |
| `POST` | `/payments/webhooks/cashfree` | Inbound webhook for Cashfree collections (`PAYMENT_SUCCESS_WEBHOOK`) | Public (HMAC Verified) |
| `POST` | `/payments/webhooks/simulate` | Test webhook simulation for automated end-to-end payment reconciliation | Authenticated / Super Admin |

---

## 10. Salesmen & Incentive Engine (`/api/v1/salesmen`)

| Method | Endpoint | Description | Access |
|---|---|---|---|
| `GET` | `/salesmen` | Salesmen list with monthly/quarterly targets, assigned shops, performance % | Super Admin |
| `POST` | `/salesmen` | Register new sales representative with optional username | Super Admin |
| `PUT` | `/salesmen/:id` | Update salesman profile, username, assigned territory, and sales targets | Super Admin |
| `DELETE`| `/salesmen/:id` | Remove salesman profile | Super Admin |
| `POST` | `/salesmen/:id/block` | Block or unblock salesman access | Super Admin |
