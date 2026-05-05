
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

// 🔐 Add a new admin by email.
// Only callers with a 'superadmin' role can invoke this.
exports.addAdminRole = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required."
    );
  }

  // Verify caller is a superadmin
  const callerDoc = await db.collection("admins").doc(request.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== 'superadmin') {
    throw new HttpsError(
      "permission-denied",
      "Only superadmins can add new admins."
    );
  }

  const { email, role } = request.data;
  if (!email || !role) {
    throw new HttpsError(
      "invalid-argument",
      "Email and role are required."
    );
  }

  try {
    // Get user by email
    const user = await admin.auth().getUserByEmail(email);

    // Set custom claims
    await admin.auth().setCustomUserClaims(user.uid, { admin: true, admin_role: role });

    // Create admin document in Firestore
    await db.collection("admins").doc(user.uid).set({
      email: user.email,
      role: role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error("Error adding admin role:", error);
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError("not-found", `User with email ${email} not found.`);
    }
    throw new HttpsError("internal", "An internal error occurred.");
  }
});

// � Migrate existing admin users to new claims structure
exports.migrateAdminClaims = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required."
    );
  }

  // Only allow superadmins to run migration
  const callerDoc = await db.collection("admins").doc(request.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== 'superadmin') {
    throw new HttpsError(
      "permission-denied",
      "Only superadmins can run migrations."
    );
  }

  try {
    // Get all admin documents
    const adminsSnapshot = await db.collection("admins").get();
    const migrationResults = [];

    for (const adminDoc of adminsSnapshot.docs) {
      const adminData = adminDoc.data();
      const uid = adminDoc.id;

      try {
        // Get current user
        const user = await admin.auth().getUser(uid);
        
        // Set proper claims
        await admin.auth().setCustomUserClaims(uid, { 
          admin: true, 
          admin_role: adminData.role || 'admin' 
        });

        migrationResults.push({
          uid,
          email: user.email,
          status: 'success',
          role: adminData.role
        });
      } catch (error) {
        migrationResults.push({
          uid,
          status: 'error',
          error: error.message
        });
      }
    }

    return { success: true, results: migrationResults };
  } catch (error) {
    console.error("Migration error:", error);
    throw new HttpsError("internal", "Migration failed: " + error.message);
  }
});

// �🔹 Initialize Paystack Transaction
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

// Notifications: create in-app notification and send push via FCM
async function createNotificationAndPush({ userId, email, payload }) {
  try {
    let targetUserId = userId;

    if (!targetUserId && email) {
      // Try to find user by email
      const userQuery = await db.collection('users').where('email', '==', email).limit(1).get();
      if (!userQuery.empty) {
        targetUserId = userQuery.docs[0].id;
      }
    }

    if (!targetUserId) {
      console.log('No target userId found for notification (email lookup failed)');
      return { success: false, reason: 'no_user' };
    }

    // Create in-app notification
    await db.collection('users').doc(targetUserId).collection('notifications').add({
      ...payload,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const userDoc = await db.collection('users').doc(targetUserId).get();
    const userData = userDoc.exists ? userDoc.data() || {} : {};
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.log(`No FCM tokens for user ${targetUserId}`);
      return { success: true, reason: 'no_tokens' };
    }

    const message = {
      notification: { title: payload.title || 'CareLink', body: payload.message || '' },
      data: payload.data || {},
    };

    const sendPromises = fcmTokens.map((token) =>
      admin
        .messaging()
        .send({ ...message, token })
        .then((messageId) => {
          console.log(`Push sent to ${targetUserId} token ${token}: ${messageId}`);
          return messageId;
        })
        .catch((err) => {
          console.error(`Error sending to token ${token}:`, err.message || err);
          if (
            err.code === 'messaging/invalid-registration-token' ||
            err.code === 'messaging/registration-token-not-registered'
          ) {
            return db.collection('users').doc(targetUserId).update({
              fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
            });
          }
          return null;
        })
    );

    await Promise.all(sendPromises);
    return { success: true };
  } catch (e) {
    console.error('Error creating notification/push:', e);
    return { success: false, error: e.toString() };
  }
}

// Backwards-compatible callable `sendEmail` endpoint (replaces SendGrid calls)
// Admin dashboard and other code may call this — we handle it by creating
// an in-app notification and sending push; emails are not sent.
exports.sendEmail = onCall(async (request) => {
  const { to, subject, html } = request.data || {};
  if (!to || !subject) {
    throw new HttpsError('invalid-argument', 'Missing to or subject');
  }

  // Simple strip of HTML tags for notification body
  const message = (html || '').replace(/<[^>]+>/g, '').trim().substring(0, 500);

  const result = await createNotificationAndPush({
    email: to,
    payload: {
      type: 'system_email_fallback',
      title: subject,
      message: message || subject,
      data: { source: 'sendEmail_callable' },
    },
  });

  if (!result.success) {
    console.log('sendEmail fallback: could not deliver notification for', to, result.reason || result.error);
  } else {
    console.log('sendEmail fallback: created in-app notification for', to);
  }

  return { success: true };
});

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

    // Create in-app notification + push for payment receipt (email disabled)
    await createNotificationAndPush({
      email: clientEmail,
      payload: {
        type: 'payment_receipt',
        title: 'Payment Confirmation',
        message: `Your payment of KES ${amount} to ${caregiverName || 'your caregiver'} has been processed. Reference: ${reference}`,
        data: { reference, amount: String(amount), type: 'payment_receipt' },
      },
    });

    return { success: true };
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

    // Notify caregiver via in-app notification + push
    await createNotificationAndPush({
      userId: caregiverId,
      payload: {
        type: 'withdrawal_status',
        title,
        message: statusMessage.replace(/<[^>]+>/g, ''),
        data: { withdrawalId, status, amount: String(amount) },
      },
    });

    return { success: true };
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

    // Notify client via in-app notification + push about refund
    await createNotificationAndPush({
      email: clientEmail,
      payload: {
        type: 'refund_processed',
        title: 'Refund Initiated',
        message: `Your refund of KES ${amount} has been initiated. Reference: ${reference}`,
        data: { reference, amount: String(amount), type: 'refund_processed' },
      },
    });

    return { success: true };
  } catch (error) {
    console.error("Error sending refund email:", error.message);
    throw new HttpsError("internal", "Failed to send refund email.");
  }
});

// ✅ Send caregiver verification submission confirmation email
exports.sendVerificationSubmissionEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("permission-denied", "Authentication required.");
  }

  const { caregiverId, caregiverName, caregiverEmail } = request.data || {};

  if (!caregiverId || !caregiverEmail) {
    throw new HttpsError("invalid-argument", "Missing caregiverId or caregiverEmail.");
  }

  try {
    const htmlContent = `
      <h2>Verification Documents Received ✅</h2>
      <p>Hello ${caregiverName || "Caregiver"},</p>
      <p>Thank you for submitting your verification documents! We have successfully received your submission.</p>
      
      <h3>What's Next?</h3>
      <p>Our admin team will review your documents and verify them against official records from:</p>
      <ul>
        <li>Kenyan Nursing Council (KNC) Registry</li>
        <li>National ID Database</li>
        <li>Passport Office</li>
      </ul>
      
      <p><strong>Expected Timeline:</strong> 24-48 hours</p>
      
      <h3>Your Submitted Documents</h3>
      <ul>
        <li>✓ Practice License</li>
        <li>✓ National ID</li>
        <li>✓ Passport Photo</li>
      </ul>
      
      <p>You can track your verification status in the CareLink app under <strong>Profile → Verification Status</strong>.</p>
      
      <p><strong>Important:</strong> Once your verification is approved, you'll receive an email notification and can immediately start bidding on jobs!</p>
      
      <p>If you have any questions, please contact our support team at support@carelink.app</p>
      
      <p>Best regards,<br><strong>CareLink Verification Team</strong></p>
    `;

    // Create in-app notification + push for verification submission
    await createNotificationAndPush({
      userId: caregiverId,
      payload: {
        type: 'verification_submission',
        title: 'Verification Documents Received',
        message: 'We have received your verification documents. Our team will review them within 24-48 hours.',
        data: { type: 'verification_submission' },
      },
    });

    console.log(`Notification created for verification submission to ${caregiverId}`);
    return { success: true };
  } catch (error) {
    console.error("Error sending verification submission email:", error.message);
    throw new HttpsError("internal", "Failed to send verification email.");
  }
});

// ✅ Send caregiver verification result email (approval or rejection)
exports.sendVerificationResultEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("permission-denied", "Authentication required.");
  }

  const { caregiverId, approved, reason } = request.data || {};

  if (!caregiverId || typeof approved !== "boolean") {
    throw new HttpsError("invalid-argument", "Missing caregiverId or approved status.");
  }

  try {
    // Get caregiver info
    const userDoc = await db.collection("users").doc(caregiverId).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found.");
    }

    const userData = userDoc.data();
    const caregiverEmail = userData.email;
    const caregiverName = userData.name || userData.displayName || "Caregiver";

    let subject = "";
    let htmlContent = "";

    if (approved) {
      subject = "CareLink - Verification Approved! 🎉";
      htmlContent = `
        <h2>Verification Approved! 🎉</h2>
        <p>Hello ${caregiverName},</p>
        <p>Great news! Your verification has been <strong style="color: green;">successfully approved</strong>!</p>
        
        <h3>You Can Now:</h3>
        <ul>
          <li>✅ Bid on available jobs</li>
          <li>✅ Build your reputation with clients</li>
          <li>✅ Earn money through CareLink</li>
          <li>✅ Access premium features (optional)</li>
        </ul>
        
        <h3>Next Steps:</h3>
        <ol>
          <li>Open the CareLink app</li>
          <li>Go to the <strong>Jobs</strong> tab to see available opportunities</li>
          <li>Browse and bid on jobs that match your skills</li>
          <li>Connect with clients and start earning!</li>
        </ol>
        
        <p><strong>Your verification status will display as "Approved" in your profile.</strong></p>
        
        <p>Welcome to the CareLink community! We're excited to have you on board.</p>
        
        <p>If you have any questions, contact support at support@carelink.app</p>
        
        <p>Best regards,<br><strong>CareLink Team</strong></p>
      `;
    } else {
      subject = "CareLink - Verification Status Update";
      htmlContent = `
        <h2>Verification Status Update</h2>
        <p>Hello ${caregiverName},</p>
        <p>Thank you for submitting your verification documents. Unfortunately, your verification was <strong style="color: #ff6b00;">not approved</strong> at this time.</p>
        
        <h3>Reason:</h3>
        <p>${reason || "Your documents did not meet our verification requirements."}</p>
        
        <h3>What You Can Do:</h3>
        <ul>
          <li>📸 Review the feedback provided</li>
          <li>📝 Prepare updated documents if needed</li>
          <li>🔄 Resubmit your verification documents</li>
          <li>📞 Contact support for clarification</li>
        </ul>
        
        <h3>How to Resubmit:</h3>
        <ol>
          <li>Open the CareLink app</li>
          <li>Go to <strong>Profile → Verification</strong></li>
          <li>Review the requirements</li>
          <li>Submit updated documents</li>
        </ol>
        
        <p><strong>Note:</strong> Please ensure all documents are clear, valid, and match exactly with your details.</p>
        
        <p>We're here to help! If you need clarification or have questions, please contact our support team at support@carelink.app</p>
        
        <p>Best regards,<br><strong>CareLink Verification Team</strong></p>
      `;
    }

    // Notify caregiver via in-app notification + push about verification result
    await createNotificationAndPush({
      userId: caregiverId,
      payload: {
        type: approved ? 'verification_approved' : 'verification_rejected',
        title: approved ? 'Verification Approved' : 'Verification Status Update',
        message: approved
          ? 'Your verification has been approved. You can now bid on jobs.'
          : `Your verification was not approved. Reason: ${reason || 'Unspecified'}`,
        data: { approved: String(approved), reason: reason || '' },
      },
    });

    console.log(`Notification created for verification result for ${caregiverId}`);
    return { success: true };
  } catch (error) {
    console.error("Error sending verification result email:", error.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to send verification result email.");
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

// ==========================================
// 💰 AUTOMATED PAYOUT SYSTEM (Phase 1)
// ==========================================

const { onSchedule } = require("firebase-functions/v2/scheduler");

/**
 * Generate payout batch (scheduled daily at 6 AM UTC)
 * Groups completed unpaid transactions by caregiver
 * Creates batch and individual payout records
 */
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
        .limit(1000) // Safety limit
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
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          processedAt: null,
          completedAt: null,
          failureReason: null,
          reference: null,
        };

        payouts.push(payout);
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
        status: "pending",
        payoutCycle: "daily",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: null,
        completedAt: null,
        payoutMethod: "mpesa",
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
      throw error;
    }
  }
);

// 📋 Get payout batch details (Admin API)
exports.getPayoutBatchDetails = onCall(async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError(
      "permission-denied",
      "Only admins can view payouts"
    );
  }

  const { batchId } = request.data;
  if (!batchId) {
    throw new HttpsError(
      "invalid-argument",
      "batchId required"
    );
  }

  try {
    const batchDoc = await db.collection("payoutBatches").doc(batchId).get();
    if (!batchDoc.exists) {
      throw new HttpsError("not-found", "Batch not found");
    }

    const payoutsSnapshot = await db
      .collection("payoutBatches")
      .doc(batchId)
      .collection("payouts")
      .get();

    const payouts = payoutsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      batch: {
        id: batchDoc.id,
        ...batchDoc.data(),
      },
      payouts,
    };
  } catch (error) {
    console.error("Error fetching batch details:", error);
    throw new HttpsError(
      "internal",
      "Failed to fetch batch details"
    );
  }
});

// ✅ Approve a payout batch (Admin)
exports.approvPayoutBatch = onCall(async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError(
      "permission-denied",
      "Admin only"
    );
  }

  const { batchId } = request.data;
  if (!batchId) {
    throw new HttpsError(
      "invalid-argument",
      "batchId required"
    );
  }

  try {
    const batchRef = db.collection("payoutBatches").doc(batchId);
    const batchDoc = await batchRef.get();

    if (!batchDoc.exists) {
      throw new HttpsError("not-found", "Batch not found");
    }

    if (batchDoc.data().status !== "pending") {
      throw new HttpsError(
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
    throw new HttpsError(
      "internal",
      "Failed to approve batch"
    );
  }
});

// 🎉 Complete payout (after M-Pesa/bank transfer succeeds)
exports.completePayout = onCall(async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError(
      "permission-denied",
      "Admin only"
    );
  }

  const { payoutId, batchId, reference, method } = request.data;
  if (!payoutId || !batchId || !reference) {
    throw new HttpsError(
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
      throw new HttpsError("not-found", "Payout not found");
    }

    const payout = payoutDoc.data();

    // Update payout
    await payoutRef.update({
      status: "completed",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      reference,
      method: method || "mpesa",
    });

    console.log(`✅ Payout completed: ${payoutId}`);

    return { success: true, message: "Payout marked as completed" };
  } catch (error) {
    console.error("Error completing payout:", error);
    throw new HttpsError(
      "internal",
      "Failed to complete payout"
    );
  }
});

// ==========================================
// 💰 INSTANT CANCELLATION REFUNDS (Phase 2)
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
      status: "pending",
      paymentMethod: "paystack",
      refundMethod: "paystack",
      paystackReference: transaction.reference,
      refundReference: null,
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

// ==========================================
// 📄 DOCUMENT EXPIRY MONITORING SYSTEM
// ==========================================

/**
 * Check for expiring verification documents and send reminders
 * Runs daily at 9 AM UTC (2 PM EAT)
 * Sends reminders at 30, 14, and 7 days before expiry
 */
exports.checkExpiringDocuments = onSchedule(
  {
    schedule: "0 9 * * *", // 9 AM UTC (2 PM EAT) every day
    timeZone: "UTC",
    retryCount: 2,
    maxInstances: 1,
  },
  async (context) => {
    console.log("🔍 Checking for expiring verification documents...");

    try {
      const now = new Date();
      const thirtyDaysFromNow = new Date(now.getTime() + (30 * 24 * 60 * 60 * 1000));
      const fourteenDaysFromNow = new Date(now.getTime() + (14 * 24 * 60 * 60 * 1000));
      const sevenDaysFromNow = new Date(now.getTime() + (7 * 24 * 60 * 60 * 1000));

      // Get all users with verification documents
      const usersSnapshot = await db.collection("users").get();
      let totalChecked = 0;
      let remindersSent = 0;

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const userId = userDoc.id;
        const email = userData.email;
        const name = userData.name || "Caregiver";

        if (!userData.verificationDocuments || userData.verificationDocuments.length === 0) {
          continue;
        }

        totalChecked++;

        for (const doc of userData.verificationDocuments) {
          if (!doc.expiryDate || doc.status !== 'approved') {
            continue; // Skip documents without expiry or not approved
          }

          const expiryDate = doc.expiryDate.toDate();
          const daysUntilExpiry = Math.ceil((expiryDate.getTime() - now.getTime()) / (24 * 60 * 60 * 1000));

          // Check if reminder should be sent
          let shouldSendReminder = false;
          let reminderType = '';

          if (daysUntilExpiry <= 7 && daysUntilExpiry > 0 && !doc.expiryReminderSent) {
            shouldSendReminder = true;
            reminderType = '7-day';
          } else if (daysUntilExpiry <= 14 && daysUntilExpiry > 7 && !doc.expiryReminderSent) {
            shouldSendReminder = true;
            reminderType = '14-day';
          } else if (daysUntilExpiry <= 30 && daysUntilExpiry > 14 && !doc.expiryReminderSent) {
            shouldSendReminder = true;
            reminderType = '30-day';
          }

          if (shouldSendReminder && email) {
            try {
              // Send reminder email
              const subject = `Document Expiry Reminder - ${doc.documentType.replace('_', ' ').toUpperCase()}`;
              const htmlContent = `
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                  <h2 style="color: #d32f2f;">Document Expiry Alert</h2>
                  <p>Dear ${name},</p>
                  <p>Your <strong>${doc.documentType.replace('_', ' ')}</strong> is expiring in <strong>${daysUntilExpiry} days</strong> (${expiryDate.toDateString()}).</p>
                  <p>Please renew your document and submit the updated version through the CareLink app to continue providing services.</p>
                  <div style="background-color: #fff3e0; padding: 15px; border-left: 4px solid #ff9800; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #e65100;">Action Required:</h3>
                    <ol>
                      <li>Renew your ${doc.documentType.replace('_', ' ')} with the relevant authority</li>
                      <li>Take a clear photo of the renewed document</li>
                      <li>Submit the new document through the CareLink verification section</li>
                    </ol>
                  </div>
                  <p>If you have any questions, please contact our support team.</p>
                  <p>Best regards,<br>CareLink Team</p>
                </div>
              `;

              // Create in-app notification + push for document expiry reminder
              await createNotificationAndPush({
                userId,
                payload: {
                  type: 'document_expiry_reminder',
                  title: 'Document Expiry Reminder',
                  message: `Your ${doc.documentType.replace('_', ' ')} is expiring in ${daysUntilExpiry} days. Please renew and resubmit.`,
                  data: { documentType: doc.documentType, daysUntilExpiry: String(daysUntilExpiry) },
                },
              });

              // Update document to mark reminder as sent
              const updatedDocs = userData.verificationDocuments.map(d =>
                d.documentType === doc.documentType && d.documentValue === doc.documentValue
                  ? { ...d, expiryReminderSent: true, lastReminderDate: admin.firestore.FieldValue.serverTimestamp() }
                  : d
              );

              await db.collection("users").doc(userId).update({
                verificationDocuments: updatedDocs
              });

              remindersSent++;
              console.log(`📧 Reminder sent to ${email} for ${doc.documentType} (${reminderType})`);

            } catch (emailError) {
              console.error(`❌ Failed to send reminder email to ${email}:`, emailError);
            }
          }
        }
      }

      console.log(`✅ Document expiry check completed:`);
      console.log(`   - Users checked: ${totalChecked}`);
      console.log(`   - Reminders sent: ${remindersSent}`);

      return {
        success: true,
        usersChecked: totalChecked,
        remindersSent: remindersSent,
      };

    } catch (error) {
      console.error("❌ Error checking expiring documents:", error);
      throw error;
    }
  }
);

/**
 * Get refund details (Admin API)
 */
exports.getRefundDetails = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
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

    // Authorization: Admin or the client who initiated refund
    const isAdmin = request.auth.token.admin;
    const isClient = request.auth.uid === refund.clientId;

    if (!isAdmin && !isClient) {
      throw new HttpsError("permission-denied", "Cannot view this refund");
    }

    return {
      id: refundDoc.id,
      ...refund,
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

  const { status, limit = 50 } = request.data;

  try {
    let query = db.collection("refunds").orderBy("createdAt", "desc");

    if (status) {
      query = query.where("status", "==", status);
    }

    query = query.limit(limit);

    const snapshot = await query.get();
    const refunds = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      refunds,
      count: refunds.length,
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

    // Mark as retrying
    await db.collection("refunds").doc(refundId).update({
      status: "pending",
      attempts: admin.firestore.FieldValue.increment(1),
      failureReason: null,
    });

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
 * Manual refund approval (Admin override)
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

    const refund = refundDoc.data();

    // Mark as manually approved
    await refundRef.update({
      status: "completed",
      manuallyApprovedBy: request.auth.uid,
      approvalNote: approvalNote || "Manual admin approval",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update transaction
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
