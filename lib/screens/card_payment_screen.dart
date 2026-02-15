import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/paystack_service.dart';

/// Card payment screen with Paystack inline checkout
class CardPaymentScreen extends StatefulWidget {
  final double amount;
  final String email;
  final String paymentType;
  final Map<String, dynamic>? metadata;

  const CardPaymentScreen({
    Key? key,
    required this.amount,
    required this.email,
    this.paymentType = 'client_payment',
    this.metadata,
  }) : super(key: key);

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _paystackService = PaystackService();
  bool _isProcessing = false;
  String? _transactionReference;

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.amount + _paystackService.calculateClientFee(widget.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Payment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.credit_card,
                  size: 64,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Amount Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Amount to Pay',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'KSh ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Base: KSh ${widget.amount.toStringAsFixed(2)} + Fee: KSh ${_paystackService.calculateClientFee(widget.amount).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Accepted Cards
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'We Accept',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCardBadge('VISA', Colors.blue),
                      const SizedBox(width: 8),
                      _buildCardBadge('Mastercard', Colors.red),
                      const SizedBox(width: 8),
                      _buildCardBadge('Verve', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Payment Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Click "Pay Now" to open secure payment page\n'
                    '2. Enter your card details\n'
                    '3. Complete the payment\n'
                    '4. You\'ll be redirected back automatically',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Pay Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _initiatePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
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
                  : const Text(
                      'Pay Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Security Notice
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '256-bit SSL Encryption',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBadge(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Future<void> _initiatePayment() async {
    setState(() => _isProcessing = true);

    try {
      // Get payment configuration
      final config = _paystackService.getPaymentConfigWithChannel(
        email: widget.email,
        amount: widget.amount,
        channel: 'card',
        type: widget.paymentType,
        metadata: widget.metadata,
      );

      _transactionReference = config['reference'] as String;

      // Initialize transaction via Cloud Function
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('initializeTransaction');
      
      final result = await callable.call(<String, dynamic>{
        'email': widget.email,
        'amount': config['amount'],
        'reference': _transactionReference,
        'channels': ['card'],
        'metadata': config['metadata'],
      });

      final data = result.data as Map<String, dynamic>?;
      
      if (data != null && data['status'] == true) {
        final authorizationUrl = data['data']?['authorization_url'] as String?;
        
        if (authorizationUrl != null && mounted) {
          // Open Paystack checkout in webview
          final success = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PaystackWebView(
                authorizationUrl: authorizationUrl,
                reference: _transactionReference!,
              ),
            ),
          );

          if (success == true && mounted) {
            // Verify payment
            await _verifyPayment();
          } else {
            throw Exception('Payment cancelled');
          }
        } else {
          throw Exception('Failed to get payment URL');
        }
      } else {
        throw Exception(data?['message'] ?? 'Failed to initialize payment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _verifyPayment() async {
    if (_transactionReference == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await Future.delayed(const Duration(seconds: 2));
      
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      final verified = await _paystackService.verifyPayment(
        _transactionReference!,
        userId: user?.uid,
        role: 'client',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Payment successful!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Payment verification failed');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Paystack WebView for secure card payment
class PaystackWebView extends StatefulWidget {
  final String authorizationUrl;
  final String reference;

  const PaystackWebView({
    Key? key,
    required this.authorizationUrl,
    required this.reference,
  }) : super(key: key);

  @override
  State<PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<PaystackWebView> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _checkPaymentStatus(url);
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  void _checkPaymentStatus(String url) {
    // Check if payment was successful or cancelled
    if (url.contains('success') || url.contains('callback')) {
      Navigator.pop(context, true);
    } else if (url.contains('cancel') || url.contains('close')) {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
