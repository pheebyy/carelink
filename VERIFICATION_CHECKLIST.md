# ✅ 7-Day Bid Expiration Verification Checklist

## Pre-Deployment Verification

- [ ] `lib/utils/bid_expiration_helper.dart` exists
- [ ] `functions/src/markExpiredBids.ts` exists  
- [ ] `lib/screens/caregiver_bids_screen.dart` exists
- [ ] `lib/services/firestore_service.dart` has updated createBid() with expiresAt field
- [ ] `lib/app_router.dart` has caregiver_bids_screen import
- [ ] `lib/app_router.dart` has '/caregiver-bids' route

## Deployment Verification

### Cloud Functions Setup
- [ ] Run: `cd functions && npm install`
- [ ] Run: `npm run build` (should succeed)
- [ ] Run: `firebase deploy --only functions`
- [ ] Verify: All 4 functions deployed in Firebase Console
  - [ ] markExpiredBidsDaily
  - [ ] markExpiredBidsEvery6Hours
  - [ ] manuallyMarkExpiredBids
  - [ ] checkBidExpiration

### Flutter Setup
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter analyze` (should show no errors)
- [ ] Run: `flutter run`

---

## Functional Testing

### Test 1: Bid Creation with Expiration
**Steps:**
1. Login as caregiver
2. Go to any job and create a bid (amount: 5000, proposal: "Test bid")
3. Check Firestore console: jobs/{jobId}/bids/{caregiverId}

**Verification:**
- [ ] Bid appears with status "pending"
- [ ] expiresAt field exists and is exactly 7 days from now
- [ ] createdAt timestamp is set
- [ ] caregiverId matches logged-in user

**Expected expiresAt:**
```
Today: 2026-05-04
Expected expiresAt: 2026-05-11
```

---

### Test 2: Caregiver Bids Screen Navigation
**Steps:**
1. Navigate to `/caregiver-bids` route
2. Observe the screen

**Verification:**
- [ ] Screen loads without error
- [ ] 4 tabs visible: Pending, Approved, Rejected, Expired
- [ ] Pending tab shows the bid created in Test 1
- [ ] Other tabs show empty state

---

### Test 3: Countdown Display
**Steps:**
1. On Pending tab, view the bid card from Test 1
2. Look for countdown timer

**Verification:**
- [ ] Countdown box visible with blue border
- [ ] Format: "⏰ Expires in 6 days, 23 hours" (approx, depending on time)
- [ ] Color: Green background
- [ ] Schedule icon present
- [ ] Countdown displays correct remaining days/hours

---

### Test 4: Countdown Auto-Update
**Steps:**
1. Note the countdown value
2. Wait 1 minute
3. Stay on the app (or reopen screen)
4. Check countdown again

**Verification:**
- [ ] Countdown minutes changed (should decrease)
- [ ] OR days/hours changed if boundary crossed
- [ ] No manual refresh needed

---

### Test 5: Expiring Soon Warning
**Steps:**
1. Go to Firestore console
2. Find the bid from Test 1
3. Edit expiresAt field to 12 hours from now
4. Refresh app or re-navigate to screen

**Verification:**
- [ ] Countdown box now has RED border
- [ ] Text color changed to RED
- [ ] Format shows hours: "🚨 Expires in 12 hours, 0 minutes"
- [ ] Warning icon appears

---

### Test 6: Bid Auto-Expiration
**Steps:**
1. Go to Firestore console
2. Edit the expiresAt field to 1 minute ago
3. Refresh app or click on the bid tab

**Verification:**
- [ ] Bid no longer appears in "Pending" tab (or moved to Expired)
- [ ] Go to "Expired" tab
- [ ] Bid appears there with status "expired"
- [ ] Countdown shows "❌ Expired"
- [ ] Color is Gray

---

### Test 7: Bid Withdrawal
**Steps:**
1. Create a new bid (Test 1 repeat)
2. Go to Caregiver Bids screen
3. On Pending tab, click "Withdraw" button
4. Confirm withdrawal in dialog

**Verification:**
- [ ] Withdrawal confirmation dialog appears
- [ ] After confirming, success message shows: "✅ Bid withdrawn successfully"
- [ ] Bid no longer appears in Pending tab

**In Firestore:**
- [ ] Bid status changed to "withdrawn"
- [ ] withdrawnAt timestamp is set

---

### Test 8: Cloud Function Manual Trigger
**Steps:**
1. Go to Firebase Console
2. Navigate to: Cloud Functions → markExpiredBidsDaily
3. Click "TESTING" tab
4. Click the function to expand
5. Click "TRIGGER"

**Verification:**
- [ ] Function executes (may take 1-2 minutes)
- [ ] Go to "LOGS" tab
- [ ] See output containing: "🎉 Bid expiration check completed"
- [ ] Log shows: { expiredCount: X, processedBids: Y, errorCount: 0 }

---

### Test 9: Multiple Bids Lifecycle
**Steps:**
1. Create 3 bids on different jobs
2. Monitor them over time
3. Manually expire one at a time in Firestore

**Verification:**
- [ ] All 3 appear in Pending tab initially
- [ ] Expire first bid → moves to Expired tab
- [ ] Approve second bid (via Firestore update) → moves to Approved tab
- [ ] Withdraw third bid → status shows withdrawn
- [ ] Tabs update correctly in real-time

---

## Firestore Data Validation

### Check Bid Document Structure
Navigate to: `jobs/{any_jobId}/bids/{caregiverId}`

**Required Fields:**
- [ ] `jobId` (string)
- [ ] `caregiverId` (string)
- [ ] `amount` (number)
- [ ] `proposal` (string)
- [ ] `status` (string: pending|approved|rejected|expired|withdrawn)
- [ ] `expiresAt` (Timestamp) ← **CRITICAL: Must be exactly 7 days after creation**
- [ ] `createdAt` (Timestamp)
- [ ] `updatedAt` (Timestamp)

**Optional Fields (appear after actions):**
- [ ] `approvedAt` (Timestamp) - appears when bid is approved
- [ ] `expiredAt` (Timestamp) - appears when bid expires
- [ ] `withdrawnAt` (Timestamp) - appears when withdrawn

---

## Performance & Edge Cases

### Test 10: Expired Bid Doesn't Show in Pending
- [ ] Set expiresAt to past date
- [ ] Refresh Pending tab
- [ ] Verify bid NOT in Pending tab

### Test 11: No Race Condition
- [ ] Approve a bid that's about to expire
- [ ] Verify it doesn't auto-expire to "expired" after approval
- [ ] Check in Firestore: status should be "approved" (not "expired")

### Test 12: Timezone Handling
- [ ] Verify expiresAt calculation uses DateTime.now() (device local time)
- [ ] Countdown calculations are in user's local timezone
- [ ] Cloud Function uses UTC (2 AM UTC schedule)

---

## Rollback Plan (If Issues Occur)

If tests fail, follow this order:

1. **Bid creation not setting expiresAt:**
   - [ ] Check `lib/services/firestore_service.dart` createBid() method
   - [ ] Verify line with `expiresAt: Timestamp.fromDate(DateTime.now().add(const Duration(days: 7)))`
   - [ ] Rebuild and redeploy

2. **Countdown not displaying:**
   - [ ] Check import in `caregiver_bids_screen.dart`: `import '../utils/bid_expiration_helper.dart';`
   - [ ] Verify _buildExpirationCountdown() is called for pending bids
   - [ ] Check _countdownTimer initialization in initState

3. **Cloud Function not running:**
   - [ ] Check Firebase Console → Scheduler
   - [ ] Verify markExpiredBidsDaily is enabled
   - [ ] Manually trigger and check logs
   - [ ] Redeploy with: `firebase deploy --only functions:markExpiredBidsDaily`

4. **Navigation to bids screen fails:**
   - [ ] Check `lib/app_router.dart` has both import and route
   - [ ] Verify route name matches: `/caregiver-bids`
   - [ ] Rebuild app

---

## Sign-Off

After completing all tests:

- [ ] All tests passed
- [ ] No errors in Firebase logs
- [ ] Firestore data structure correct
- [ ] Cloud Function triggered successfully
- [ ] UI displays countdown correctly

**Date Completed:** _______________  
**Tested By:** _______________  
**Status:** ✅ READY FOR PRODUCTION

---

## Notes

- 7-day expiration is **exactly 7 days** from creation time
- Countdown updates **every minute** via Timer
- Cloud Function runs **daily at 2 AM UTC** + **every 6 hours**
- No manual expiration needed - fully automated
- Bids automatically move from Pending → Expired after 7 days
