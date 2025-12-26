import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';



/// Handles initialization, transaction setup, and business logic
class PaystackService {
  static final PaystackService _instance = PaystackService._internal();

  late String _publicKey;
  bool _initialized = false;

  PaystackService._internal();

  factory PaystackService() => _instance;

  /// Initialize Paystack using your public key from `.env`
  void initialize() {
    _publicKey = dotenv.env['PAYSTACK_PUBLIC_KEY'] ?? '';

    if (_publicKey.isEmpty) {
      print('⚠️ Warning: Paystack public key not found in .env file');
      _initialized = false;
      return;
    }

    _initialized = true;
    print('✅ Paystack Service initialized successfully with KES currency');
  }

  /// Public getters
  String get publicKey => _publicKey;
  bool get isInitialized => _initialized;

  // ================================
  // 💼 CARELINK BUSINESS MODEL LOGIC
  // ================================

  /// Commission charged from caregiver (default 5%)
  double calculateCaregiverCommission(double amount, {double rate = 0.05}) {
    return amount * rate;
  }

  /// Transactional fee charged to the client (0.02 - 1%)
  double calculateClientFee(double amount, {double rate = 0.02}) {
    return amount * rate;
  }

  /// Premium subscription price — fixed at KSh 300
  double getPremiumPriceKES() => 300.0;

  /// ================================
  /// 💰 PAYMENT CONFIGURATION
  /// ================================

  /// Builds a payment configuration for Paystack checkout
  ///
  /// [type] can be:
  /// - "client_payment" (client pays caregiver)
  /// - "caregiver_commission" (Carelink deducts commission)
  /// - "premium_subscription" (caregiver buys premium)
  Map<String, dynamic> getPaymentConfig({
    required String email,
    required double amount, // in KSh
    String? reference,
    String type = "client_payment",
    Map<String, dynamic>? metadata,
  }) {
    if (!_initialized) {
      throw Exception('Paystack not initialized. Call initialize() first.');
    }

    double finalAmount = amount;

    // Apply Carelink logic per transaction type
    switch (type) {
      case "client_payment":
        final fee = calculateClientFee(amount);
        finalAmount = amount + fee;
        print('💰 Client fee (2%) added: KSh ${fee.toStringAsFixed(2)}');
        break;

      case "caregiver_commission":
        final commission = calculateCaregiverCommission(amount);
        finalAmount = commission;
        print('💼 Caregiver commission (5%): KSh ${commission.toStringAsFixed(2)}');
        break;

      case "premium_subscription":
        finalAmount = getPremiumPriceKES();
        print('⭐ Premium subscription set at KSh ${finalAmount.toStringAsFixed(2)}');
        break;

      default:
        print('⚠️ Unknown payment type, using base amount only.');
    }

    // Paystack expects amount * 100 (in lowest currency unit)
    final amountInKobo = (finalAmount * 100).toInt();

    return {
      'email': email,
      'amount': amountInKobo,
      'reference': reference ?? 'carelink_${DateTime.now().millisecondsSinceEpoch}',
      'publicKey': _publicKey,
      'currency': 'KES',
      'metadata': {
        'type': type,
        'base_amount': amount,
        'final_amount': finalAmount,
        'carelink_fee_applied': type != "premium_subscription",
        'timestamp': DateTime.now().toIso8601String(),
        ...?metadata,
      },
    };
  }

  // ================================
  // 🔍 PAYMENT VERIFICATION (CLIENT)
  // ================================
  ///
  /// This should call your Firebase Function: verifyTransaction
  /// Example endpoint: `https://us-central1-YOUR_PROJECT.cloudfunctions.net/verifyTransaction`
  ///
  /// The function checks Paystack, computes commissions, and updates Firestore.
  ///
  Future<bool> verifyPayment(String reference) async {
    try {
      if (!_initialized) {
        throw Exception('Paystack not initialized');
      }

      print('🔍 Verifying payment with reference: $reference');
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('verifyTransaction');
      final result = await callable.call(<String, dynamic>{'reference': reference});
      final data = result.data as Map<String, dynamic>?;
      final verified = data != null && (data['verified'] == true || data['status'] == 'verified');
      print('🔍 verifyPayment result: $data');
      return verified;
    } catch (e) {
      print('🔥 Paystack Verification Error: $e');
      return false;
    }
  }

  /// Request refund for a transaction (calls Cloud Function)
  Future<bool> initiateRefund(String reference) async {
    try {
      print('💰 Initiating refund for reference: $reference');
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('initiateRefund');
      final result = await callable.call(<String, dynamic>{'reference': reference});
      final data = result.data as Map<String, dynamic>?;
      final success = data != null && data['status'] == 'refund_initiated';
      print('💰 Refund result: $data');
      return success;
    } catch (e) {
      print('🔥 Refund Error: $e');
      return false;
    }
  }

  /// Handle payment failure with logging
  Future<void> handlePaymentFailure(String reference, String reason) async {
    try {
      print('❌ Payment failure: $reference - $reason');
      // Could log to Firestore for analytics
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('logPaymentFailure');
      await callable.call(<String, dynamic>{
        'reference': reference,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ Error logging failure: $e');
    }
  }
}
