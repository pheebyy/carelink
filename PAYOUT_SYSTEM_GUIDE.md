# Phase 1: Automated Payout System - Implementation Guide

## Overview

This guide covers the implementation of automated payout batches for caregivers. Instead of manual admin approvals, payouts are now generated automatically every day at 6 AM UTC, with admins managing the approval and completion workflow.

---

## Architecture

### Collections

```
payoutBatches/
  ├── {batchId}  (document)
  │   ├── batchId: string
  │   ├── totalPayouts: number
  │   ├── totalAmount: number (KES)
  │   ├── status: "pending" | "processing" | "completed"
  │   ├── createdAt: timestamp
  │   ├── processedAt: timestamp
  │   └── payouts/ (subcollection)
  │       ├── {payoutId} (individual payout record)
  │       ├── caregiverId: string
  │       ├── grossAmount: number
  │       ├── withholdingTax: number
  │       ├── netAmount: number
  │       ├── status: "pending" | "processing" | "completed" | "failed"
  │       ├── transactionIds: array
  │       └── reference: string (M-Pesa/bank ref)

transactions/  (existing - modified)
  ├── paidOut: boolean (NEW - tracks if paid in batch)
  └── paidOutBatchId: string (NEW - batch reference)

caregiver_wallets/  (existing - modified)
  └── nextPayoutDate: date (NEW - when next payout expected)
```

---

## Workflow

### Daily Payout Batch Generation (Scheduled)

**Time:** 6 AM UTC every day (via Cloud Scheduler)
**Function:** `generatePayoutBatch()`

#### Process:

1. Query `transactions` collection for:
   - `status == "completed"`
   - `paidOut == false`

2. Group transactions by `caregiverId`

3. For each caregiver:
   - Sum all `caregiverEarnings`
   - Calculate withholding tax (currently 0%, ready for jurisdiction rules)
   - Net amount = gross - tax

4. Create batch document with:
   - `status: "pending"`
   - Total amount and caregiver count
   - `createdAt` timestamp

5. Create individual payout records in `payoutBatches/{batchId}/payouts/`

6. Mark transactions as `paidOut: true` and `paidOutBatchId: {batchId}`

7. Set `nextPayoutDate` on affected caregiver wallets

8. Send notification emails to caregivers

#### Example Output:

```json
{
  "batchId": "batch_2026-04-10_1234567890",
  "totalPayouts": 15,
  "totalAmount": 45000,
  "status": "pending",
  "createdAt": "2026-04-10T06:00:00Z",
  "payouts": [
    {
      "caregiverId": "caregiver_123",
      "grossAmount": 3000,
      "withholdingTax": 0,
      "netAmount": 3000,
      "transactionCount": 5,
      "transactionIds": ["tx_1", "tx_2", "tx_3", "tx_4", "tx_5"]
    }
    // ... more caregivers
  ]
}
```

---

### Admin Approval Workflow

#### Step 1: Review Payout Batch

Admin navigates to **Payouts** page in admin dashboard.

**Visible:**
- Pending batch with total amount
- Number of caregivers affected
- Created timestamp

#### Step 2: View Batch Details

Admin clicks "View" on any batch.

**Shows:**
- All individual payouts
- Per-caregiver amounts
- Count of transactions per caregiver
- Current status of each payout

#### Step 3: Approve Batch

Admin clicks "Approve Batch" button.

**Actions:**
- Batch status: `pending` → `processing`
- All payouts status: `pending` → `processing`
- `processedAt` timestamp set
- Payouts ready for actual fund disbursement

**Email to Caregivers:** "Your payout has been initiated and is  being processed (1-2 business days)"

#### Step 4: Complete Payout

After M-Pesa/bank transfer succeeds:

Admin clicks "Complete" on individual payout.

**Input:**
- M-Pesa confirmation reference
- Bank transaction reference

**Actions:**
- Payout status: `processing` → `completed`
- `reference` field saved
- `completedAt` timestamp set
- Email to caregiver: "Your payout of KES X has been completed"

---

## Setup Instructions

### 1. Deploy Firestore Rules

The security rules have been updated to include `payoutBatches` collection:

```bash
cd c:\Users\chris\carelink
firebase deploy --only firestore:rules
```

This allows:
- ✅ Admins to read payout batches
- ✅ Cloud Functions to create/update batches
- ✅ Caregivers to see their own payout history

### 2. Add Cloud Functions

The payout functions are in `admin-dashboard/payout_functions.js`:

**Functions to add to `functions/index.js`:**

- `generatePayoutBatch` - Scheduled daily at 6 AM UTC
- `getPayoutBatchDetails` - Admin API to fetch batch details
- `approvPayoutBatch` - Approve pending batch
- `completePayout` - Mark individual payout complete

**To deploy:**

```bash
cd c:\Users\chris\carelink\functions
npm install  # if needed
firebase deploy --only functions
```

### 3. Add Admin UI Page

The payout management page is pre-created at:

`admin-dashboard/src/pages/payouts.js`

**Features:**
- View pending/completed payouts
- Stats dashboard (pending amount, completed amount, totals)
- Approve batch action
- Complete individual payout with reference
- Real-time updates

### 4. Update Navigation

Add to `admin-dashboard/src/components/Layout.js` menu items:

```javascript
{
  label: 'Payouts',
  href: '/payouts',
  icon: LocalAtmIcon,
  permission: 'canApprovePayouts',
}
```

**Already done in this implementation** ✅

### 5. Configure Scheduled Function

**In Firebase Console:**

1. Go to Cloud Scheduler
2. Create new job:
   - Name: `daily-payout-generation`
   - Frequency: `0 6 * * *` (6 AM UTC daily)
   - Timezone: UTC
   - Target type: Cloud Pub/Sub
   - Topic: `payout-generation`
   - Message body: `{}`

3. Or rely on `onSchedule` trigger (newer Firebase SDK handles this automatically)

### 6. Set Environment Variables

In `functions/.env`:

```
PAYSTACK_SECRET_KEY=your_key_here
SENDGRID_API_KEY=your_sendgrid_key_here  # Optional for email
```

---

## API Reference

### `generatePayoutBatch()` (Scheduled)

**Trigger:** Cloud Scheduler - Daily at 6 AM UTC

**Output:**
```json
{
  "success": true,
  "batchId": "batch_2026-04-10_1234567890",
  "caregivers": 15,
  "totalAmount": 45000
}
```

---

### `getPayoutBatchDetails()` (Admin API)

**Called from:** `payouts.js` page when admin clicks "View"

**Request:**
```javascript
{
  batchId: "batch_2026-04-10_1234567890"
}
```

**Response:**
```javascript
{
  batch: {
    id: "batch_2026-04-10_1234567890",
    totalPayouts: 15,
    totalAmount: 45000,
    status: "pending",
    createdAt: "2026-04-10T06:00:00Z"
  },
  payouts: [
    {
      id: "payout_123",
      caregiverId: "caregiver_123",
      grossAmount: 3000,
      withholdingTax: 0,
      netAmount: 3000,
      transactionCount: 5,
      status: "pending"
    }
    // ... more payouts
  ]
}
```

---

### `approvPayoutBatch()` (Admin Action)

**Called from:** `payouts.js` when admin clicks "Approve Batch"

**Request:**
```javascript
{
  batchId: "batch_2026-04-10_1234567890"
}
```

**Actions:**
- Batch status: `pending` → `processing`
- All payouts: `pending` → `processing`
- Notifications sent to caregivers

---

### `completePayout()` (Admin Action)

**Called from:** `payouts.js` when admin clicks "Complete" on specific payout

**Request:**
```javascript
{
  payoutId: "payout_123",
  batchId: "batch_2026-04-10_1234567890",
  reference: "MPG123456789",  // M-Pesa reference or bank ref
  method: "mpesa"  // or "bank_transfer"
}
```

**Actions:**
- Payout status: `processing` → `completed`
- Reference saved
- Caregiver notified via email

---

## Notifications

### Emails Sent

1. **Payout Initiated** (after batch approved):
   - Subject: "CareLink - Payout Initiated 💰"
   - Content: Amount, batch ID, expected time (1-2 business days)
   - Sent to: Caregiver email

2. **Payout Completed** (after admin marks complete):
   - Subject: "CareLink - Payout Completed ✅"
   - Content: Amount, reference, received date
   - Sent to: Caregiver email

**Note:** Emails require `SENDGRID_API_KEY` environment variable. If not set, notifications skip gracefully.

---

## Testing

### Manual Test: Generate a Batch

1. Create test transactions:
   ```javascript
   // In Firestore Console, manually create:
   db.collection('transactions').add({
     caregiverId: 'test_caregiver_1',
     status: 'completed',
     paidOut: false,
     caregiverEarnings: 5000,
     createdAt: new Date()
   })
   ```

2. Run the function manually:
   ```bash
   firebase functions:call generatePayoutBatch --region us-central1
   ```

3. Check Firestore:
   - `payoutBatches/{batchId}` document created
   - `payoutBatches/{batchId}/payouts/` subcollection has caregivers
   - Transactions marked `paidOut: true`

### UI Test: Approve Batch

1. Go to admin dashboard → Payouts page
2. Should see pending batch with total amount
3. Click "View" → see details
4. Click "Approve Batch" → status changes to "processing"
5. Click "Complete" on a payout → enter M-Pesa ref → status changes to "completed"

---

## Future Enhancements

### Phase 1.5: Multi-Currency Support
- Add payout currency selection
- Support multiple M-Pesa accounts by region

### Phase 2: Recurring Payouts
- Support weekly/bi-weekly/monthly cycles
- Calendar view of payout schedules

### Phase 3: Withholding Tax
- Add country/jurisdiction selection
- Auto-calculate tax based on gross amount
- Generate tax reports for accounting

### Phase 4: Webhook Integration
- Receive M-Pesa delivery confirmations
- Auto-update payout status when funds received
- Reduce manual admin work

---

## Troubleshooting

### Scheduled Function Not Running

**Issue:** `generatePayoutBatch` doesn't trigger at 6 AM

**Check:**
1. Firebase Console → Cloud Scheduler → verify job exists
2. Cloud Functions logs for errors: `firebase functions:log generatePayoutBatch`
3. Verify `onSchedule` decorator syntax

**Fix:**
```bash
firebase deploy --only functions
```

---

### Batch Not Appearing in UI

**Issue:** Created batch not visible in admin dashboard

**Check:**
1. Verify `payoutBatches` collection exists in Firestore
2. Check security rules: admin can read `payoutBatches`
3. Browser console for errors (F12 → Console)

**Fix:**
```bash
firebase deploy --only firestore:rules
```

---

### Notifications Not Sent

**Issue:** Caregivers don't receive emails

**Check:**
1. `SENDGRID_API_KEY` set in `functions/.env`
2. Email addresses exist in caregiver `users` documents
3. Firebase Cloud Functions logs for errors

**Fix:** Set SendGrid key:
```bash
firebase functions:config:set sendgrid.apikey="your_key"
```

---

## Monitoring

### Key Metrics

- **Batch generation time:** Should complete < 2 minutes for 1000+ caregivers
- **Payout accuracy:** Every caregiver's earnings matches completed transactions
- **Notification delivery:** All caregivers receive emails

### Dashboard Metrics

Track these in admin dashboard:

```javascript
{
  totalBatchesCreated: number,
  totalAmountPaidOut: number (KES),
  averagePayoutAmount: number,
  completionRate: percentage,
  failureRate: percentage,
  avgTimeToApprove: hours,
  avgTimeToComplete: hours
}
```

---

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Payout Trigger** | Manual admin action | Automatic daily at 6 AM |
| **Caregiver Wait Time** | Indefinite (admin approval needed) | Predictable (3-7 days) |
| **Admin Work** | Review each caregiver individually | Approve/complete in bulk |
| **Notifications** | Manual emails | Automatic at each stage |
| **Audit Trail** | Basic | Complete (batch ID, timestamps, references) |
| **Scalability** | Doesn't scale (manual) | Scales to thousands |

---

**Implementation complete!** 🎉 Ready for Phase 2 (Instant Cancellation Refunds) or Phase 3 (Job Bidding).
