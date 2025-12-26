import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/paystack_service.dart';

/// Paystack checkout screen using web redirect.
/// Falls back to simulated checkout if web launch fails.
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
  bool _isProcessing = false;
  late PaystackService _paystackService;

  @override
  void initState() {
    super.initState();
    _paystackService = PaystackService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchPaystackCheckout();
    });
  }

  void _launchPaystackCheckout() async {
    try {
      setState(() => _isProcessing = true);

      // Configuration values (would be used for web redirect in production)
      // final publicKey = widget.paymentConfig['publicKey'] as String? ?? '';
      // final amount = widget.paymentConfig['amount'] as int? ?? 0;
      // final email = widget.paymentConfig['email'] as String? ?? '';

      // Build Paystack hosted checkout URL
      // Note: This requires the transaction to be initialized on the backend first
      final checkoutUrl = 'https://checkout.paystack.com/';

      // In production, the backend should return an access_code
      // For now, simulate or redirect to a checkout page
      final accessCode = 'accs_xyz123'; // Placeholder

      final url = Uri.parse('$checkoutUrl$accessCode');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);

        // In a real app, you'd poll the backend to verify payment status
        // For now, simulate success after delay
        await Future.delayed(const Duration(seconds: 5));

        if (mounted) {
          // Simulate verification
          final verified = await _paystackService.verifyPayment(widget.reference);
          if (verified) {
            Navigator.of(context).pop(true);
          } else {
            _showErrorAndReturn('Payment verification failed');
          }
        }
      } else {
        // Fallback to simulated checkout UI
        _showSimulatedCheckout();
      }
    } catch (e) {
      print('🔥 Exception during checkout: $e');
      _showSimulatedCheckout();
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSimulatedCheckout() {
    // Show simulated payment UI as fallback
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Simulated Checkout'),
        content: const Text(
          'For testing: Use test card 4111 1111 1111 1111\n\n'
          'This simulates a successful payment for demo purposes.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                _showErrorAndReturn('Payment cancelled');
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
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
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text('Amount'),
                            Text(
                              'KES $amountKES',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Reference: ${widget.reference}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

