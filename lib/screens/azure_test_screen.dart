import 'package:flutter/material.dart';
import '../services/azure_communication_service.dart';

/// Test screen for Azure Communication Service
class AzureTestScreen extends StatefulWidget {
  const AzureTestScreen({super.key});

  @override
  State<AzureTestScreen> createState() => _AzureTestScreenState();
}

class _AzureTestScreenState extends State<AzureTestScreen> {
  final _azureService = AzureCommunicationService();
  final _phoneController = TextEditingController(text: '+254700000000');
  String _statusMessage = 'Ready to test Azure Communication Service';
  bool _isSending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Azure Communication Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _azureService.isInitialized ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _azureService.isInitialized ? Icons.check_circle : Icons.error,
                          color: _azureService.isInitialized ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _azureService.isInitialized 
                              ? 'Service Initialized' 
                              : 'Service Not Initialized',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Phone Number Input
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+254700000000',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
                helperText: 'Format: +[country code][number]',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),

            // Test Buttons
            const Text(
              'Test SMS Functions:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildTestButton(
              label: '📅 Test Booking Notification',
              color: Colors.blue,
              onPressed: _testBookingNotification,
            ),
            const SizedBox(height: 8),

            _buildTestButton(
              label: '💰 Test Payment Confirmation',
              color: Colors.green,
              onPressed: _testPaymentConfirmation,
            ),
            const SizedBox(height: 8),

            _buildTestButton(
              label: '⏰ Test Booking Reminder',
              color: Colors.orange,
              onPressed: _testBookingReminder,
            ),
            const SizedBox(height: 8),

            _buildTestButton(
              label: '🔐 Test Verification Code',
              color: Colors.purple,
              onPressed: _testVerificationCode,
            ),
            const SizedBox(height: 8),

            _buildTestButton(
              label: '📱 Test Generic SMS',
              color: Colors.teal,
              onPressed: _testGenericSMS,
            ),
            const SizedBox(height: 24),

            // Info Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Important Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• SMS will be sent from Azure test number\n'
                      '• Check console for detailed logs\n'
                      '• Phone number must include country code\n'
                      '• Free tier has limited SMS quota',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: _isSending ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isSending 
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
    );
  }

  Future<void> _testBookingNotification() async {
    setState(() {
      _isSending = true;
      _statusMessage = 'Sending booking notification...';
    });

    final success = await _azureService.sendBookingNotification(
      caregiverPhone: _phoneController.text.trim(),
      clientName: 'John Doe',
      bookingDate: DateTime.now().toString().substring(0, 10),
      serviceType: 'Elderly Care',
    );

    setState(() {
      _isSending = false;
      _statusMessage = success
          ? '✅ Booking notification sent successfully!'
          : '❌ Failed to send notification. Check console logs.';
    });
  }

  Future<void> _testPaymentConfirmation() async {
    setState(() {
      _isSending = true;
      _statusMessage = 'Sending payment confirmation...';
    });

    final success = await _azureService.sendPaymentConfirmation(
      phone: _phoneController.text.trim(),
      recipientName: 'Jane Smith',
      amount: 1500.00,
      reference: 'PAY${DateTime.now().millisecondsSinceEpoch}',
    );

    setState(() {
      _isSending = false;
      _statusMessage = success
          ? '✅ Payment confirmation sent successfully!'
          : '❌ Failed to send confirmation. Check console logs.';
    });
  }

  Future<void> _testBookingReminder() async {
    setState(() {
      _isSending = true;
      _statusMessage = 'Sending booking reminder...';
    });

    final success = await _azureService.sendBookingReminder(
      phone: _phoneController.text.trim(),
      name: 'Alex Johnson',
      bookingDate: DateTime.now().add(const Duration(days: 1)).toString().substring(0, 10),
      bookingTime: '10:00 AM',
    );

    setState(() {
      _isSending = false;
      _statusMessage = success
          ? '✅ Booking reminder sent successfully!'
          : '❌ Failed to send reminder. Check console logs.';
    });
  }

  Future<void> _testVerificationCode() async {
    setState(() {
      _isSending = true;
      _statusMessage = 'Sending verification code...';
    });

    final code = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    final success = await _azureService.sendVerificationCode(
      phone: _phoneController.text.trim(),
      code: code,
    );

    setState(() {
      _isSending = false;
      _statusMessage = success
          ? '✅ Verification code sent: $code'
          : '❌ Failed to send code. Check console logs.';
    });
  }

  Future<void> _testGenericSMS() async {
    setState(() {
      _isSending = true;
      _statusMessage = 'Sending generic SMS...';
    });

    final success = await _azureService.sendSMS(
      phone: _phoneController.text.trim(),
      message: 'Hello from Carelink! This is a test message from Azure Communication Service. 🚀',
    );

    setState(() {
      _isSending = false;
      _statusMessage = success
          ? '✅ Generic SMS sent successfully!'
          : '❌ Failed to send SMS. Check console logs.';
    });
  }
}
