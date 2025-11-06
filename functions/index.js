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
