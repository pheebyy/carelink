import 'package:flutter/material.dart';
import 'payment_method_screen.dart';

/// Example screen showing how to integrate the payment flow
class PaymentExampleScreen extends StatelessWidget {
  const PaymentExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Examples'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildExampleCard(
            context,
            title: 'Book Caregiver Service',
            description: 'Pay for a 3-hour elderly care service',
            amount: 1500.0,
            icon: Icons.medical_services,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            title: 'Premium Subscription',
            description: 'Upgrade to Premium for KSh 300/month',
            amount: 300.0,
            icon: Icons.star,
            color: Colors.orange,
            paymentType: 'premium_subscription',
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            title: 'One-time Payment',
            description: 'Test the payment flow with KSh 100',
            amount: 100.0,
            icon: Icons.payment,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          
          // How to integrate section
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'How to Integrate',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'To use this payment flow in your app:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildCodeExample(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard(
    BuildContext context, {
    required String title,
    required String description,
    required double amount,
    required IconData icon,
    required Color color,
    String paymentType = 'client_payment',
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _initiatePayment(
          context,
          amount: amount,
          paymentType: paymentType,
          metadata: {
            'service': title,
            'description': description,
          },
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'KSh ${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeExample() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '''
// Navigate to payment screen
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PaymentMethodScreen(
      amount: 1500.0,
      paymentType: 'client_payment',
      metadata: {
        'service': 'Elderly Care',
        'duration': '3 hours',
      },
    ),
  ),
);

if (result == true) {
  // Payment successful!
  print('Payment completed');
}
        ''',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  void _initiatePayment(
    BuildContext context, {
    required double amount,
    required String paymentType,
    required Map<String, dynamic> metadata,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(
          amount: amount,
          paymentType: paymentType,
          metadata: metadata,
        ),
      ),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Payment completed successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
