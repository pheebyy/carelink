import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'paystack_checkout_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/paystack_service.dart';
import '../services/payment_firestore_service.dart';
import 'payment_confirmation_screen.dart';
import 'payment_history_screen.dart';

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
    // Push a full screen confirmation page and return the user's choice
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationScreen(
          amount: amount,
          breakdown: breakdown,
          caregiverName: widget.caregiverName,
        ),
      ),
    );

    return result ?? false;
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

            // Pay button + View history
            Row(
              children: [
                Expanded(
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _initiatePaystackCheckout(
    Map<String, dynamic> paymentConfig,
    String reference,
  ) async {
    try {
      // Open real Paystack checkout
      final checkoutResult = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaystackCheckoutScreen(
            paymentConfig: paymentConfig,
            reference: reference,
          ),
        ),
      );

      if (checkoutResult != true) {
        await _paystackService.handlePaymentFailure(reference, 'User cancelled payment');
        _showError('Payment was cancelled. Tap to retry.', showRetry: true, reference: reference);
        return false;
      }

      // Verify with backend Cloud Function
      final verified = await _paystackService.verifyPayment(reference);
      if (!verified) {
        await _paystackService.handlePaymentFailure(reference, 'Verification failed');
        _showError('Payment verification failed. Tap to retry.', showRetry: true, reference: reference);
      }
      return verified;
    } catch (e) {
      await _paystackService.handlePaymentFailure(reference, e.toString());
      _showError('Paystack error: $e. Tap to retry.', showRetry: true, reference: reference);
      return false;
    }
  }

  void _showError(
    String message, {
    bool showRetry = false,
    String? reference,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: showRetry && reference != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _processPayment(),
              )
            : null,
      ),
    );
  }

  /// Placeholder: Add card / manage saved payment methods
  void _onAddCardPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add card flow is not implemented yet')),
    );
  }
}
