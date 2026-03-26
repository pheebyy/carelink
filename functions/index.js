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
const PAYSTACK_API_SECRET = defineSecret("PAYSTACK_SECRET_KEY");

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

function getPaystackSecret() {
  // Prefer Secret Manager in production; fallback to .env for emulator/local runs.
  return PAYSTACK_API_SECRET.value() || process.env.PAYSTACK_SECRET_KEY || "";
}

// 🔹 Initialize Paystack Transaction
exports.initializeTransaction = onCall({ secrets: [PAYSTACK_API_SECRET] }, async (request) => {
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
      throw new HttpsError("failed-precondition", "PAYSTACK_SECRET_KEY is not configured.");
    }

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
    
    return {
      status: true,
      message: "Transaction initialized successfully",
      data: response.data.data,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error("Error initializing transaction:", error.response?.data || error.message);
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
exports.verifyTransaction = onCall({ secrets: [PAYSTACK_API_SECRET] }, async (request) => {
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
        status,
        paymentType,
        paystackData: verification.data,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

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
