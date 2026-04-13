/**
 * Phase 2: Instant Cancellation Refunds
 * Processes instant refunds for jobs cancelled before start time
 * Integrates with Paystack API for real-time refund processing
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const axios = require("axios");

const db = admin.firestore();
const PAYSTACK_BASE_URL = "https://api.paystack.co";
const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;

// ==========================================
// 🔄 INSTANT REFUND WORKFLOW
// ==========================================

/**
 * Initiate instant refund when job cancelled before start
 * Called by mobile app or admin dashboard
 */
exports.initiateInstantRefund = onCall(async (request) => {
  const { jobId, reason, cancelledBy } = request.data;
  
  if (!jobId || !reason || !cancelledBy) {
    throw new HttpsError(
      "invalid-argument",
      "jobId, reason, and cancelledBy required"
    );
  }

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  try {
    // 1. Get the job
    const jobRef = db.collection("jobs").doc(jobId);
    const jobDoc = await jobRef.get();
    
    if (!jobDoc.exists) {
      throw new HttpsError("not-found", "Job not found");
    }

    const job = jobDoc.data();
    const currentTime = Date.now();
    const startTime = job.startDate ? job.startDate.toMillis() : null;

    // 2. Validate: Job can only be cancelled before start time
    if (startTime && currentTime > startTime) {
      throw new HttpsError(
        "failed-precondition",
        "Cannot refund: Job has already started"
      );
    }

    // 3. Check if job is in refundable status
    const refundableStatuses = ["open", "applied", "hired"];
    if (!refundableStatuses.includes(job.status)) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot refund job with status: ${job.status}`
      );
    }

    // 4. Get payment transaction
    const paymentRef = job.paymentReference;
    if (!paymentRef) {
      throw new HttpsError(
        "not-found",
        "No payment found for this job"
      );
    }

    const transactionDoc = await db.collection("transactions").doc(paymentRef).get();
    if (!transactionDoc.exists) {
      throw new HttpsError("not-found", "Payment transaction not found");
    }

    const transaction = transactionDoc.data();

    // 5. Check if already refunded
    if (transaction.status === "refunded") {
      throw new HttpsError(
        "failed-precondition",
        "This payment has already been refunded"
      );
    }

    // 6. Authorization check: Only client or admin can refund
    const isClient = request.auth.uid === job.clientId;
    const isAdmin = request.auth.token.admin;
    
    if (!isClient && !isAdmin) {
      throw new HttpsError(
        "permission-denied",
        "Only client or admin can refund this job"
      );
    }

    // 7. Create refund record
    const refundId = `refund_${jobId}_${Date.now()}`;
    const refundRef = db.collection("refunds").doc(refundId);

    await refundRef.set({
      refundId,
      jobId,
      transactionId: paymentRef,
      clientId: job.clientId,
      caregiverId: job.caregiverId || null,
      amount: transaction.amount,
      currency: "KES",
      reason,
      cancelledBy,
      status: "pending", // pending → processing → completed/failed
      paymentMethod: "paystack", // How original payment was made
      refundMethod: "paystack", // Where refund will go (original method)
      paystackReference: transaction.reference,
      refundReference: null, // Will be set after Paystack refund
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: null,
      completedAt: null,
      failureReason: null,
      attempts: 0,
      maxAttempts: 3,
    });

    // 8. Update job status to cancelled
    await jobRef.update({
      status: "canceled",
      canceledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelReason: reason,
      cancelledBy: cancelledBy,
    });

    // 9. Update transaction status
    await db.collection("transactions").doc(paymentRef).update({
      status: "refunding",
      refundId: refundId,
      refundInitiatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 10. Trigger actual refund processing (can be async)
    triggerPaystackRefund(refundId, transaction.reference, transaction.amount);

    console.log(`✅ Instant refund initiated: ${refundId}`);
    
    return {
      success: true,
      refundId,
      message: "Refund initiated",
      amount: transaction.amount,
      status: "pending",
    };
  } catch (error) {
    console.error("❌ Error initiating refund:", error);
    throw error;
  }
});

/**
 * Process actual Paystack refund (background function)
 * Calls Paystack API to process the refund
 */
async function triggerPaystackRefund(refundId, paystackReference, amount) {
  try {
    const refundRef = db.collection("refunds").doc(refundId);

    // Call Paystack refund API
    const response = await axios.post(
      `${PAYSTACK_BASE_URL}/refund`,
      {
        transaction: paystackReference,
        amount: Math.round(amount * 100), // Paystack uses kobo (cents)
      },
      {
        headers: {
          Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
          "Content-Type": "application/json",
        },
      }
    );

    if (!response.data.status) {
      throw new Error(response.data.message || "Paystack refund failed");
    }

    const refundData = response.data.data;

    // Update refund record with Paystack response
    await refundRef.update({
      status: "processing",
      refundReference: refundData.reference,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      paystackRefundId: refundData.id,
      attempts: admin.firestore.FieldValue.increment(1),
    });

    console.log(`✅ Paystack refund initiated: ${refundData.reference}`);

    // Send email to client
    await sendRefundEmail(refundId);

  } catch (error) {
    console.error("❌ Error processing Paystack refund:", error.message);

    // Update refund with failure info
    const refundRef = db.collection("refunds").doc(refundId);
    await refundRef.update({
      status: "failed",
      failureReason: error.message,
      attempts: admin.firestore.FieldValue.increment(1),
    });

    throw error;
  }
}

/**
 * Handle Paystack refund webhook
 * Updates refund status when Paystack processes it
 */
exports.handleRefundWebhook = onCall(async (request) => {
  const { event, data } = request.data;

  if (event !== "refund.failed" && event !== "refund.processed") {
    return { acknowledged: true };
  }

  try {
    const paystackRefundReference = data.reference;

    // Find refund by Paystack reference
    const refundSnapshot = await db
      .collection("refunds")
      .where("refundReference", "==", paystackRefundReference)
      .limit(1)
      .get();

    if (refundSnapshot.empty) {
      console.warn(`⚠️  Webhook: Refund not found for ${paystackRefundReference}`);
      return { acknowledged: true };
    }

    const refundDoc = refundSnapshot.docs[0];
    const refund = refundDoc.data();

    if (event === "refund.processed") {
      // Update refund to completed
      await refundDoc.ref.update({
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update transaction to refunded
      await db
        .collection("transactions")
        .doc(refund.transactionId)
        .update({
          status: "refunded",
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
          refundReference: paystackRefundReference,
        });

      console.log(`✅ Refund completed: ${refund.refundId}`);

      // Send completion email
      await sendRefundCompletionEmail(refund);

    } else if (event === "refund.failed") {
      // Update refund to failed
      await refundDoc.ref.update({
        status: "failed",
        failureReason: data.failureMessage || "Paystack refund failed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`❌ Refund failed: ${refund.refundId}`);
    }

    return { acknowledged: true };
  } catch (error) {
    console.error("❌ Error handling refund webhook:", error);
    throw new HttpsError("internal", "Failed to handle webhook");
  }
});

/**
 * Get refund details (Admin API)
 */
exports.getRefundDetails = onCall(async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Only admins can view refunds");
  }

  const { refundId } = request.data;
  if (!refundId) {
    throw new HttpsError("invalid-argument", "refundId required");
  }

  try {
    const refundDoc = await db.collection("refunds").doc(refundId).get();
    
    if (!refundDoc.exists) {
      throw new HttpsError("not-found", "Refund not found");
    }

    return {
      id: refundDoc.id,
      ...refundDoc.data(),
    };
  } catch (error) {
    console.error("Error fetching refund details:", error);
    throw new HttpsError("internal", "Failed to fetch refund details");
  }
});

/**
 * List all refunds with filters (Admin Dashboard)
 */
exports.listRefunds = onCall(async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Only admins can view refunds");
  }

  const { status, limit = 50, startAfter } = request.data;

  try {
    let query = db.collection("refunds").orderBy("createdAt", "desc");

    if (status) {
      query = query.where("status", "==", status);
    }

    if (startAfter) {
      query = query.startAfter(startAfter);
    }

    query = query.limit(limit + 1);

    const snapshot = await query.get();
    const refunds = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      refunds: refunds.slice(0, limit),
      hasMore: refunds.length > limit,
    };
  } catch (error) {
    console.error("Error listing refunds:", error);
    throw new HttpsError("internal", "Failed to list refunds");
  }
});

/**
 * Retry failed refund (Admin)
 */
exports.retryFailedRefund = onCall(async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Admin only");
  }

  const { refundId } = request.data;
  if (!refundId) {
    throw new HttpsError("invalid-argument", "refundId required");
  }

  try {
    const refundDoc = await db.collection("refunds").doc(refundId).get();
    
    if (!refundDoc.exists) {
      throw new HttpsError("not-found", "Refund not found");
    }

    const refund = refundDoc.data();

    // Check if max attempts exceeded
    if (refund.attempts >= refund.maxAttempts) {
      throw new HttpsError(
        "failed-precondition",
        `Max retry attempts (${refund.maxAttempts}) exceeded`
      );
    }

    // Retry Paystack refund
    await triggerPaystackRefund(
      refundId,
      refund.paystackReference,
      refund.amount
    );

    console.log(`🔄 Refund retry initiated: ${refundId}`);

    return {
      success: true,
      message: "Refund retry initiated",
    };
  } catch (error) {
    console.error("Error retrying refund:", error);
    throw new HttpsError("internal", "Failed to retry refund");
  }
});

/**
 * Manual refund (Admin override - for cases where Paystack fails)
 */
exports.manualRefundApproval = onCall(async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Admin only");
  }

  const { refundId, approvalNote } = request.data;
  if (!refundId) {
    throw new HttpsError("invalid-argument", "refundId required");
  }

  try {
    const refundRef = db.collection("refunds").doc(refundId);
    const refundDoc = await refundRef.get();
    
    if (!refundDoc.exists) {
      throw new HttpsError("not-found", "Refund not found");
    }

    // Mark as manually approved
    await refundRef.update({
      status: "completed",
      manuallyApprovedBy: request.auth.uid,
      approvalNote: approvalNote || "Manual admin approval",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update transaction
    const refund = refundDoc.data();
    await db
      .collection("transactions")
      .doc(refund.transactionId)
      .update({
        status: "refunded",
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        manualRefund: true,
      });

    console.log(`✅ Manual refund approved: ${refundId}`);

    return {
      success: true,
      message: "Refund manually approved",
    };
  } catch (error) {
    console.error("Error approving manual refund:", error);
    throw new HttpsError("internal", "Failed to approve refund");
  }
});

// ==========================================
// 📧 EMAIL NOTIFICATIONS
// ==========================================

/**
 * Send refund initiated email to client
 */
async function sendRefundEmail(refundId) {
  try {
    const refundDoc = await db.collection("refunds").doc(refundId).get();
    const refund = refundDoc.data();

    const clientDoc = await db.collection("users").doc(refund.clientId).get();
    const client = clientDoc.data();

    const jobDoc = await db.collection("jobs").doc(refund.jobId).get();
    const job = jobDoc.data();

    const emailContent = `
Dear ${client.fullName},

Your job cancellation refund has been initiated:

📋 Job Details:
- Job ID: ${job.id}
- Job Title: ${job.title}
- Amount: KES ${refund.amount.toLocaleString()}
- Reason: ${refund.reason}

💰 Refund Status: PROCESSING
Your refund is being processed and should arrive in your account within 1-2 business days.

Reference: ${refund.refundId}

If you have any questions, contact our support team.

Best regards,
CareLink Team
    `;

    // Fire email function (SendGrid)
    await functions.context.callFunction("sendEmail", {
      to: client.email,
      subject: "Refund Initiated - Job Cancellation",
      html: emailContent,
    });

    console.log(`📧 Refund email sent to ${client.email}`);
  } catch (error) {
    console.error("Error sending refund email:", error);
  }
}

/**
 * Send refund completion email to client
 */
async function sendRefundCompletionEmail(refund) {
  try {
    const clientDoc = await db.collection("users").doc(refund.clientId).get();
    const client = clientDoc.data();

    const emailContent = `
Dear ${client.fullName},

Your refund has been completed! 🎉

💰 Refund Details:
- Amount: KES ${refund.amount.toLocaleString()}
- Reference: ${refund.refundReference}
- Date: ${new Date().toLocaleDateString()}

The funds should now be visible in your original payment method.

Best regards,
CareLink Team
    `;

    // Fire email function
    await functions.context.callFunction("sendEmail", {
      to: client.email,
      subject: "Refund Completed - Funds Returned",
      html: emailContent,
    });

    console.log(`📧 Refund completion email sent to ${client.email}`);
  } catch (error) {
    console.error("Error sending refund completion email:", error);
  }
}

module.exports = {
  initiateInstantRefund: exports.initiateInstantRefund,
  handleRefundWebhook: exports.handleRefundWebhook,
  getRefundDetails: exports.getRefundDetails,
  listRefunds: exports.listRefunds,
  retryFailedRefund: exports.retryFailedRefund,
  manualRefundApproval: exports.manualRefundApproval,
};
