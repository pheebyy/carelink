# 7-Day Bid Expiration System - Implementation & Deployment Guide

## ✅ Implementation Status

### Files Created
- [x] `lib/utils/bid_expiration_helper.dart` - Countdown calculation utilities
- [x] `functions/src/markExpiredBids.ts` - Cloud Function for automatic cleanup
- [x] `lib/screens/caregiver_bids_screen.dart` - Caregiver bid management UI
- [x] Updated `lib/services/firestore_service.dart` - Expiration methods + createBid update
- [x] Updated `lib/app_router.dart` - Added /caregiver-bids route

---

## 🚀 Deployment Steps

### Step 1: Install TypeScript Dependencies for Cloud Functions
```bash
cd functions
npm install
```

### Step 2: Build TypeScript Cloud Functions
```bash
npm run build
```

### Step 3: Deploy Cloud Functions
```bash
firebase deploy --only functions

# Or deploy specific functions:
firebase deploy --only functions:markExpiredBidsDaily
firebase deploy --only functions:markExpiredBidsEvery6Hours
firebase deploy --only functions:manuallyMarkExpiredBids
firebase deploy --only functions:checkBidExpiration
```

### Step 4: Verify Firebase Scheduler Setup
- Go to Firebase Console → Cloud Scheduler
- Verify `markExpiredBidsDaily` (runs at 2 AM UTC)
- Verify `markExpiredBidsEvery6Hours` (runs every 6 hours)

### Step 5: Build and Run Flutter App
```bash
flutter pub get
flutter run
```

---

## 🧪 Testing Checklist

### Manual Testing

#### Test 1: Create Bid with Expiration
- [ ] Login as caregiver
- [ ] Create a bid on a job
- [ ] Verify bid has `expiresAt` field set to exactly 7 days from now
- [ ] Navigate to caregiver-bids screen
- [ ] Verify bid appears in "Pending" tab

#### Test 2: Countdown Display
- [ ] View pending bid
- [ ] Verify countdown shows "⏰ Expires in 6 days, 23 hours" (approx)
- [ ] Wait 1 minute, refresh
- [ ] Verify countdown updates

#### Test 3: Expiration Soon Warning
- [ ] Manually set a bid's expiresAt to 12 hours from now (in Firestore console)
- [ ] Refresh app
- [ ] Verify countdown shows "🚨 Expires in 12 hours"
- [ ] Verify expiration badge is RED (expiring soon)

#### Test 4: Auto-Expiration
- [ ] Set a bid's expiresAt to 1 minute ago (in Firestore console)
- [ ] Refresh app
- [ ] Verify bid automatically moves to "Expired" tab
- [ ] Verify status shows "❌ Expired"

#### Test 5: Bid Withdrawal
- [ ] Create a new bid
- [ ] On caregiver-bids screen, click "Withdraw"
- [ ] Confirm withdrawal
- [ ] Verify bid status changes to "withdrawn"

#### Test 6: Cloud Function Execution
- [ ] Go to Firebase Console → Cloud Functions → markExpiredBidsDaily
- [ ] Click "TRIGGER" manually
- [ ] Monitor logs
- [ ] Verify log shows: "🎉 Bid expiration check completed: { expiredCount, processedBids, errorCount }"

#### Test 7: Firestore Data Integrity
- [ ] Check Firestore: `jobs/{jobId}/bids/{caregiverId}`
- [ ] Verify all bids have:
  - ✅ `expiresAt` timestamp (7 days from creation)
  - ✅ `status` field (pending/approved/rejected/expired/withdrawn)
  - ✅ `createdAt` timestamp

---

## 📊 Expected Behavior

### Bid Lifecycle with Expiration

```
1. Bid Created
   - expiresAt = NOW + 7 days
   - status = 'pending'
   - Countdown displays in UI

2. Days 1-6 (Active)
   - Status: PENDING (orange badge)
   - Countdown: "⏰ Expires in X days, Y hours"
   - Color: Green

3. Last 24 Hours (Expiring Soon)
   - Status: PENDING (orange badge)
   - Countdown: "🚨 Expires in X hours, Y minutes"
   - Color: RED
   - Warning icon displayed

4. After 7 Days
   - Cloud Function marks bid as 'expired'
   - status = 'expired'
   - Countdown: "❌ Expired"
   - Bid moves to "Expired" tab
   - Color: Gray

5. Client Can Approve Before Expiration
   - Approves bid → status = 'approved'
   - Bid moves to "Approved" tab
   - Countdown no longer displays

6. Caregiver Can Withdraw
   - Only pending bids can be withdrawn
   - status = 'withdrawn'
   - Bid moves to... (check design)
```

---

## 🔧 Configuration

### Cloud Function Schedules

**markExpiredBidsDaily**
- Schedule: `0 2 * * *` (Daily at 2 AM UTC)
- Use case: Standard daily cleanup
- Suitable for: Most applications

**markExpiredBidsEvery6Hours**
- Schedule: `0 */6 * * *` (Every 6 hours: 0, 6, 12, 18 UTC)
- Use case: Faster expiration tracking
- Suitable for: High-volume bidding systems

### To Change Schedule:
Edit `functions/src/markExpiredBids.ts` and modify the cron expression.

---

## 🔍 Monitoring & Logs

### View Cloud Function Logs
```bash
firebase functions:log

# Or in Firebase Console:
# → Cloud Functions → markExpiredBidsDaily → Logs
```

### Expected Log Output
```
🔄 Starting daily bid expiration check...
📋 Found 42 jobs to check
✅ Expired bid: caregiver_123 in job: job_456
✅ Expired bid: caregiver_789 in job: job_012
📋 Job job_456 no longer has pending bids
🎉 Bid expiration check completed: {
  expiredCount: 12,
  processedBids: 12,
  errorCount: 0,
  timestamp: "2026-05-04T02:00:00.000Z"
}
```

---

## 🐛 Troubleshooting

### Issue: Bids not expiring after 7 days
**Solution:**
1. Check Cloud Scheduler in Firebase Console
2. Verify function is enabled: `markExpiredBidsDaily`
3. Check Cloud Function logs for errors
4. Manually trigger: `firebase deploy --only functions:markExpiredBidsDaily`

### Issue: Countdown not updating
**Solution:**
1. Verify timer is running: `_countdownTimer` in `caregiver_bids_screen.dart`
2. Check that `expiresAt` field exists in Firestore
3. Verify `BidExpirationHelper.calculateTimeRemaining()` logic
4. Restart app to reset timer

### Issue: Bid stuck in "pending" after expiration time
**Solution:**
1. Refresh app to trigger client-side check
2. Call `checkAndMarkExpiredBids()` manually
3. Manually trigger Cloud Function

### Issue: Cloud Function not deploying
**Solution:**
```bash
# Clear and rebuild
rm -rf functions/lib
npm run build
firebase deploy --only functions

# If permission issues:
firebase login
firebase deploy --only functions
```

---

## 📝 Firestore Collections Structure

```
jobs/
  {jobId}/
    bids/
      {caregiverId}/
        - jobId (string)
        - caregiverId (string)
        - amount (number)
        - proposal (string)
        - estimatedDuration (number)
        - status (string: pending|approved|rejected|expired|withdrawn)
        - expiresAt (Timestamp) ← KEY: 7 days from creation
        - createdAt (Timestamp)
        - updatedAt (Timestamp)
        - approvedAt (Timestamp, optional)
        - expiredAt (Timestamp, optional)
        - withdrawnAt (Timestamp, optional)
```

---

## 🎯 Key Features Implemented

✅ **7-day automatic expiration** - Bids expire exactly 7 days after creation  
✅ **Real-time countdown** - Updates every minute with formatted display  
✅ **Expiring soon warnings** - Red badge when < 24 hours left  
✅ **Client-side fallback** - Auto-expiration even if Cloud Function fails  
✅ **Scheduled cleanup** - Daily or 6-hourly automatic expiration  
✅ **Manual trigger** - Admin can trigger expiration on-demand  
✅ **Bid withdrawal** - Caregivers can withdraw pending bids before expiration  
✅ **Comprehensive logging** - Full audit trail in Firebase logs  

---

## 📞 Support & Next Steps

### If you encounter issues:
1. Check the troubleshooting section above
2. Review Cloud Function logs
3. Verify Firestore data structure
4. Check that imports are correct in all files

### Future Enhancements:
- [ ] Add expiration notification to client
- [ ] Add expiration to job search filters
- [ ] Add batch expiration check endpoint for admins
- [ ] Add UI for manual expiration in admin dashboard
- [ ] Add analytics for bid expiration rates
