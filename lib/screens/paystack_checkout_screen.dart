import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paystack_payment/paystack_payment.dart';
import '../services/paystack_service.dart';

class PaystackCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> paymentConfig;
  final String reference;

  const PaystackCheckoutScreen({
    Key? key,
    required this.paymentConfig,
    required this.reference,
  }) : super(key: key);

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  final _paystackService = PaystackService();
  final _paystackPlugin = PaystackPayment();
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPaystackCheckout();
    });
  }

  void _startPaystackCheckout() async {
    try {
      setState(() => _isProcessing = true);

      final publicKey = widget.paymentConfig['publicKey'] as String? ?? '';
      final amountInKobo = widget.paymentConfig['amount'] as int? ?? 0;
      final email = widget.paymentConfig['email'] as String? ?? '';
      final accessCode = widget.paymentConfig['accessCode'] as String? ?? '';

      if (publicKey.isEmpty || amountInKobo <= 0 || email.isEmpty || accessCode.isEmpty) {
        _showErrorAndReturn('Invalid payment configuration');
        return;
      }

      // Checkout using the Paystack plugin with callbacks
      _paystackPlugin.checkout(
        context: context,
        accessCode: accessCode,
        onSuccess: (info) {
          // Payment succeeded, verify with backend
          _verifyPaymentOnSuccess();
        },
        onError: (error) {
          // Payment failed
          if (mounted) {
            _showErrorAndReturn('Payment error: $error');
          }
        },
        onCancel: (response) {
          // Payment cancelled
          if (mounted) {
            _showErrorAndReturn('Payment was cancelled');
          }
        },
      );
    } catch (e) {
      print(' Checkout error: $e');
      if (mounted) {
        _showErrorAndReturn('Payment error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _verifyPaymentOnSuccess() async {
    final user = FirebaseAuth.instance.currentUser;
    final verified = await _paystackService.verifyPayment(
      widget.reference,
      userId: user?.uid,
      role: 'client',
    );
    if (!mounted) return;

    if (verified) {
      Navigator.of(context).pop(true);
    } else {
      _showErrorAndReturn('Payment verification failed. Please contact support.');
    }
  }

  void _showErrorAndReturn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final amountKobo = widget.paymentConfig['amount'] as int? ?? 0;
    final amountKES = (amountKobo / 100).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Checkout'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Processing KES $amountKES payment...'),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 64, color: Colors.green.shade700),
                    const SizedBox(height: 24),
                    const Text(
                      'Secure Payment',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Redirecting to payment gateway...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

