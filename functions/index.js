const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
require("dotenv").config(); // ✅ Load .env variables

admin.initializeApp();
const db = admin.firestore();

// ✅ Securely load Paystack key from .env
const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;

// 🔹 Verify Paystack Transaction
async function verifyPaystackPayment(reference) {
  const url = `https://api.paystack.co/transaction/verify/${reference}`;
  const headers = {
    Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
  };

  const response = await axios.get(url, { headers });
  return response.data;
}

// 🔹 Main Firebase Function
exports.verifyTransaction = functions.https.onCall(async (data, context) => {
  const { reference, userId, role } = data;

  if (!reference || !userId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing reference or userId."
    );
  }

  try {
    const verification = await verifyPaystackPayment(reference);
    const status = verification.data.status;

    if (status !== "success") {
      throw new Error("Transaction not successful.");
    }

    // Convert from Kobo → NGN → KES
    const amountKobo = verification.data.amount;
    const amountNGN = amountKobo / 100;
    const conversionRate = 0.67; // Example: 1 NGN ≈ 0.67 KES
    const amountKES = amountNGN * conversionRate;

    // Carelink Commission Model
    const caregiverCommission = amountKES * 0.15;
    const clientFee = amountKES * 0.02;
    const totalRevenue = caregiverCommission + clientFee;

    // Save transaction record
    await db.collection("transactions").doc(reference).set({
      userId,
      role,
      reference,
      amountKES,
      caregiverCommission,
      clientFee,
      totalRevenue,
      status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Premium Activation (KSh 300)
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
      success: true,
      message: "Transaction verified successfully.",
      data: {
        amountKES,
        caregiverCommission,
        clientFee,
        totalRevenue,
        premiumActivated: role === "caregiver" && amountKES >= 300,
      },
    };
  } catch (error) {
    console.error("❌ Verification error:", error.message);
    throw new functions.https.HttpsError(
      "internal",
      "Payment verification failed."
    );
  }
});

// 🔔 Send push notification when a new message is created
exports.onNewMessage = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const { conversationId, messageId } = context.params;
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

      if (recipientIds.length === 0) {
        console.log("No recipients found");
        return null;
      }

      // Get sender info
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderName =
        senderDoc.exists && senderDoc.data().displayName
          ? senderDoc.data().displayName
          : "Someone";

      // Send notification to each recipient
      const notificationPromises = recipientIds.map(async (recipientId) => {
        const userDoc = await db.collection("users").doc(recipientId).get();
        if (!userDoc.exists) return null;

        const userData = userDoc.data();
        const fcmTokens = userData.fcmTokens || [];

        if (fcmTokens.length === 0) {
          console.log(`No FCM tokens for user ${recipientId}`);
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
            .catch((err) => {
              console.error(
                `Error sending to token ${token}:`,
                err.message
              );
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
      console.log("✅ Push notifications sent successfully");
      return null;
    } catch (error) {
      console.error("❌ Error sending push notification:", error);
      return null;
    }
  });
