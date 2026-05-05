const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();
// (SendGrid email helper removed — using in-app notifications and FCM only)

// Helper: create in-app notification and send push via FCM
async function createNotificationAndPush(clientId, payload) {
  try {
    // Create in-app notification document
    await db.collection('users').doc(clientId).collection('notifications').add({
      ...payload,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const userDoc = await db.collection('users').doc(clientId).get();
    if (!userDoc.exists) {
      console.log(`User ${clientId} not found for notification`);
      return;
    }

    const userData = userDoc.data() || {};
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.log(`No FCM tokens for user ${clientId}`);
      return;
    }

    const message = {
      notification: { title: payload.title || 'CareLink', body: payload.message || '' },
      data: payload.data || {},
    };

    // Send to each token and remove invalid tokens
    const sendPromises = fcmTokens.map((token) =>
      admin
        .messaging()
        .send({ ...message, token })
        .then((messageId) => {
          console.log(`Push sent to ${clientId} token ${token}: ${messageId}`);
          return messageId;
        })
        .catch((err) => {
          console.error(`Error sending to token ${token}:`, err.message || err);
          if (
            err.code === 'messaging/invalid-registration-token' ||
            err.code === 'messaging/registration-token-not-registered'
          ) {
            return db.collection('users').doc(clientId).update({
              fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
            });
          }
          return null;
        })
    );

    await Promise.all(sendPromises);
  } catch (e) {
    console.error(' Error creating notification/push:', e);
  }
}

/**
 * Scheduled Cloud Function to mark expired bids
 * Runs daily at 2 AM UTC
 */
exports.markExpiredBidsDaily = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log(' Starting daily bid expiration check...');
    return markExpiredBidsTask();
  });

/**
 * Scheduled Cloud Function to mark expired bids
 * Runs every 6 hours for faster cleanup
 */
exports.markExpiredBidsEvery6Hours = functions.pubsub
  .schedule('0 */6 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('🔄 Starting 6-hourly bid expiration check...');
    return markExpiredBidsTask();
  });

/**
 * On-demand HTTP endpoint to manually trigger bid expiration
 * Can be called by admin dashboard
 */
exports.manuallyMarkExpiredBids = functions.https.onRequest(
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
      console.error(' Error marking expired bids:', error);
      res.status(500).json({ error: error.toString() });
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
    console.log(` Found ${jobsSnapshot.size} jobs to check`);

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

            // Notify the client who created the bid
            try {
              const bidData = bidDoc.data();
              const clientId = bidData.clientId || jobDoc.data().clientId;
              const caregiverName = bidData.caregiverName || bidData.caregiverId || 'A caregiver';
              const bidAmount = bidData.amount || bidData.bidAmount || 0;

              if (clientId) {
                const message = `${caregiverName}'s bid of KES ${bidAmount} on job "${jobDoc.data().title || jobId}" has expired.`;

                // Create in-app notification + push
                await createNotificationAndPush(clientId, {
                  type: 'bid_expired',
                  jobId,
                  bidId: bidDoc.id,
                  title: 'Bid Expired',
                  message,
                  data: { jobId, bidId: bidDoc.id, type: 'bid_expired' },
                });

                // Email sending removed; in-app notification + push delivered
                console.log('Email send skipped: using in-app notification + push only');
              }
            } catch (notifyErr) {
              console.error('❌ Error notifying client about expired bid:', notifyErr);
            }
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

// Firestore trigger: when a new bid document is created, notify the job owner (client)
exports.onNewBid = functions.firestore.document('jobs/{jobId}/bids/{bidId}').onCreate(async (snap, ctx) => {
  const bid = snap.data();
  const { jobId, bidId } = ctx.params;

  try {
    const jobDoc = await db.collection('jobs').doc(jobId).get();
    if (!jobDoc.exists) {
      console.log(`Job ${jobId} not found for new bid notification`);
      return null;
    }

    const clientId = jobDoc.data().clientId;
    if (!clientId) {
      console.log(`Job ${jobId} has no clientId`);
      return null;
    }

    const caregiverName = bid.caregiverName || bid.caregiverId || 'A caregiver';
    const bidAmount = bid.amount || bid.bidAmount || 0;
    const message = `${caregiverName} placed a bid of KES ${bidAmount} on your job "${jobDoc.data().title || jobId}".`;

    await createNotificationAndPush(clientId, {
      type: 'new_bid',
      jobId,
      bidId,
      title: 'New Bid Received',
      message,
      data: { jobId, bidId, type: 'new_bid' },
    });

    // Email sending removed; in-app notification + push delivered
    console.log('Email send skipped for new-bid: using in-app notification + push only');

    return null;
  } catch (e) {
    console.error(' Error in onNewBid notification:', e);
    return null;
  }
});

/**
 * Callable Cloud Function for client-side expiration check
 * Can be called from Dart app for real-time validation
 */
exports.checkBidExpiration = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { jobId, caregiverId } = data;

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
      console.error(' Error checking bid expiration:', error);
      throw new functions.https.HttpsError('internal', error.toString());
    }
  }
);
