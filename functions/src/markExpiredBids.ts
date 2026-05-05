import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Scheduled Cloud Function to mark expired bids
 * Runs daily at 2 AM UTC
 */
export const markExpiredBidsDaily = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context: functions.EventContext) => {
    console.log('🔄 Starting daily bid expiration check...');
    return markExpiredBidsTask();
  });

/**
 * Scheduled Cloud Function to mark expired bids
 * Runs every 6 hours for faster cleanup
 */
export const markExpiredBidsEvery6Hours = functions.pubsub
  .schedule('0 */6 * * *')
  .timeZone('UTC')
  .onRun(async (context: functions.EventContext) => {
    console.log('🔄 Starting 6-hourly bid expiration check...');
    return markExpiredBidsTask();
  });

/**
 * On-demand HTTP endpoint to manually trigger bid expiration
 * Can be called by admin dashboard
 */
export const manuallyMarkExpiredBids = functions.https.onRequest(
  async (req, res) => {
    // Optional: Add authentication check
    const authToken = req.headers.authorization;
    if (!authToken || !authToken.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    try {
      const result = await markExpiredBidsTask();
      res.status(200).json(result);
    } catch (error) {
      console.error('❌ Error marking expired bids:', error);
      res.status(500).json({ error: error instanceof Error ? error.message : String(error) });
    }
  }
);

/**
 * Main task: Mark all expired bids
 */
async function markExpiredBidsTask() {
  const now = admin.firestore.Timestamp.now();
  let expiredCount = 0;
  let processedBids = 0;
  let errorCount = 0;

  try {
    // Get all jobs
    const jobsSnapshot = await db.collection('jobs').get();
    console.log(`📋 Found ${jobsSnapshot.size} jobs to check`);

    for (const jobDoc of jobsSnapshot.docs) {
      const jobId = jobDoc.id;

      try {
        // Get pending bids that have expired
        const expiredBidsSnapshot = await db
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .where('status', '==', 'pending')
          .where('expiresAt', '<', now)
          .get();

        processedBids += expiredBidsSnapshot.size;

        // Update each expired bid
        for (const bidDoc of expiredBidsSnapshot.docs) {
          try {
            await bidDoc.ref.update({
              status: 'expired',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              expiredAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            expiredCount++;
            console.log(`✅ Expired bid: ${bidDoc.id} in job: ${jobId}`);
          } catch (error) {
            errorCount++;
            console.error(`❌ Error updating bid ${bidDoc.id}:`, error);
          }
        }

        // Check if job still has pending bids
        const remainingPendingBids = await db
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .where('status', '==', 'pending')
          .get();

        if (remainingPendingBids.size === 0) {
          // Update job metadata
          await jobDoc.ref.update({
            hasPendingBids: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`📋 Job ${jobId} no longer has pending bids`);
        }
      } catch (error) {
        errorCount++;
        console.error(`❌ Error processing job ${jobId}:`, error);
      }
    }

    const result = {
      success: true,
      expiredCount,
      processedBids,
      errorCount,
      timestamp: new Date().toISOString(),
    };

    console.log(`🎉 Bid expiration check completed:`, result);
    return result;
  } catch (error) {
    console.error('❌ Critical error in markExpiredBidsTask:', error);
    throw error;
  }
}

/**
 * Callable Cloud Function for client-side expiration check
 * Can be called from Dart app for real-time validation
 */
export const checkBidExpiration = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
    if (!context?.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const jobId = data?.jobId;
    const caregiverId = data?.caregiverId;

    if (!jobId || !caregiverId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'jobId and caregiverId are required'
      );
    }

    try {
      const bidDoc = await db
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(caregiverId)
        .get();

      if (!bidDoc.exists) {
        return { exists: false };
      }

      const bidData = bidDoc.data();
      const now = admin.firestore.Timestamp.now();
      const expiresAt = bidData?.expiresAt;

      const isExpired = expiresAt && expiresAt < now;

      // Update if expired
      if (isExpired && bidData?.status === 'pending') {
        await bidDoc.ref.update({
          status: 'expired',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return {
        exists: true,
        status: isExpired ? 'expired' : bidData?.status,
        expiresAt: bidData?.expiresAt,
        isExpired,
      };
    } catch (error) {
      console.error('❌ Error checking bid expiration:', error);
      throw new functions.https.HttpsError('internal', error instanceof Error ? error.message : String(error));
    }
  }
);
