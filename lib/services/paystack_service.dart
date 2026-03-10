import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'azure_communication_service.dart';



/// Handles initialization, transaction setup, and business logic
class PaystackService {
  static final PaystackService _instance = PaystackService._internal();

  late String _publicKey;
  bool _initialized = false;
  final _azureComm = AzureCommunicationService();

  PaystackService._internal();

  factory PaystackService() => _instance;

  /// Initialize Paystack using your public key from `.env`
  void initialize() {
    _publicKey = dotenv.env['PAYSTACK_PUBLIC_KEY'] ?? '';

    if (_publicKey.isEmpty) {
      print(' Warning: Paystack public key not found in .env file');
      _initialized = false;
      return;
    }

    _initialized = true;
    print(' Paystack Service initialized successfully with KES currency');
  }

  /// Public getters
  String get publicKey => _publicKey;
  bool get isInitialized => _initialized;

  // ================================
  //  CARELINK BUSINESS MODEL LOGIC
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

  // ================================
  //  PAYMENT CHANNELS
  // ================================

  /// Get available payment channels for Kenya
  List<String> getAvailablePaymentChannels() {
    return ['card', 'mobile_money', 'bank'];
  }

  /// Get payment configuration with specific channel (Card, M-Pesa, etc.)
  Map<String, dynamic> getPaymentConfigWithChannel({
    required String email,
    required double amount,
    required String channel, // 'card', 'mobile_money', 'bank'
    String? reference,
    String type = "client_payment",
    Map<String, dynamic>? metadata,
  }) {
    final config = getPaymentConfig(
      email: email,
      amount: amount,
      reference: reference,
      type: type,
      metadata: metadata,
    );

    // Add channel-specific configuration
    config['channels'] = [channel];
    
    if (channel == 'mobile_money') {
      config['metadata']['payment_method'] = 'M-Pesa';
      config['metadata']['mobile_money_provider'] = 'mpesa';
      print(' M-Pesa payment channel selected');
    } else if (channel == 'card') {
      config['metadata']['payment_method'] = 'Card';
      print(' Card payment channel selected');
    } else if (channel == 'bank') {
      config['metadata']['payment_method'] = 'Bank Transfer';
      print(' Bank transfer channel selected');
    }

    return config;
  }

  /// Initialize M-Pesa payment
  Future<Map<String, dynamic>?> initializeMpesaPayment({
    required String email,
    required double amount,
    required String phoneNumber, // Format: 254XXXXXXXXX
    String? reference,
    String type = "client_payment",
  }) async {
    try {
      print(' Initializing M-Pesa payment for $phoneNumber');

      final resolvedReference = reference ?? generateUniqueReference('mpesa');

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('initializeMpesaPayment');

      final result = await callable.call(<String, dynamic>{
        'email': email,
        'amount': amount,
        'phoneNumber': phoneNumber,
        'reference': resolvedReference,
        'type': type,
      });

      final data = result.data as Map<String, dynamic>?;
      print(' M-Pesa payment initialized: $data');
      return data;
    } catch (e) {
      print(' M-Pesa initialization error: $e');
      return null;
    }
  }

  // ================================
  //  CARD MANAGEMENT
  // ================================

  /// Save card authorization for future payments
  Future<bool> saveCardAuthorization({
    required String userId,
    required String authorizationCode,
    required String cardType,
    required String last4,
    required String expiryMonth,
    required String expiryYear,
    required String bin,
  }) async {
    try {
      print(' Saving card authorization for user: $userId');
      
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('saveCardAuthorization');
      
      final result = await callable.call(<String, dynamic>{
        'userId': userId,
        'authorizationCode': authorizationCode,
        'cardType': cardType,
        'last4': last4,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'bin': bin,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      final success = result.data?['success'] == true;
      print(success ? ' Card saved successfully' : ' Failed to save card');
      return success;
    } catch (e) {
      print(' Error saving card: $e');
      return false;
    }
  }

  /// Get saved cards for a user
  Future<List<Map<String, dynamic>>> getSavedCards(String userId) async {
    try {
      print(' Fetching saved cards for user: $userId');
      
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getSavedCards');
      
      final result = await callable.call(<String, dynamic>{'userId': userId});
      
      final cards = List<Map<String, dynamic>>.from(result.data?['cards'] ?? []);
      print(' Found ${cards.length} saved cards');
      return cards;
    } catch (e) {
      print(' Error fetching cards: $e');
      return [];
    }
  }

  /// Delete a saved card
  Future<bool> deleteSavedCard({
    required String userId,
    required String cardId,
  }) async {
    try {
      print(' Deleting card: $cardId');
      
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('deleteSavedCard');
      
      final result = await callable.call(<String, dynamic>{
        'userId': userId,
        'cardId': cardId,
      });
      
      final success = result.data?['success'] == true;
      print(success ? ' Card deleted' : ' Failed to delete card');
      return success;
    } catch (e) {
      print(' Error deleting card: $e');
      return false;
    }
  }

  /// Charge a saved card
  Future<Map<String, dynamic>?> chargeSavedCard({
    required String userId,
    required String authorizationCode,
    required double amount,
    String? reference,
    String type = "client_payment",
  }) async {
    try {
      print('💳 Charging saved card...');

      final resolvedReference = reference ?? generateUniqueReference('card');

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('chargeSavedCard');

      final result = await callable.call(<String, dynamic>{
        'userId': userId,
        'authorizationCode': authorizationCode,
        'amount': amount,
        'reference': resolvedReference,
        'type': type,
      });

      final data = result.data as Map<String, dynamic>?;
      print(' Card charge result: $data');
      return data;
    } catch (e) {
      print(' Error charging card: $e');
      return null;
    }
  }

  /// ================================
  /// PAYMENT CONFIGURATION
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
        print(' Client fee (2%) added: KSh ${fee.toStringAsFixed(2)}');
        break;

      case "caregiver_commission":
        final commission = calculateCaregiverCommission(amount);
        finalAmount = commission;
        print(' Caregiver commission (5%): KSh ${commission.toStringAsFixed(2)}');
        break;

      case "premium_subscription":
        finalAmount = getPremiumPriceKES();
        print(' Premium subscription set at KSh ${finalAmount.toStringAsFixed(2)}');
        break;

      default:
        print(' Unknown payment type, using base amount only.');
    }

    // Paystack expects amount * 100 (in lowest currency unit)
    final amountInKobo = (finalAmount * 100).toInt();

    // Always generate a unique reference if not provided
    final ref = reference ?? generateUniqueReference('carelink');

    return {
      'email': email,
      'amount': amountInKobo,
      'reference': ref,
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

  /// Utility to generate a unique reference
  String generateUniqueReference(String prefix) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
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
  Future<bool> verifyPayment(String reference, {String? userId, String? role}) async {
    try {
      if (!_initialized) {
        throw Exception('Paystack not initialized');
      }

      print('🔍 Verifying payment with reference: $reference');
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('verifyTransaction');
      final result = await callable.call(<String, dynamic>{
        'reference': reference,
        'userId': userId ?? 'unknown',
        'role': role ?? 'client',
      });
      final data = result.data as Map<String, dynamic>?;
      final verified = data != null && (data['verified'] == true || data['status'] == 'verified');
      
      // Send SMS notification if payment verified and Azure is initialized
      if (verified && _azureComm.isInitialized) {
        try {
          await _azureComm.sendPaymentConfirmation(
            phone: data['phone'] ?? '',
            recipientName: data['name'] ?? 'Customer',
            amount: (data['amount'] ?? 0.0).toDouble(),
            reference: reference,
          );
          print('Payment confirmation SMS sent');
        } catch (smsError) {
          print(' SMS notification failed but payment verified: $smsError');
        }
      }
      
      print('verifyPayment result: $data');
      return verified;
    } catch (e) {
      print(' Paystack Verification Error: $e');
      return false;
    }
  }

  /// Request refund for a transaction (calls Cloud Function)
  Future<bool> initiateRefund(String reference) async {
    try {
      print(' Initiating refund for reference: $reference');
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('initiateRefund');
      final result = await callable.call(<String, dynamic>{'reference': reference});
      final data = result.data as Map<String, dynamic>?;
      final success = data != null && data['status'] == 'refund_initiated';
      print(' Refund result: $data');
      return success;
    } catch (e) {
      print(' Refund Error: $e');
      return false;
    }
  }

  /// Handle payment failure with logging
  Future<void> handlePaymentFailure(String reference, String reason) async {
    try {
      print(' Payment failure: $reference - $reason');
      // Could log to Firestore for analytics
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('logPaymentFailure');
      await callable.call(<String, dynamic>{
        'reference': reference,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging failure: $e');
    }
  }

  // Example: Add a check before starting a transaction (pseudo-code, depends on your backend)
  // You can call this before initializing a payment
  Future<bool> isReferenceValid(String reference) async {
    return true; // Placeholder
  }

  // Removed invalid class-level example:
  // final ref = reference ?? generateUniqueReference('mpesa');
}
