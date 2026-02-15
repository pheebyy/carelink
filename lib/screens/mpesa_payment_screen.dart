import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/paystack_service.dart';
import '../services/azure_communication_service.dart';

/// M-Pesa payment screen with STK Push
class MpesaPaymentScreen extends StatefulWidget {
  final double amount;
  final String email;
  final String paymentType;
  final Map<String, dynamic>? metadata;

  const MpesaPaymentScreen({
    Key? key,
    required this.amount,
    required this.email,
    this.paymentType = 'client_payment',
    this.metadata,
  }) : super(key: key);

  @override
  State<MpesaPaymentScreen> createState() => _MpesaPaymentScreenState();
}

class _MpesaPaymentScreenState extends State<MpesaPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _paystackService = PaystackService();
  final _azureService = AzureCommunicationService();
  
  bool _isProcessing = false;
  String? _transactionReference;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.amount + _paystackService.calculateClientFee(widget.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('M-Pesa Payment'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // M-Pesa Logo/Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_android,
                    size: 64,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Amount Card
              Card(
                color: Colors.green.shade50,
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
                          color: Colors.green,
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

              // Phone Number Input
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: InputDecoration(
                  labelText: 'M-Pesa Phone Number',
                  hintText: '254712345678',
                  prefixIcon: const Icon(Icons.phone, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  helperText: 'Enter number without + or spaces',
                  helperStyle: TextStyle(color: Colors.grey.shade600),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your M-Pesa number';
                  }
                  if (!value.startsWith('254')) {
                    return 'Number must start with 254';
                  }
                  if (value.length != 12) {
                    return 'Number must be 12 digits (254XXXXXXXXX)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Instructions Card
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
                          'How to Pay',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep('1', 'Enter your Safaricom number'),
                    _buildInstructionStep('2', 'Click "Pay Now" below'),
                    _buildInstructionStep('3', 'Enter M-Pesa PIN on your phone'),
                    _buildInstructionStep('4', 'Wait for confirmation'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Pay Button
              ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                  Icon(Icons.lock, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Secured by Paystack',
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
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final phoneNumber = _phoneController.text.trim();
      
      // Initialize M-Pesa payment
      final result = await _paystackService.initializeMpesaPayment(
        email: widget.email,
        amount: widget.amount,
        phoneNumber: phoneNumber,
        type: widget.paymentType,
      );

      if (result == null) {
        throw Exception('Failed to initialize payment');
      }

      _transactionReference = result['reference'];

      // Show STK Push dialog
      if (mounted) {
        await _showSTKPushDialog(phoneNumber);
      }

      // Verify payment after user confirms STK push
      await _verifyPayment();
      
    } catch (e) {
      if (mounted) {
        _showError('Payment failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showSTKPushDialog(String phoneNumber) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.phone_android, color: Colors.green.shade700),
            const SizedBox(width: 12),
            const Text('Check Your Phone'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 20),
            Text(
              'An M-Pesa prompt has been sent to:',
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              phoneNumber,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please enter your M-Pesa PIN to complete the payment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I\'ve Entered PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPayment() async {
    if (_transactionReference == null) return;

    // Wait a bit for payment to process
    await Future.delayed(const Duration(seconds: 2));

    final verified = await _paystackService.verifyPayment(_transactionReference!);

    if (!mounted) return;

    if (verified) {
      // Send SMS confirmation
      if (_azureService.isInitialized) {
        await _azureService.sendPaymentConfirmation(
          phone: '+${_phoneController.text.trim()}',
          recipientName: 'Customer',
          amount: widget.amount,
          reference: _transactionReference!,
        );
      }

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
          duration: Duration(seconds: 3),
        ),
      );

      // Return success
      Navigator.pop(context, true);
    } else {
      _showError('Payment verification failed. Please contact support.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
