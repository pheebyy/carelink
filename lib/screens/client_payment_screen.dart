import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/paystack_service.dart';
import '../services/payment_firestore_service.dart';

class ClientPaymentScreen extends StatefulWidget {
  final String caregiverId;
  final String caregiverName;
  final double suggestedAmount;

  const ClientPaymentScreen({
    super.key,
    required this.caregiverId,
    required this.caregiverName,
    this.suggestedAmount = 1000.0,
  });

  @override
  State<ClientPaymentScreen> createState() => _ClientPaymentScreenState();
}

class _ClientPaymentScreenState extends State<ClientPaymentScreen> {
  final _amountController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _paystackService = PaystackService();
  final _paymentService = PaymentFirestoreService();

  bool _isProcessing = false;
  String? _selectedPaymentMethod = 'paystack';

  bool _isAmountValid() {
    final value = double.tryParse(_amountController.text);
    return value != null && value > 0 && value >= 100;
  }

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.suggestedAmount.toStringAsFixed(2);
    _paystackService.initialize();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Calculate payment breakdown
  Map<String, double> _calculateBreakdown(double amount) {
    final platformFee = _paystackService.calculateClientFee(amount);
    final totalAmount = amount + platformFee;
    final caregiverEarning = amount - _paystackService.calculateCaregiverCommission(amount);

    return {
      'baseAmount': amount,
      'platformFee': platformFee,
      'totalAmount': totalAmount,
      'caregiverEarning': caregiverEarning,
    };
  }

  /// Process payment
  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text);

    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (amount < 100) {
      _showError('Minimum amount is KES 100');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Create payment transaction
      final reference = 'payment_${DateTime.now().millisecondsSinceEpoch}';
      final transaction = await _paymentService.createTransaction(
        clientId: user.uid,
        caregiverId: widget.caregiverId,
        amount: amount,
        reference: reference,
        metadata: {
          'caregiverName': widget.caregiverName,
          'clientEmail': user.email,
        },
      );

      // Get payment config for Paystack
      final paymentConfig = _paystackService.getPaymentConfig(
        email: user.email ?? 'user@carelink.app',
        amount: amount,
        reference: reference,
        type: 'client_payment',
        metadata: {
          'transactionId': transaction.id,
          'caregiverId': widget.caregiverId,
        },
      );

      if (!mounted) return;

      // Show payment confirmation dialog
      final confirmed = await _showPaymentConfirmation(
        amount,
        _calculateBreakdown(amount),
      );

      if (!confirmed) {
        setState(() => _isProcessing = false);
        return;
      }

      // Initiate Paystack checkout with payment config and verify result
      final success = await _initiatePaystackCheckout(paymentConfig, reference);

      if (!success) {
        // Payment not completed or verification failed
        if (!mounted) return;
        _showError('Payment was not completed. Please try again.');
        setState(() => _isProcessing = false);
        return;
      }

      // After successful Paystack payment & verification, mark transaction as completed
      await _paymentService.completeTransaction(reference);

      if (!mounted) return;

      _showSuccess(
        'Payment successful!',
        'KES ${amount.toStringAsFixed(2)} has been transferred to ${widget.caregiverName}',
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showError('Payment failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Show payment confirmation dialog
  Future<bool> _showPaymentConfirmation(
    double amount,
    Map<String, double> breakdown,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pay ${widget.caregiverName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildBreakdownRow(
              'Base Amount',
              breakdown['baseAmount']!,
              Colors.black87,
            ),
            _buildBreakdownRow(
              'Platform Fee (2%)',
              breakdown['platformFee']!,
              Colors.orange,
            ),
            const Divider(height: 16),
            _buildBreakdownRow(
              'You Pay',
              breakdown['totalAmount']!,
              Colors.green,
              isBold: true,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.caregiverName} receives: KES ${breakdown['caregiverEarning']!.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    ) ??
    false;
  }

  /// Build breakdown row
  Widget _buildBreakdownRow(
    String label,
    double amount,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'KES ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _calculateBreakdown(
      double.tryParse(_amountController.text) ?? 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Payment'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Caregiver info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.green.shade700,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paying',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          widget.caregiverName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount input
            Text(
              'Amount (KES)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
              decoration: InputDecoration(
                prefixText: 'KES ',
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Minimum KES 100.00',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // Payment breakdown
            Text(
              'Payment Breakdown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildBreakdownRow(
                    'Amount to caregiver',
                    breakdown['baseAmount']!,
                    Colors.black87,
                  ),
                  const SizedBox(height: 8),
                  _buildBreakdownRow(
                    'Platform fee (2%)',
                    breakdown['platformFee']!,
                    Colors.orange,
                  ),
                  const Divider(height: 16),
                  _buildBreakdownRow(
                    'Total you pay',
                    breakdown['totalAmount']!,
                    Colors.green,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment method selection
            Text(
              'Payment Method',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paystack',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Secure card payment',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Radio<String>(
                    value: 'paystack',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) => setState(
                      () => _selectedPaymentMethod = value,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Saved payment methods (placeholder)
            Text(
              'Saved payment methods',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('No saved cards')),
                  TextButton(
                    onPressed: _onAddCardPressed,
                    child: const Text('Add card'),
                  ),
                ],
              ),
            ),

            // Pay button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isProcessing || !_isAmountValid()) ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Pay KES ${breakdown['totalAmount']!.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

            /// Placeholder: Add card / manage saved payment methods
            void _onAddCardPressed() {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add card flow is not implemented yet')),
              );
            }

  Future<bool> _initiatePaystackCheckout(
    Map<String, dynamic> paymentConfig,
    String reference,
  ) async {
    try {
      // TODO: Implement Paystack checkout UI integration
      // This method should:
      // 1. Use the paystack_payment package to show payment UI
      // 2. Call PaystackPlugin.initialize() if not already done
      // 3. Show payment form with amount, email, reference
      // 4. Handle payment response (success/failure)
      // 5. For successful payments, call Cloud Function to verify with Paystack
      // 
      // Example implementation structure:
      // final CheckoutResponse response = await PaystackPlugin.checkout(
      //   context: context,
      //   secretKey: dotenv.env['PAYSTACK_SECRET_KEY']!,
      //   reference: reference,
      //   amount: paymentConfig['amount'], // in Kobo
      //   email: paymentConfig['email'],
      //   onClosed: () {
      //     _showError('Payment cancelled');
      //   },
      // );
      //
      // if (response.status) {
      //   // Verify with Cloud Function
      //   final result = await FirebaseFunctions.instance
      //       .httpsCallable('verifyTransaction')
      //       .call({'reference': reference});
      //   if (result.data['success']) {
      //     _showSuccess('Payment verified and wallet credited!', '');
      //   }
      // } else {
      //   _showError('Payment failed');
      // }

      // For now, simulate successful payment flow by verifying payment
      final verified = await _paystackService.verifyPayment(reference);

      if (!verified) {
        return false;
      }

      return true;
    } catch (e) {
      _showError('Paystack error: $e');
      return false;
    }
  }
}
