import 'package:cloud_functions/cloud_functions.dart';
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
  final String? _selectedPaymentMethod = 'paystack';

  // UI Brand Colors
  static const Color _primaryGreen = Color(0xFF2E7D5B);
  static const Color _deepGreen = Color(0xFF1F5E44);
  static const Color _mutedGold = Color(0xFFB8862E);

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

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length > 1 ? 2 : 1).toUpperCase();
  }

  Map<String, double> _calculateBreakdown(double amount) {
    final platformFee = _paystackService.calculateClientFee(amount);
    final totalAmount = amount + platformFee;
    final caregiverEarning = amount;

    return {
      'baseAmount': amount,
      'platformFee': platformFee,
      'totalAmount': totalAmount,
      'caregiverEarning': caregiverEarning,
    };
  }

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

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('initializeTransaction');
      
      try {
        final initResult = await callable.call(<String, dynamic>{
          'email': paymentConfig['email'],
          'amount': paymentConfig['amount'],
          'reference': paymentConfig['reference'],
          'currency': paymentConfig['currency'],
          'metadata': paymentConfig['metadata'],
        });

        final initData = initResult.data as Map<String, dynamic>?;
        final accessCode =
            initData?['accessCode'] ??
            initData?['access_code'] ??
            initData?['data']?['access_code'];

        if (initData == null || accessCode == null) {
          throw Exception('Could not initialize payment with Paystack. Response: $initData');
        }
        paymentConfig['accessCode'] = accessCode;
      } on FirebaseFunctionsException catch (e) {
        throw Exception('Payment service error: ${e.code} - ${e.message}');
      }

      if (!mounted) return;

      final confirmed = await _showPaymentConfirmation(
        amount,
        _calculateBreakdown(amount),
      );

      if (!confirmed) {
        setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;

      final success = await _initiatePaystackCheckout(paymentConfig, reference);

      if (!success) {
        if (!mounted) return;
        _showError('Payment was not completed. Please try again.', showRetry: true, reference: reference);
        setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;
      _showSuccess('Payment successful!', 'KES ${amount.toStringAsFixed(2)} has been transferred to ${widget.caregiverName}');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Payment error: $e');
      _showError('Payment error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _showPaymentConfirmation(double amount, Map<String, double> breakdown) async {
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

  void _showSuccess(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String message, {bool showRetry = false, String? reference}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    final breakdown = _calculateBreakdown(double.tryParse(_amountController.text) ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Send Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. PAYING CARD
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F3EC), Color(0xFFD5EBDF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _primaryGreen,
                    child: Text(
                      _getInitials(widget.caregiverName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
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
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.caregiverName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: _deepGreen,
                          ),
                        ),
                        const Text(
                          'Professional Caregiver',
                          style: TextStyle(
                            fontSize: 13,
                            color: _primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 2. AMOUNT INPUT
            const Text(
              'Amount to send',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
              decoration: InputDecoration(
                prefixText: 'KES ',
                prefixStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: _primaryGreen),
                hintText: '0.00',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primaryGreen, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Minimum KES 100.00',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),

            // 3. PAYMENT BREAKDOWN CARD
            const Text(
              'Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildBreakdownRow('Base Amount', breakdown['baseAmount']!, Colors.black87),
                        const SizedBox(height: 8),
                        _buildBreakdownRow('Platform Fee (2%)', breakdown['platformFee']!, _mutedGold),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F3EC),
                    ),
                    child: _buildBreakdownRow(
                      'Total you pay',
                      breakdown['totalAmount']!,
                      _deepGreen,
                      isBold: true,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 4. PAYMENT METHOD
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedPaymentMethod == 'paystack' ? _primaryGreen : Colors.grey.shade200,
                  width: 2,
                ),
                boxShadow: _selectedPaymentMethod == 'paystack'
                    ? [BoxShadow(color: _primaryGreen.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 2)]
                    : null,
              ),
              child: ListTile(
                leading: const Icon(Icons.security, color: _primaryGreen),
                title: const Text('Paystack', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Cards, Bank, Mobile Money'),
                trailing: Radio<String>(
                  value: 'paystack',
                  groupValue: _selectedPaymentMethod,
                  activeColor: _primaryGreen,
                  fillColor: WidgetStateProperty.resolveWith((states) => _primaryGreen),
                  onChanged: null, // Fixed: disabled to match selection UI
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 5. SAVED PAYMENT METHODS / ADD CARD
            const Text(
              'Saved Cards',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildDashedAddCardTile(),
            const SizedBox(height: 40),

            // 6. PAY BUTTON
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: (_isProcessing || !_isAmountValid()) ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: _primaryGreen.withValues(alpha: 0.4),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        'Pay KES ${breakdown['totalAmount']!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double amount, Color color, {bool isBold = false, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          'KES ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontFamily: 'monospace',
            fontWeight: isBold ? FontWeight.bold : FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDashedAddCardTile() {
    return CustomPaint(
      painter: _DashedRectPainter(color: Colors.grey.shade400, strokeWidth: 1.5, gap: 5.0),
      child: InkWell(
        onTap: _onAddCardPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.grey.shade600, size: 28),
              const SizedBox(height: 8),
              Text(
                'Add a card to save for next time',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _initiatePaystackCheckout(Map<String, dynamic> paymentConfig, String reference) async {
    try {
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
        return false;
      }
      return true;
    } catch (e) {
      await _paystackService.handlePaymentFailure(reference, e.toString());
      return false;
    }
  }

  void _onAddCardPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add card flow is not implemented yet'), behavior: SnackBarBehavior.floating),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  _DashedRectPainter({this.color = Colors.grey, this.strokeWidth = 1.5, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(12)));

    final dashPath = Path();
    double distance = 0.0;
    for (final segment in path.computeMetrics()) {
      while (distance < segment.length) {
        dashPath.addPath(segment.extractPath(distance, distance + gap), Offset.zero);
        distance += gap * 2;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(_DashedRectPainter oldDelegate) => false;
}
