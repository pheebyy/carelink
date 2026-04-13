// ==========================================
// 💰 AUTOMATED PAYOUT SYSTEM (Phase 1)
// ==========================================

/**
 * PAYOUT BATCH GENERATION - Runs daily at 6 AM UTC
 * 
 * This function:
 * 1. Collects all completed transactions since last payout
 * 2. Groups by caregiver
 * 3. Calculates net amount (earnings - withholding tax if applicable)
 * 4. Creates payout batch document
 * 5. Creates individual payout records
 * 6. Set nextPayoutDate on wallets
 * 7. Sends notifications
 */

const functions = require("firebase-functions/v2");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const db = admin.firestore();

// 🔄 Generate payout batch (scheduled daily at 6 AM UTC)
exports.generatePayoutBatch = onSchedule(
  {
    schedule: "0 6 * * *", // 6 AM UTC every day
    timeZone: "UTC",
    retryCount: 2,
    maxInstances: 1, // Prevent concurrent batches
  },
  async (context) => {
    console.log("🔄 Starting automated payout batch generation...");
    
    try {
      const now = new Date();
      const batchId = `batch_${now.toISOString().split("T")[0]}_${Date.now()}`;
      const batchRef = db.collection("payoutBatches").doc(batchId);

      // 1. Get all caregivers with completed transactions
      const transactionsSnapshot = await db
        .collection("transactions")
        .where("status", "==", "completed")
        .where("paidOut", "==", false) // Not yet paid out
        .get();

      if (transactionsSnapshot.empty) {
        console.log("ℹ️  No transactions to process");
        return { success: true, message: "No transactions to payout", processed: 0 };
      }

      // 2. Group by caregiver
      const caregiverEarnings = {};
      transactionsSnapshot.forEach((doc) => {
        const tx = doc.data();
        const caregiverId = tx.caregiverId;
        
        if (!caregiverId) return; // Skip if no caregiver
        
        if (!caregiverEarnings[caregiverId]) {
          caregiverEarnings[caregiverId] = {
            total: 0,
            count: 0,
            transactions: [],
          };
        }
        
        caregiverEarnings[caregiverId].total += tx.caregiverEarnings || 0;
        caregiverEarnings[caregiverId].count += 1;
        caregiverEarnings[caregiverId].transactions.push(doc.id);
      });

      // 3. Create payout records
      const payouts = [];
      const updates = [];

      for (const [caregiverId, earning] of Object.entries(caregiverEarnings)) {
        const grossAmount = earning.total;
        const withholdingTax = 0; // TODO: Calculate based on jurisdiction
        const netAmount = grossAmount - withholdingTax;

        const payout = {
          caregiverId,
          batchId,
          grossAmount,
          withholdingTax,
          netAmount,
          transactionCount: earning.count,
          transactionIds: earning.transactions,
          status: "pending", // pending → processing → completed
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          processedAt: null,
          completedAt: null,
          failureReason: null,
          reference: null, // M-Pesa/bank ref when disbursed
        };

        payouts.push(payout);

        // Mark transactions as paid out
        updates.push({
          transactionIds: earning.transactions,
          data: { paidOut: true, paidOutBatchId: batchId },
        });
      }

      // 4. Create batch document
      await batchRef.set({
        batchId,
        totalPayouts: payouts.length,
        totalAmount: payouts.reduce((sum, p) => sum + p.netAmount, 0),
        status: "pending", // pending → processing → completed
        payoutCycle: "daily", // daily, weekly, etc
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: null,
        completedAt: null,
        payoutMethod: "mpesa", // mpesa, bank_transfer
      });

      // 5. Create individual payout records
      const payoutSubcollection = batchRef.collection("payouts");
      for (const payout of payouts) {
        await payoutSubcollection.add(payout);
      }

      // 6. Mark transactions as paid out and set next payout date
      const batch = db.batch();
      for (const update of updates) {
        for (const txId of update.transactionIds) {
          batch.update(db.collection("transactions").doc(txId), update.data);
        }
      }

      // Set nextPayoutDate for affected caregivers (7 days from now)
      const nextPayoutDate = new Date();
      nextPayoutDate.setDate(nextPayoutDate.getDate() + 7);
      
      for (const caregiverId of Object.keys(caregiverEarnings)) {
        batch.update(
          db.collection("caregiver_wallets").doc(caregiverId),
          { nextPayoutDate: nextPayoutDate }
        );
      }

      await batch.commit();

      // 7. Send notifications to affected caregivers
      for (const payout of payouts) {
        await notifyPayoutInitiated(
          payout.caregiverId,
          payout.netAmount,
          batchId
        );
      }

      console.log(`✅ Payout batch generated: ${batchId}`);
      console.log(`   - Caregivers: ${payouts.length}`);
      console.log(`   - Total amount: KES ${payouts.reduce((sum, p) => sum + p.netAmount, 0)}`);

      return {
        success: true,
        batchId,
        caregivers: payouts.length,
        totalAmount: payouts.reduce((sum, p) => sum + p.netAmount, 0),
      };
    } catch (error) {
      console.error("❌ Error generating payout batch:", error);
      
      // Log to Firestore for debugging
      await db.collection("system_errors").add({
        function: "generatePayoutBatch",
        error: error.message,
        stack: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      throw error;
    }
  }
);

/**
 * ON-CALL: Get payout batch details (Admin API)
 */
exports.getPayoutBatchDetails = functions.https.onCall(
  async (request) => {
    // Verify admin
    if (!request.auth || !request.auth.token.admin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can view payouts"
      );
    }

    const { batchId } = request.data;
    if (!batchId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "batchId required"
      );
    }

    try {
      const batchDoc = await db.collection("payoutBatches").doc(batchId).get();
      if (!batchDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Batch not found");
      }

      const payoutsSnapshot = await db
        .collection("payoutBatches")
        .doc(batchId)
        .collection("payouts")
        .get();

      const payouts = payoutsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate?.() || doc.data().createdAt,
      }));

      return {
        batch: {
          id: batchDoc.id,
          ...batchDoc.data(),
          createdAt: batchDoc.data().createdAt?.toDate?.() || batchDoc.data().createdAt,
        },
        payouts,
      };
    } catch (error) {
      console.error("Error fetching batch details:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to fetch batch details"
      );
    }
  }
);

/**
 * ON-CALL: Manually approve a payout batch (Admin)
 * Transition: pending → processing
 */
exports.approvPayoutBatch = functions.https.onCall(
  async (request) => {
    if (!request.auth || !request.auth.token.admin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin only"
      );
    }

    const { batchId } = request.data;
    if (!batchId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "batchId required"
      );
    }

    try {
      const batchRef = db.collection("payoutBatches").doc(batchId);
      const batchDoc = await batchRef.get();

      if (!batchDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Batch not found");
      }

      if (batchDoc.data().status !== "pending") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          `Cannot approve batch in ${batchDoc.data().status} status`
        );
      }

      // Update batch status
      await batchRef.update({
        status: "processing",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update all payouts in batch
      const payoutsSnapshot = await batchRef.collection("payouts").get();
      const batch = db.batch();

      payoutsSnapshot.forEach((doc) => {
        batch.update(doc.ref, {
          status: "processing",
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();

      console.log(`✅ Payout batch approved: ${batchId}`);

      return { success: true, message: "Payout batch approved" };
    } catch (error) {
      console.error("Error approving batch:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to approve batch"
      );
    }
  }
);

/**
 * ON-CALL: Complete payout (after M-Pesa/bank transfer succeeds)
 */
exports.completePayout = functions.https.onCall(
  async (request) => {
    if (!request.auth || !request.auth.token.admin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin only"
      );
    }

    const { payoutId, batchId, reference, method } = request.data;
    if (!payoutId || !batchId || !reference) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields"
      );
    }

    try {
      const payoutRef = db
        .collection("payoutBatches")
        .doc(batchId)
        .collection("payouts")
        .doc(payoutId);

      const payoutDoc = await payoutRef.get();
      if (!payoutDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Payout not found");
      }

      const payout = payoutDoc.data();

      // Update payout
      await payoutRef.update({
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        reference,
        method: method || "mpesa",
      });

      // Notify caregiver
      await notifyPayoutCompleted(
        payout.caregiverId,
        payout.netAmount,
        reference
      );

      console.log(`✅ Payout completed: ${payoutId}`);

      return { success: true, message: "Payout marked as completed" };
    } catch (error) {
      console.error("Error completing payout:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to complete payout"
      );
    }
  }
);

/**
 * Helper: Send payout initiated notification
 */
async function notifyPayoutInitiated(caregiverId, amount, batchId) {
  try {
    const userDoc = await db.collection("users").doc(caregiverId).get();
    if (!userDoc.exists) return;

    const email = userDoc.data().email;
    const displayName = userDoc.data().displayName || "Caregiver";

    const htmlContent = `
      <h2>Payout Initiated 💰</h2>
      <p>Hello ${displayName},</p>
      <p>Your payout has been initiated and is being processed!</p>
      <p><strong>Amount:</strong> KES ${amount.toFixed(2)}</p>
      <p><strong>Batch ID:</strong> ${batchId}</p>
      <p><strong>Status:</strong> Processing</p>
      <p><strong>Expected Time:</strong> 1-2 business days via M-Pesa</p>
      <p>You'll receive a confirmation SMS when funds arrive.</p>
      <p>Best regards,<br>CareLink Team</p>
    `;

    // Send via SendGrid (optional - can be empty if not configured)
    try {
      const sendgridApiKey = process.env.SENDGRID_API_KEY;
      if (sendgridApiKey) {
        const response = await require("axios").post(
          "https://api.sendgrid.com/v3/mail/send",
          {
            personalizations: [{ to: [{ email }] }],
            from: { email: "noreply@carelink.app", name: "CareLink" },
            subject: "CareLink - Payout Initiated",
            content: [{ type: "text/html", value: htmlContent }],
          },
          {
            headers: {
              Authorization: `Bearer ${sendgridApiKey}`,
              "Content-Type": "application/json",
            },
          }
        );

        console.log(`✅ Notification sent to ${email}`);
      }
    } catch (emailError) {
      console.log(`⚠️  Email delivery skipped (SendGrid not configured)`);
    }
  } catch (error) {
    console.error("Error sending payout notification:", error.message);
    // Don't throw - notification failure shouldn't break payout
  }
}

/**
 * Helper: Send payout completed notification
 */
async function notifyPayoutCompleted(caregiverId, amount, reference) {
  try {
    const userDoc = await db.collection("users").doc(caregiverId).get();
    if (!userDoc.exists) return;

    const email = userDoc.data().email;
    const displayName = userDoc.data().displayName || "Caregiver";

    const htmlContent = `
      <h2>Payout Completed ✅</h2>
      <p>Hello ${displayName},</p>
      <p>Your payout has been successfully completed!</p>
      <p><strong>Amount:</strong> KES ${amount.toFixed(2)}</p>
      <p><strong>Reference:</strong> ${reference}</p>
      <p><strong>Received:</strong> ${new Date().toLocaleString()}</p>
      <p>You should see the funds in your M-Pesa account now.</p>
      <p>Thank you for your hard work on CareLink!</p>
      <p>Best regards,<br>CareLink Team</p>
    `;

    try {
      const sendgridApiKey = process.env.SENDGRID_API_KEY;
      if (sendgridApiKey) {
        await require("axios").post(
          "https://api.sendgrid.com/v3/mail/send",
          {
            personalizations: [{ to: [{ email }] }],
            from: { email: "noreply@carelink.app", name: "CareLink" },
            subject: "CareLink - Payout Completed ✅",
            content: [{ type: "text/html", value: htmlContent }],
          },
          {
            headers: {
              Authorization: `Bearer ${sendgridApiKey}`,
              "Content-Type": "application/json",
            },
          }
        );
      }
    } catch (emailError) {
      console.log("⚠️  Email delivery skipped");
    }
  } catch (error) {
    console.error("Error sending completion notification:", error.message);
  }
}

module.exports = {
  generatePayoutBatch: exports.generatePayoutBatch,
  getPayoutBatchDetails: exports.getPayoutBatchDetails,
  approvPayoutBatch: exports.approvPayoutBatch,
  completePayout: exports.completePayout,
};
