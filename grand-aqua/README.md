# Grand Aqua — Enterprise Business Management, Sales & E-Commerce Platform

Grand Aqua is a production-grade, multi-application business ecosystem built for manufacturers and distributors of water purifiers, commercial RO plants, water softening plants, and spare parts.

---

## 1. Project Directory Structure

```text
grand-aqua/
│
├── grand aqua super admin web app/     # Next.js 14 Web Portal for Super Admins
├── grand aqua super admin android app/ # Flutter Android App for Super Admins
├── grand aqua salesman web app/        # Next.js 14 Web Portal for Salesmen
├── grand aqua salesman android app/    # Flutter Android App for Field Sales Reps
├── grand aqua buyer android app/       # Flutter Android App for B2B/B2C Buyers
│
├── grand aqua backend/                 # NestJS + TypeScript REST API + Prisma ORM
│
├── grand aqua shared documentation/    # System Architecture, API Specs, Guides
└── README.md                           # Master Project Guide
```

---

## 2. Technology Stack

- **Backend:** Node.js, NestJS, TypeScript, MongoDB (Replica Set `rs0`) / PostgreSQL, Prisma ORM, PDFKit, Swagger/OpenAPI.
- **Web Applications:** Next.js 14 (App Router), React, TypeScript, Tailwind CSS, Lucide Icons, TanStack Query, Recharts.
- **Android Applications:** Flutter 3.x, Dart 3.4+, Material 3, Riverpod 3 (`NotifierProvider`), Dio, GoRouter, SharedPreferences.

---

## 3. Key Business Capabilities

1. **Four-Tier Independent Pricing:**
   - Distributor, Wholesaler, Dealer, and Customer pricing per item with volume tiers.
   - Price freezing on quotation creation and order checkout.

2. **Buyer Classification & Loyalty Lifecycle:**
   - Auto-registration as `CUSTOMER` with loyalty tier `NONE`.
   - Admin-controlled elevation to `DEALER`, `WHOLESALER`, or `DISTRIBUTOR` with formal consequence review.
   - Independent loyalty tiers (`GOLD`, `PLATINUM`, `DIAMOND`) with cashback vouchers and trade credit expansion.

3. **Field Sales & Commercial Quotation Engine:**
   - Quotation drafting with custom discount allowances.
   - Strict approval threshold: discounts exceeding 10% require Super Admin signoff before order conversion.
   - High-fidelity PDF generation (`/api/v1/quotations/:id/pdf`) using PDFKit.

4. **Trade Credit Risk & Order Management:**
   - Credit limit enforcement on orders (`Outstanding + Order <= Limit`).
   - Payment allocation engine tracking settlement by Cash, Cheque, Bank Transfer, or UPI.
   - Auto-calculation of 3% salesman incentives upon delivery.

5. **Order Dispatch & Official GST Tax Invoice Generator:**
   - Super Admin order fulfillment modal with Carrier Partner selection (Delhivery Express, Blue Dart, V-Trans, DTDC, etc.) and Tracking Docket Number assignment.
   - Official GST Tax Invoice (`TAX INVOICE - ORIGINAL FOR RECIPIENT`) generated with PDFKit matching reference industry standards.
   - Full GST compliance: HSN Codes (`84212190`), SGST (9%), CGST (9%), Number-to-Words amount conversion, NEFT/RTGS bank details, and Authorized Signatory box.
   - High-performance, direct-streaming download endpoints accessible without token blockers across all 5 Web & Mobile clients (`/api/v1/orders/:id/invoice-pdf`).

---

## 4. Quick Start Guide

### 1. Backend Setup
```bash
cd "grand-aqua/grand aqua backend"
npm install
npx prisma generate
npm run build
npm run start:dev
```
- API Base: `http://localhost:4000/api/v1`
- Swagger Documentation: `http://localhost:4000/api/v1/docs`

### 2. Super Admin Web Portal
```bash
cd "grand-aqua/grand aqua super admin web app"
npm install
npm run dev -- -p 3000
```
- Web URL: `http://localhost:3000`
- Login: `admin@grandaqua.com` / `GrandAqua@Admin2026`

### 3. Salesman Web Portal
```bash
cd "grand-aqua/grand aqua salesman web app"
npm install
npm run dev -- -p 3001
```
- Web URL: `http://localhost:3001`
- Login: `amit.sharma@grandaqua.com` / `Salesman@2026`

### 4. One-Click Windows Launchers
- **Start Backend & MongoDB (`rs0`):** Double-click `START_BACKEND.bat`
- **Start Both Web Applications:** Double-click `START_WEB_APPS.bat`

### 5. Installable Android APK Locations (Pre-Built)
All ready-to-install Android APKs are consolidated in the [`APKs/`](file:///d:/grand_aqua_full/grand-aqua/APKs) folder:
- **Buyer Android APK:** [`grand-aqua/APKs/Grand_Aqua_Buyer.apk`](file:///d:/grand_aqua_full/grand-aqua/APKs/Grand_Aqua_Buyer.apk)
- **Salesman Android APK:** [`grand-aqua/APKs/Grand_Aqua_Salesman.apk`](file:///d:/grand_aqua_full/grand-aqua/APKs/Grand_Aqua_Salesman.apk)
- **Super Admin Android APK:** [`grand-aqua/APKs/Grand_Aqua_SuperAdmin.apk`](file:///d:/grand_aqua_full/grand-aqua/APKs/Grand_Aqua_SuperAdmin.apk)

---

## 5. Verification & Tests

- **Backend Unit Tests:**
  ```bash
  cd "grand-aqua/grand aqua backend"
  npm test
  ```
  *(14/14 automated test suites passing for pricing, snapshot freezing, discounts, and credit limits)*

- **Production Builds:**
  - `grand aqua backend`: `npm run build` -> Clean NestJS compilation
  - `grand aqua super admin web app`: `npm run build` -> 16 static/dynamic routes optimized
  - `grand aqua salesman web app`: `npm run build` -> 11 static/dynamic routes optimized
  - `grand aqua super admin android app`: `flutter analyze` -> 0 errors
  - `grand aqua salesman android app`: `flutter analyze` -> 0 errors
  - `grand aqua buyer android app`: `flutter analyze` -> 0 errors

---

## 6. Shared Documentation Links

- [System Architecture](file:///d:/grand_aqua_full/grand-aqua/grand%20aqua%20shared%20documentation/SYSTEM_ARCHITECTURE.md)
- [REST API Reference](file:///d:/grand_aqua_full/grand-aqua/grand%20aqua%20shared%20documentation/API_REFERENCE.md)
- [Deployment Guide](file:///d:/grand_aqua_full/grand-aqua/grand%20aqua%20shared%20documentation/DEPLOYMENT_GUIDE.md)
