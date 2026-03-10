# Paystack Payment Smoke Test Checklist

Use this after every payment-related change and function deploy.

## 1. Pre-flight

- Confirm `.env` has `PAYSTACK_PUBLIC_KEY` in Flutter and `PAYSTACK_SECRET_KEY` in Cloud Functions runtime.
- Confirm Functions are deployed from `functions/`.
- Sign in with a real Firebase user in the app.

## 2. Happy Path: Client pays caregiver

1. Open `ClientPaymentScreen`.
2. Enter amount `1000` KES.
3. Proceed to checkout and complete payment.
4. Expect UI success message and return to previous screen.

Expected Firestore state:

- `transactions/{reference}` exists.
- Required fields present:
  - `clientId`
  - `caregiverId`
  - `amount` (base amount)
  - `platformFee` (2% of base amount)
  - `caregiverEarnings` (base amount)
  - `status` = `completed`
  - `paystackData` (verification payload)
  - `verifiedAt`
- `caregiver_wallets/{caregiverId}` updated:
  - `balance` increased by base amount
  - `totalEarnings` increased by base amount
  - `transactionIds` contains `reference`

## 3. Cancel Path

1. Start payment.
2. Cancel from Paystack checkout.

Expected:

- App shows cancellation error and retry option.
- `transactions/{reference}.status` remains `pending`.
- A document is added to `payment_failures` with:
  - `reference`
  - `reason`
  - `createdAt`

## 4. Idempotency Check (No double credit)

1. Complete one successful payment.
2. Manually invoke completion flow again for same `reference` (or retry same completion path).

Expected:

- Wallet is not credited twice.
- Transaction remains `completed`.

## 5. Function Endpoint Checks

- `initializeTransaction` callable exists and returns `data.access_code`.
- `verifyTransaction` callable exists and returns `verified: true` on successful reference.
- `logPaymentFailure` callable exists and writes to `payment_failures`.

## 6. Regression Checks

- Payment history screen still loads completed transactions.
- Dashboard pending counters do not include completed payment.
- No analyzer errors in:
  - `lib/screens/client_payment_screen.dart`
  - `lib/screens/paystack_checkout_screen.dart`
  - `lib/services/payment_firestore_service.dart`
  - `functions/index.js`

## 7. Quick Triage Guide

- Initialization failure: check callable name (`initializeTransaction`) and function deployment.
- Verification failure: confirm Paystack secret key in function environment.
- Missing wallet credit: inspect `transactions/{reference}` for `caregiverId` and `status`.
- Duplicate credits: verify `completeTransaction` idempotency guard is present.
