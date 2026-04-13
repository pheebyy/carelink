# Phase 2: Instant Cancellation Refunds

## 📋 Overview

Phase 2 enables clients to cancel jobs **before they start** and receive **instant refunds** to their original payment method (Paystack). This improves user trust and provides financial protection for clients who change their minds.

### Key Features
- ✅ Cancel jobs before start time
- ✅ Instant refunds to original payment method
- ✅ Admin dashboard for refund management
- ✅ Automatic retry on Paystack failures (up to 3 attempts)
- ✅ Manual override for admin edge cases
- ✅ Audit trail for all refunds

### Business Logic
- **Refundable Statuses**: `open`, `applied`, `hired`
- **Non-Refundable**: Jobs already `in-progress`, `completed`, or `canceled`
- **Authorization**: Only job client or admin can initiate refund
- **Timeline**: Must cancel **before job start time**
- **Amount**: Full payment amount refunded (platform fee included)

---

## 🏗️ Architecture

### Firestore Collections

#### `refunds/{refundId}`
Tracks all cancellation refund requests and their status.

```firestore
{
  refundId: "refund_job123_1626789012345",
  jobId: "job123",
  transactionId: "tx123",
  clientId: "user456",
  caregiverId: "user789",
  
  // Amounts
  amount: 5000,                    // Full payment in KES
  currency: "KES",
  
  // Status Flow: pending → processing → completed / failed
  status: "pending",
  
  // Cancellation Details
  reason: "Found another caregiver",
  cancelledBy: "client",           // "client" or "admin"
  
  // Payment Integration
  paymentMethod: "paystack",       // Original payment method
  refundMethod: "paystack",        // Refund destination
  paystackReference: "123456789",  // Original transaction ref
  refundReference: null,           // Set after Paystack refund
  
  // Timestamps
  createdAt: Timestamp,
  processedAt: null,               // When Paystack started refund
  completedAt: null,               // When refund completed
  
  // Retry Logic
  attempts: 0,                     // Number of Paystack attempts
  maxAttempts: 3,                  // Max retry attempts
  failureReason: null,             // Error message if failed
  
  // Admin Override
  manuallyApprovedBy: null,        // Admin UID if manually approved
  approvalNote: null,              // Admin note for override
}
```

### Cloud Functions

#### 1. `initiateInstantRefund(jobId, reason, cancelledBy)`
**Triggered**: Client or admin cancels a job
**Action**: Creates refund record, updates job/transaction status

**Request**:
```javascript
{
  jobId: "job_12345",
  reason: "Found another caregiver",
  cancelledBy: "client"  // or "admin"
}
```

**Response**:
```javascript
{
  success: true,
  refundId: "refund_job_12345_timestamp",
  message: "Refund initiated",
  amount: 5000,
  status: "pending"
}
```

**Validation**:
- ✓ User is authenticated (client or admin)
- ✓ Job exists
- ✓ Job hasn't started (currentTime < startTime)
- ✓ Job status is refundable (open, applied, hired)
- ✓ Payment transaction exists
- ✓ Transaction not already refunded
- ✓ User is job client or admin

**Side Effects**:
1. Creates refund document in `refunds/{refundId}`
2. Updates job: `status = "canceled"`, `canceledAt = now`, `cancelReason`
3. Updates transaction: `status = "refunding"`, `refundId`
4. Sends client email: "Refund Initiated"
5. Triggers async Paystack refund processing

#### 2. `listRefunds(status?, limit) → Admin`
Fetches all refunds with optional status filter, used by admin dashboard.

**Request**:
```javascript
{
  status: "pending",  // or "processing", "completed", "failed"
  limit: 50
}
```

**Response**:
```javascript
{
  refunds: [...],
  count: 5
}
```

#### 3. `getRefundDetails(refundId) → Client or Admin`
Gets detailed info about a single refund.

**Authorization**:
- Admin: Can view any refund
- Client: Can only view own refunds

#### 4. `retryFailedRefund(refundId) → Admin`
Retries a failed refund (max 3 attempts total).

**Validation**:
- ✓ Admin only
- ✓ Refund status is "failed"
- ✓ Attempts < maxAttempts

**Side Effects**:
- Updates refund: `status = "pending"`, `attempts++`
- Triggers Paystack retry

#### 5. `manualRefundApproval(refundId, approvalNote) → Admin`
Admin override to mark refund completed without Paystack verification.

**Use Cases**:
- Paystack refund confirmed via email/dashboard but webhook didn't fire
- Manual bank transfer completed
- Edge case handling

**Side Effects**:
1. Updates refund: `status = "completed"`, `completedAt`
2. Updates transaction: `status = "refunded"`
3. Sends client email: "Refund Completed"

---

## 📱 Mobile App Integration

### Job Details Screen - Cancel Button

Add a "Cancel Job" button to the job details screen (before start time):

```dart
// In JobDetailsScreen widget

if (isJobOwner && job.status != 'completed' && job.status != 'in-progress') {
  if (job.startDate != null && DateTime.now().isBefore(job.startDate!)) {
    ElevatedButton.icon(
      onPressed: _showCancelDialog,
      icon: Icon(Icons.close),
      label: Text('Cancel Job (Refund)'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[100],
        foregroundColor: Colors.red[900],
      ),
    );
  }
}
```

### Cancel Confirmation Dialog

```dart
void _showCancelDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Cancel Job & Request Refund?'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('By canceling, you will:'),
          SizedBox(height: 12),
          Text('✓ Cancel the job'),
          Text('✓ Request refund of KES ${widget.job.budget}'),
          Text('✓ Notify the caregiver'),
          SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'Cancellation reason',
              hintText: 'e.g., Found another caregiver',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Keep Job'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await _initiateCancelRefund();
          },
          icon: Icon(Icons.close),
          label: Text('Cancel & Refund'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
        ),
      ],
    ),
  );
}
```

### Cloud Function Call

```dart
Future<void> _initiateCancelRefund() async {
  try {
    final functions = FirebaseFunctions.instance;
    final result = await functions.httpsCallable('initiateInstantRefund').call({
      'jobId': widget.job.id,
      'reason': _reasonController.text,
      'cancelledBy': 'client',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.data['message']),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.pop(context); // Close dialog
    Navigator.pop(context); // Go back to jobs list
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

---

## 🎯 Admin Dashboard - Refunds Page

### Features

1. **Stats Cards**: 
   - Total refunds processed
   - Pending amount (KES)
   - Completed amount (KES)
   - Failed refunds count

2. **Filter Buttons**:
   - All | Pending | Processing | Completed | Failed

3. **Refunds Table**:
   - Refund ID (shortened)
   - Job ID
   - Amount (KES)
   - Status (colored chip)
   - Reason
   - Created date
   - Action button → View Details

4. **Details Dialog**:
   - Full refund information
   - Paystack reference
   - Status timeline
   - Actions:
     - **Retry** (if failed & attempts < 3)
     - **Manual Approval** (if failed)

### URL
```
/admin/refunds
```

---

## 🔄 Refund Status Workflow

```
┌──────────┐
│ PENDING  │  Client initiated refund
└────┬─────┘  Waiting for Paystack processing
     │
     ↓
┌──────────┐
│PROCESSING│  Paystack is processing refund
└────┬─────┘
     │
     ├─→ ✅ COMPLETED  (Paystack webhook: refund.processed)
     │    └─ Sends client email
     │
     └─→ ❌ FAILED     (Paystack webhook: refund.failed)
          └─ Admin can retry (max 3 times)
          └─ Admin can manually approve
```

---

## 💳 Paystack Integration

### Original Payment Reference → Refund

When initiating refund, we use the **original Paystack transaction reference** to refund via Paystack API.

```
Job Payment Flow:
1. Client pays → Paystack transaction created
2. Reference stored in transactions.reference

Cancel Job Flow:
1. Client clicks "Cancel Job"
2. We create refund record
3. Send refund request to Paystack with original reference
4. Paystack processes and sends webhook
5. We update refund status based on webhook
```

### Paystack Webhook Events

**Supported Events**:
- `refund.processed` → Refund successful
- `refund.failed` → Refund failed

**Webhook Payload**:
```json
{
  "event": "refund.processed",
  "data": {
    "reference": "12345_refund_xyz",
    "amount": 500000  // in kobo
  }
}
```

---

## 🧪 Testing Phase 2

### Manual Test Flow

```
1. Create a test job in Firebase:
   - Status: "open"
   - StartDate: Tomorrow
   - Budget: 1000 KES
   - ClientId: test_user_123
   - PaymentReference: tx_001

2. Create a test transaction:
   - ID: tx_001
   - Amount: 1000
   - Status: "completed"
   - Reference: "paystack_ref_123"

3. Call initiateInstantRefund Cloud Function:
   - jobId: test_job_123
   - reason: "Testing Phase 2"
   - cancelledBy: "client"
   - Expected: refundId created, status "pending"

4. Check Firebase:
   - refunds collection has new document
   - jobs/{test_job_123}.status = "canceled"
   - transactions/{tx_001}.status = "refunding"

5. Admin Dashboard:
   - Open /admin/refunds
   - Should see pending refund
   - Click "View"
   - Check refund details
```

### Test Cases

**TC1: Successful Refund**
- Job is open, before start time
- Client initiates refund
- Refund succeeds
- Result: Refund marked completed, client receives funds

**TC2: Job Already Started**
- Job is in-progress
- Client attempts refund
- Result: Error "Cannot refund: Job has already started"

**TC3: Already Refunded**
- Transaction already has status "refunded"
- Result: Error "Payment already refunded"

**TC4: Admin Retry Failed Refund**
- Refund stuck in "failed" (max 2 attempts)
- Admin clicks "Retry"
- Result: Status back to "pending", attempt counter incremented

**TC5: Admin Manual Approval**
- Refund failed (Paystack down)
- Admin verified refund manually
- Admin clicks "Manual Approval" with note
- Result: Refund marked completed, client notified

---

## 📊 Metrics & Monitoring

### Key Metrics

```
1. Refund Rate
   = (Completed Refunds / Total Jobs) × 100
   Target: < 2% (too high indicates product issues)

2. Refund Success Rate
   = (Completed Refunds / Initiated Refunds) × 100
   Target: > 98% (Paystack reliability)

3. Avg Refund Processing Time
   = Avg(completedAt - createdAt)
   Target: < 2 hours (instant perception)

4. Manual Override Rate
   = (Manual Approvals / Failed Refunds) × 100
   Target: < 5% (edge cases)
```

### Monitoring via Firebase

Monitor refund collection for:
- Growth in failed refunds (possible Paystack issues)
- High manual override rate (integration problem)
- Retry attempts > 2 (network reliability)

---

## 🚀 Deployment

### Step 1: Update Firestore Rules
```bash
firebase deploy --only firestore:rules
```

Validates the refunds collection rules.

### Step 2: Deploy Cloud Functions
```bash
firebase deploy --only functions
```

Deploys all 5 new refund functions:
- initiateInstantRefund
- listRefunds
- getRefundDetails
- retryFailedRefund
- manualRefundApproval

### Step 3: Update Admin Dashboard
Routes available after deployment:
- GET `/admin/refunds` - Refunds page

### Step 4: Update Mobile App
Add cancel refund button to job details screen.

---

## 🔐 Security

### Authorization

| Function | Client | Admin | CF |
|----------|--------|-------|---|
| initiateInstantRefund | Job owner | Yes | No |
| listRefunds | No | Yes | No |
| getRefundDetails | Own refunds | Yes | No |
| retryFailedRefund | No | Yes | No |
| manualRefundApproval | No | Yes | No |

### Validation

- Client can only cancel jobs they created
- Admin can cancel any job
- Cancellation only allowed before start time
- Transaction must exist and not be refunded
- Refund logic isolated in Cloud Functions (no client writes to refunds)

---

## 🐛 Troubleshooting

### Issue: "Maximum retry attempts exceeded"
**Cause**: Paystack refund failed 3 times
**Solution**: 
1. Check Paystack dashboard for account issues
2. Admin can use "Manual Approval"
3. Contact Paystack support if persists

### Issue: Refund stuck in "processing"
**Cause**: Webhook from Paystack didn't arrive
**Solution**:
1. Give 5-10 minutes for webhook retry
2. Check Paystack webhook logs
3. Admin can manually approve after verification

### Issue: Client never received refund email
**Cause**: Email service error
**Solution**:
1. Check Firebase email log (sendEmail function)
2. Verify client email address in users collection
3. Resend manually via admin dashboard

---

## 📈 Future Enhancements (Phase 2.5+)

### 2.5: Partial Refunds
- Allow admin to refund partial amounts
- Useful for disputes or negotiated cancellations

### 2.6: Refund Analytics
- Dashboard charts: refund trends, reasons analysis
- Export refund reports

### 2.7: Scheduled Refunds
- Defer refund processing to off-peak hours
- Better for Paystack rate limits

### 2.8: Refund Policies
- Different refund rates (e.g., 50% if < 24h before start)
- Configurable by admin

---

## 📞 Support & Questions

For issues or questions about Phase 2:
1. Check Firestore rules compilation
2. Verify Cloud Functions deployment status
3. Review function logs in Firebase Console
4. Check Paystack webhook delivery
5. Verify mobile app is passing correct parameters

---

**Last Updated**: April 2026
**Status**: ✅ Production Ready
