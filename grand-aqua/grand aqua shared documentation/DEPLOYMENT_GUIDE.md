# Grand Aqua — Deployment & Environment Setup Guide

## 1. Prerequisites

- **Node.js:** v18.x, v20.x, or v22.x LTS
- **MongoDB:** v7.0.x (with replica set enabled) or **PostgreSQL** v14/15+
- **Flutter SDK:** v3.22.x+ with Dart 3.4+
- **Android Studio / Android SDK:** For building Android APKs

---

## 2. Shared Environment Setup

Create `.env` inside `grand-aqua/grand aqua backend/`:

```env
PORT=4000
NODE_ENV=production
# MongoDB Replica Set:
DATABASE_URL="mongodb://127.0.0.1:27018/grand_aqua_db?replicaSet=rs0&directConnection=true"
JWT_SECRET="grand_aqua_super_secure_jwt_token_key_2026_xyz"
JWT_EXPIRATION="7d"

# Storage
STORAGE_PROVIDER="local"
UPLOAD_DIR="./uploads"

# SMS Gateway (Fast2SMS / Twilio)
SMS_PROVIDER="mock"
SMS_API_KEY="your_api_key_here"

# Payments (Razorpay / Cashfree)
PAYMENT_GATEWAY="mock"
RAZORPAY_KEY_ID="rzp_test_key"
RAZORPAY_KEY_SECRET="rzp_test_secret"
```

---

## 3. Running the Backend

```bash
cd "grand-aqua/grand aqua backend"

# Install dependencies
npm install

# Run database migrations
npx prisma migrate deploy

# Seed initial Super Admin, Salesmen, Products, and Buyers
npm run seed

# Build production bundle
npm run build

# Start production server
npm run start:prod
```

Server will start on `http://localhost:4000`. Swagger is accessible at `http://localhost:4000/api/v1/docs`.

---

## 4. Running the Web Applications

### A. Super Admin Web App
```bash
cd "grand-aqua/grand aqua super admin web app"
npm install
npm run build
npm start -- -p 3000
```
Runs at: `http://localhost:3000`

### B. Salesman Web App
```bash
cd "grand-aqua/grand aqua salesman web app"
npm install
npm run build
npm start -- -p 3001
```
Runs at: `http://localhost:3001`

---

## 5. Building the Flutter Android Applications

All three Flutter applications use `Dio` configured with `http://10.0.2.2:4000/api/v1` for Android Emulators, or custom base URLs when building production release APKs.

### A. Super Admin Android App
```bash
cd "grand-aqua/grand aqua super admin android app"
flutter pub get
flutter build apk --release
```

### B. Salesman Android App
```bash
cd "grand-aqua/grand aqua salesman android app"
flutter pub get
flutter build apk --release
```

### C. Buyer Android App
```bash
cd "grand-aqua/grand aqua buyer android app"
flutter pub get
flutter build apk --release
```

Generated APKs will be located at `build/app/outputs/flutter-apk/app-release.apk` in each respective folder.

---

## 6. Seed Credentials for Quick Testing

- **Super Admin:**
  - Email: `admin@grandaqua.com`
  - Password: `GrandAqua@Admin2026`
- **Field Salesman:**
  - Email: `amit.sharma@grandaqua.com`
  - Password: `Salesman@2026`
- **Buyer Mobile OTP:**
  - Phone: `+919811122233` (or any valid mobile number)
  - Dev/Mock OTP: `123456`

---

## 7. Commercial Quotations & Visual Features (Latest Updates)

### A. Quotation Itemized Layout
All 5 applications and the backend PDF generator follow a standardized commercial layout:
- **Columns:** `#` | `Image` | `Product` | `Qty` | `Price` | `Total`
- **Product Visuals:** Displays actual product image thumbnails where available.
- **Camera Fallback Glyph:** Automatically renders a circular camera vector glyph with a diagonal slash when no product photo exists.
- **Table Footer Summary:** Includes a dedicated `Total` row matching quotation subtotal.
- **Download PDF:** Available via `GET /api/v1/quotations/:id/pdf` directly in Super Admin, Salesman, and Buyer apps.

### B. Super Admin Target & Incentive Removal
- Monthly and quarterly salesman sales targets are completely removed from forms, mutations, state, and UI.
- The Incentive Engine has been decommissioned from the Super Admin navigation and dashboard.
- Active Sales Force metric replaces incentive stats.

