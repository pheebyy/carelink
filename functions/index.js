const functions = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
require("dotenv").config(); //loads dotenv variables

admin.initializeApp();
const db = admin.firestore();
const ADMIN_BOOTSTRAP_TOKEN = defineSecret("ADMIN_BOOTSTRAP_TOKEN");

// Helper function to get Paystack secret
function getPaystackSecret() {
  const secret = process.env.PAYSTACK_SECRET_KEY || "";
  if (!secret) {
    console.error("❌ PAYSTACK_SECRET_KEY not found in environment. Available keys:", Object.keys(process.env).filter(k => k.includes("PAYSTACK") || k.includes("paystack")));
  }
  return secret;
}

// One-time bootstrap for the very first admin account.
// Requires ADMIN_BOOTSTRAP_TOKEN runtime env var and a matching token in request.data.
exports.bootstrapFirstAdmin = onCall({ secrets: [ADMIN_BOOTSTRAP_TOKEN] }, async (request) => {
  const configuredToken = ADMIN_BOOTSTRAP_TOKEN.value();
  if (!configuredToken) {
    throw new HttpsError(
      "failed-precondition",
      "ADMIN_BOOTSTRAP_TOKEN is not configured."
    );
  }

  const { uid, bootstrapToken } = request.data || {};
  if (!uid || !bootstrapToken) {
    throw new HttpsError(
      "invalid-argument",
      "uid and bootstrapToken are required."
    );
  }

  if (bootstrapToken !== configuredToken) {
    throw new HttpsError(
      "permission-denied",
      "Invalid bootstrap token."
    );
  }

  const existingAdmin = await db
    .collection("users")
    .where("role", "==", "admin")
    .limit(1)
    .get();

  if (!existingAdmin.empty) {
    throw new HttpsError(
      "failed-precondition",
      "An admin already exists. Use setAdminRole instead."
    );
  }

  await admin.auth().setCustomUserClaims(uid, { admin: true });

  await db.collection("users").doc(uid).set(
    {
      role: "admin",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { success: true, uid, admin: true };
});

// 🔐 Set or remove admin role using Firebase Auth custom claims.
// Only callers that already have admin claim can invoke this function.
exports.setAdminRole = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "permission-denied",
      "Authentication is required."
    );
  }

  const callerHasClaim = request.auth.token.admin === true;
  let callerHasRole = false;
  if (!callerHasClaim) {
    const callerDoc = await db.collection("users").doc(request.auth.uid).get();
    const callerData = callerDoc.data() || {};
    callerHasRole = (callerData.role || "").toLowerCase() === "admin";
  }

  if (!callerHasClaim && !callerHasRole) {
    throw new HttpsError(
      "permission-denied",
      "Only admins can set admin roles."
    );
  }

  const { uid, isAdmin } = request.data || {};
  if (!uid || typeof isAdmin !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      "uid and isAdmin(boolean) are required."
    );
  }

  await admin.auth().setCustomUserClaims(uid, { admin: isAdmin });

  await db.collection("users").doc(uid).set(
    {
      role: isAdmin ? "admin" : "user",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { success: true, uid, admin: isAdmin };
});

// 🔹 Initialize Paystack Transaction
exports.initializeTransaction = onCall(async (request) => {
  console.log("🔹 initializeTransaction called with:", {
    email: request.data.email,
    amount: request.data.amount,
    reference: request.data.reference,
  });

  const { email, amount, reference, channels, metadata } = request.data;

  if (!email || !amount || !reference) {
    throw new HttpsError(
      "invalid-argument",
      "Missing required parameters: email, amount, or reference."
    );
  }

  try {
    const paystackSecret = getPaystackSecret();
    if (!paystackSecret) {
      console.error("❌ PAYSTACK_SECRET_KEY is missing!");
      throw new HttpsError("failed-precondition", "PAYSTACK_SECRET_KEY is not configured.");
    }

    console.log("✅ Secret found. Calling Paystack API...");

    const url = "https://api.paystack.co/transaction/initialize";
    const headers = {
      Authorization: `Bearer ${paystackSecret}`,
      "Content-Type": "application/json",
    };

    const payload = {
      email,
      amount: amount, // Already in kobo from Flutter (amount * 100)
      reference,
      currency: "KES",
      channels: channels || ["card", "mobile_money"],
      metadata: metadata || {},
    };

    const response = await axios.post(url, payload, { headers });
    
    console.log("✅ Paystack API response:", { status: response.data.status, accessCode: response.data.data?.access_code });
    
    return {
      status: true,
      message: "Transaction initialized successfully",
      data: response.data.data,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error("❌ Error initializing transaction:", {
      status: error.response?.status,
      message: error.response?.data?.message || error.message,
      data: error.response?.data,
    });
    throw new HttpsError(
      "internal",
      error.response?.data?.message || "Failed to initialize transaction"
    );
  }
});

// 🔹 Verify Paystack Transaction
async function verifyPaystackPayment(reference, paystackSecret) {
  const url = `https://api.paystack.co/transaction/verify/${reference}`;
  const headers = {
    Authorization: `Bearer ${paystackSecret}`,
  };

  const response = await axios.get(url, { headers });
  return response.data;
}

// 🔹 Main Firebase Function
exports.verifyTransaction = onCall(async (request) => {
  const { reference, userId, role } = request.data;

  if (!reference || !userId) {
    throw new HttpsError(
      "invalid-argument",
      "Missing reference or userId."
    );
  }

  try {
    const paystackSecret = getPaystackSecret();
    if (!paystackSecret) {
      throw new HttpsError("failed-precondition", "PAYSTACK_SECRET_KEY is not configured.");
    }

    const verification = await verifyPaystackPayment(reference, paystackSecret);
    const status = verification.data.status;

    if (status !== "success") {
      throw new Error("Transaction not successful.");
    }

    // Amount from Paystack is in lowest unit (KES * 100)
    const amountCents = verification.data.amount;
    const amountKES = amountCents / 100;
    const paymentMetadata = verification.data.metadata || {};
    const paymentType = paymentMetadata.type || "client_payment";

    // Prefer metadata values emitted by the app to avoid fee-model drift.
    const baseAmountKES = Number(paymentMetadata.base_amount || amountKES);
    const finalAmountKES = Number(paymentMetadata.final_amount || amountKES);

    // Carelink Commission Model
    const caregiverCommission =
      paymentType === "caregiver_commission" ? finalAmountKES : 0;
    const clientFee = Math.max(0, finalAmountKES - baseAmountKES);
    const totalRevenue = caregiverCommission + clientFee;

    const normalizedUserId = userId && userId !== "unknown" ? userId : null;
    const normalizedRole = role && role !== "unknown" ? role : null;

    // Get existing transaction to find caregiverId and earnings
    const existingTx = await db.collection("transactions").doc(reference).get();
    const txData = existingTx.data() || {};
    const caregiverId = txData.caregiverId;
    const caregiverEarnings = txData.caregiverEarnings || baseAmountKES;

    // Save verification details without overwriting existing transaction fields.
    await db.collection("transactions").doc(reference).set(
      {
        ...(normalizedUserId ? { userId: normalizedUserId } : {}),
        ...(normalizedRole ? { role: normalizedRole } : {}),
        reference,
        amountKES,
        baseAmountKES,
        finalAmountKES,
        caregiverCommission,
        clientFee,
        totalRevenue,
        status: "completed", // Mark as completed after verification
        paymentType,
        paystackData: verification.data,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Credit caregiver wallet
    if (caregiverId) {
      const walletRef = db.collection("caregiver_wallets").doc(caregiverId);
      const walletDoc = await walletRef.get();
      
      if (walletDoc.exists) {
        // Update existing wallet
        await walletRef.update({
          balance: admin.firestore.FieldValue.increment(caregiverEarnings),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // Create new wallet
        await walletRef.set({
          caregiverId,
          balance: caregiverEarnings,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      console.log(`✅ Credited wallet for ${caregiverId}: KES ${caregiverEarnings}`);
    }

    // Premium Activation (KES 300)
    if (role === "caregiver" && amountKES >= 300) {
      await db.collection("users").doc(userId).update({
        isPremium: true,
        premiumSince: admin.firestore.FieldValue.serverTimestamp(),
        premiumExpiry: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        ),
      });
    }

    return {
      verified: true,
      status: "verified",
      success: true,
      message: "Transaction verified successfully.",
      amount: amountKES,
      reference: reference,
      data: {
        amountKES,
        baseAmountKES,
        finalAmountKES,
        caregiverCommission,
        clientFee,
        totalRevenue,
        premiumActivated: role === "caregiver" && amountKES >= 300,
      },
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error(" Verification error:", error.message);
    throw new HttpsError(
      "internal",
      "Payment verification failed."
    );
  }
});

// 🔹 Log payment failures for support and retry diagnostics
exports.logPaymentFailure = onCall(async (request) => {
  const { reference, reason, timestamp } = request.data || {};

  if (!reference || !reason) {
    throw new HttpsError(
      "invalid-argument",
      "Missing reference or reason."
    );
  }

  try {
    await db.collection("payment_failures").add({
      reference,
      reason,
      timestamp: timestamp || new Date().toISOString(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error("Error logging payment failure:", error.message);
    throw new HttpsError(
      "internal",
      "Failed to log payment failure."
    );
  }
});

// ==========================================
// 💰 WITHDRAWAL PROCESSING
// ==========================================

// 🏦 Process caregiver withdrawal with M-Pesa or bank transfer
exports.processWithdrawal = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("permission-denied", "Authentication required.");
  }

  const { caregiverId, amount, bank, accountName, accountNumber, phoneNumber } = request.data || {};

  if (!caregiverId || !amount || !bank) {
    throw new HttpsError(
      "invalid-argument",
      "Missing caregiverId, amount, or bank."
    );
  }

  if (amount < 100) {
    throw new HttpsError("invalid-argument", "Minimum withdrawal is KES 100.");
  }

  try {
    const walletRef = db.collection("caregiver_wallets").doc(caregiverId);
    const walletDoc = await walletRef.get();

    if (!walletDoc.exists) {
      throw new HttpsError("not-found", "Wallet not found.");
    }

    const wallet = walletDoc.data();
    if (wallet.balance < amount) {
      throw new HttpsError("failed-precondition", "Insufficient balance.");
    }

    // Create withdrawal record
    const withdrawalRef = db.collection("withdrawals").doc();
    const withdrawalId = withdrawalRef.id;

    await withdrawalRef.set({
      caregiverId,
      amount,
      bank,
      accountName,
      accountNumber,
      phoneNumber,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: null,
      completedAt: null,
      failureReason: null,
    });

    // Deduct from wallet
    await walletRef.update({
      balance: admin.firestore.FieldValue.increment(-amount),
      totalWithdrawn: admin.firestore.FieldValue.increment(amount),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Withdrawal created: ${withdrawalId} for ${amount} KES`);

    return {
      success: true,
      withdrawalId,
      status: "pending",
      message: "Withdrawal request submitted. Processing usually takes 1-24 hours.",
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error("Withdrawal processing error:", error.message);
    throw new HttpsError("internal", "Failed to process withdrawal.");
  }
});

// ==========================================
// 🔄 REFUND PROCESSING
// ==========================================

// 💸 Refund a failed or disputed transaction via Paystack
exports.initiateRefund = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("permission-denied", "Authentication required.");
  }

  const { reference, reason } = request.data || {};

  if (!reference || !reason) {
    throw new HttpsError("invalid-argument", "Missing reference or reason.");
  }

  try {
    const paystackSecret = getPaystackSecret();
    if (!paystackSecret) {
      throw new HttpsError("failed-precondition", "PAYSTACK_SECRET_KEY not configured.");
    }

    // Get transaction
    const transactionDoc = await db.collection("transactions").doc(reference).get();
    if (!transactionDoc.exists) {
      throw new HttpsError("not-found", "Transaction not found.");
    }

    const transaction = transactionDoc.data();
    if (transaction.status === "refunded") {
      throw new HttpsError("failed-precondition", "Transaction already refunded.");
    }

    // Call Paystack refund API
    const url = "https://api.paystack.co/refund";
    const headers = {
      Authorization: `Bearer ${paystackSecret}`,
      "Content-Type": "application/json",
    };

    const payload = {
      transaction: reference,
      amount: Math.round(transaction.finalAmountKES * 100), // in kobo
    };

    const response = await axios.post(url, payload, { headers });
    const refundData = response.data.data;

    // Update transaction with refund info
    await db.collection("transactions").doc(reference).update({
      status: "refunded",
      refundReference: refundData.reference,
      refundReason: reason,
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
      paystackRefundData: refundData,
    });

    console.log(`✅ Refund initiated for ${reference}`);

    return {
      success: true,
      refundReference: refundData.reference,
      status: "refunded",
      amount: transaction.finalAmountKES,
      message: "Refund processed. Amount will be credited within 5-7 business days.",
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error("Refund error:", error.response?.data || error.message);
    throw new HttpsError(
      "internal",
      error.response?.data?.message || "Failed to process refund."
    );
  }
});

// Get withdrawal history for a caregiver
exports.getWithdrawalHistory = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("permission-denied", "Authentication required.");
  }

  const { caregiverId, limit = 20 } = request.data || {};

  if (!caregiverId) {
    throw new HttpsError("invalid-argument", "caregiverId is required.");
  }

  try {
    const snapshot = await db
      .collection("withdrawals")
      .where("caregiverId", "==", caregiverId)
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    const withdrawals = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return { success: true, withdrawals };
  } catch (error) {
    console.error("Error fetching withdrawal history:", error.message);
    throw new HttpsError("internal", "Failed to fetch withdrawal history.");
  }
});

// ==========================================
// 📧 EMAIL NOTIFICATIONS
// ==========================================

// Helper: Send email via SendGrid (add SendGrid API key to .env)
async function sendEmail(to, subject, htmlContent) {
  try {
    const sendgridApiKey = process.env.SENDGRID_API_KEY;
    if (!sendgridApiKey) {
      console.log("⚠️  SendGrid not configured, skipping email:", subject);
      return { success: false, reason: "sendgrid_not_configured" };
    }

    const url = "https://api.sendgrid.com/v3/mail/send";
    const headers = {
      Authorization: `Bearer ${sendgridApiKey}`,
      "Content-Type": "application/json",
    };

    const payload = {
      personalizations: [{ to: [{ email: to }] }],
      from: { email: "noreply@carelink.app", name: "CareLink" },
      subject,
      content: [{ type: "text/html", value: htmlContent }],
    };

    const response = await axios.post(url, payload, { headers });
    console.log(`✅ Email sent to ${to}: ${subject}`);
    return { success: true, messageId: response.headers["x-message-id"] };
  } catch (error) {
    console.error(`❌ Email error to ${to}:`, error.message);
    return { success: false, error: error.message };
  }
}

// 🎯 Send payment receipt email when transaction status is marked "completed"
exports.sendPaymentReceiptEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("permission-denied", "Authentication required.");
  }

  const { reference, clientEmail, amount, caregiverName } = request.data || {};

  if (!reference || !clientEmail || !amount) {
    throw new HttpsError("invalid-argument", "Missing reference, clientEmail, or amount.");
  }

  try {
    const htmlContent = `
      <h2>Payment Confirmation</h2>
      <p>Hello,</p>
      <p>Your payment of <strong>KES ${amount}</strong> to <strong>${caregiverName || "your caregiver"}</strong> has been successfully processed.</p>
      <p><strong>Reference:</strong> ${reference}</p>
      <p><strong>Date:</strong> ${new Date().toLocaleString()}</p>
      <p>Thank you for using CareLink!</p>
    `;

    const result = await sendEmail(clientEmail, "CareLink - Payment Receipt", htmlContent);
    return { success: result.success };
  } catch (error) {
    console.error("Error sending receipt email:", error.message);
    throw new HttpsError("internal", "Failed to send receipt email.");
  }
});

// 🤝 Send withdrawal status notification email
exports.sendWithdrawalStatusEmail = onCall(async (request) => {
  const { caregiverId, withdrawalId, status, amount, reason } = request.data || {};

  if (!caregiverId || !withdrawalId || !status) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  try {
    // Get caregiver email
    const userDoc = await db.collection("users").doc(caregiverId).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found.");
    }

    const email = userDoc.data().email;
    let subject = "";
    let statusMessage = "";

    if (status === "completed") {
      subject = "CareLink - Withdrawal Approved";
      statusMessage = `Your withdrawal of <strong>KES ${amount}</strong> has been <strong style="color: green;">approved</strong> and will be processed within 1-2 business days.`;
    } else if (status === "rejected") {
      subject = "CareLink - Withdrawal Rejected";
      statusMessage = `Your withdrawal request of KES ${amount} has been <strong style="color: red;">rejected</strong>. Reason: ${reason || "Unspecified"}. Please contact support for more information.`;
    } else if (status === "pending") {
      subject = "CareLink - Withdrawal Request Received";
      statusMessage = `Your withdrawal request of <strong>KES ${amount}</strong> has been received and is <strong style="color: blue;">pending</strong> approval. Processing usually takes 1-24 hours.`;
    }

    const htmlContent = `
      <h2>Withdrawal Status Update</h2>
      <p>Hello,</p>
      <p>${statusMessage}</p>
      <p><strong>Reference:</strong> ${withdrawalId}</p>
      <p>If you have any questions, please contact our support team.</p>
      <p>Best regards,<br>CareLink Team</p>
    `;

    const result = await sendEmail(email, subject, htmlContent);
    return { success: result.success };
  } catch (error) {
    console.error("Error sending withdrawal email:", error.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to send withdrawal email.");
  }
});

// 💰 Send refund confirmation email
exports.sendRefundConfirmationEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("permission-denied", "Authentication required.");
  }

  const { reference, clientEmail, amount, reason } = request.data || {};

  if (!reference || !clientEmail || !amount) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  try {
    const htmlContent = `
      <h2>Refund Initiated</h2>
      <p>Hello,</p>
      <p>Your refund request has been processed successfully.</p>
      <p><strong>Amount:</strong> KES ${amount}</p>
      <p><strong>Reason:</strong> ${reason}</p>
      <p><strong>Reference:</strong> ${reference}</p>
      <p><strong style="color: #ff6b00;">⏱️ Processing Time:</strong> 5-7 business days</p>
      <p>The refund will be credited back to your original payment method. Thank you for using CareLink.</p>
    `;

    const result = await sendEmail(clientEmail, "CareLink - Refund Processed", htmlContent);
    return { success: result.success };
  } catch (error) {
    console.error("Error sending refund email:", error.message);
    throw new HttpsError("internal", "Failed to send refund email.");
  }
});

// ==========================================
// 📋 AUDIT LOGGING TRIGGER
// ==========================================

// 🔔 Log transaction changes for audit trail
exports.onTransactionUpdated = onDocumentCreated(
  "transactions/{transactionId}",
  async (event) => {
    const { transactionId } = event.params;
    const transaction = event.data?.data();

    if (!transaction) return;

    try {
      // Log transaction creation
      await db.collection("audit_logs").add({
        userId: transaction.clientId || "system",
        eventType: "transaction",
        resource: "transaction",
        resourceId: transactionId,
        action: "created",
        changes: {
          status: transaction.status,
          amount: transaction.amount,
          reference: transaction.reference,
        },
        details: `Transaction created for KES ${transaction.amount}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Audit log created for transaction: ${transactionId}`);
    } catch (error) {
      console.error("Error logging transaction audit:", error.message);
    }
  }
);

// 🔔 Send push notification when a new message is created
exports.onNewMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }
    
    const { conversationId, messageId } = event.params;
    const messageData = snapshot.data();
    const senderId = messageData.senderId;
    const messageText = messageData.text || "";

    try {
      // Get conversation participants
      const conversationDoc = await db
        .collection("conversations")
        .doc(conversationId)
        .get();

      if (!conversationDoc.exists) {
        console.log("Conversation not found");
        return null;
      }

      const participantIds = conversationDoc.data().participantIds || [];
      const recipientIds = participantIds.filter((id) => id !== senderId);
      const notificationLogs = [];

      if (recipientIds.length === 0) {
        console.log("No recipients found");
        return null;
      }

      // Get sender info
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderName =
        senderDoc.exists
          ? senderDoc.data().displayName || senderDoc.data().name || "Someone"
          : "Someone";

      // Send notification to each recipient
      const notificationPromises = recipientIds.map(async (recipientId) => {
        const userDoc = await db.collection("users").doc(recipientId).get();
        if (!userDoc.exists) {
          notificationLogs.push({
            recipientId,
            status: "skipped",
            reason: "recipient_not_found",
          });
          return null;
        }

        const userData = userDoc.data();
        const fcmTokens = userData.fcmTokens || [];

        if (fcmTokens.length === 0) {
          console.log(`No FCM tokens for user ${recipientId}`);
          notificationLogs.push({
            recipientId,
            status: "skipped",
            reason: "no_tokens",
          });
          return null;
        }

        // Prepare notification payload
        const payload = {
          notification: {
            title: senderName,
            body: messageText.substring(0, 100), // Truncate long messages
          },
          data: {
            type: "chat_message",
            conversationId,
            messageId,
            senderId,
          },
        };

        // Send to all tokens
        const sendPromises = fcmTokens.map((token) =>
          admin
            .messaging()
            .send({
              ...payload,
              token,
            })
            .then((messageId) => {
              notificationLogs.push({
                recipientId,
                token,
                status: "sent",
                messageId,
              });
              return messageId;
            })
            .catch((err) => {
              console.error(
                `Error sending to token ${token}:`,
                err.message
              );
              notificationLogs.push({
                recipientId,
                token,
                status: "failed",
                errorCode: err.code || "unknown",
                errorMessage: err.message || "Unknown error",
              });
              // Remove invalid tokens
              if (
                err.code === "messaging/invalid-registration-token" ||
                err.code === "messaging/registration-token-not-registered"
              ) {
                return db
                  .collection("users")
                  .doc(recipientId)
                  .update({
                    fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
                  });
              }
              return null;
            })
        );

        return Promise.all(sendPromises);
      });

      await Promise.all(notificationPromises);

      await db.collection("notification_logs").add({
        type: "chat_message",
        conversationId,
        messageId,
        senderId,
        recipientIds,
        attempts: notificationLogs,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(" Push notifications sent successfully");
      return null;
    } catch (error) {
      console.error(" Error sending push notification:", error);
      return null;
    }
  }
);
