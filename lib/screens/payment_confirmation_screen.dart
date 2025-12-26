import 'package:flutter/material.dart';

class PaymentConfirmationScreen extends StatelessWidget {
  final double amount;
  final Map<String, double> breakdown;
  final String caregiverName;

  const PaymentConfirmationScreen({
    Key? key,
    required this.amount,
    required this.breakdown,
    required this.caregiverName,
  }) : super(key: key);

  Widget _buildBreakdownRow(String label, double value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('KES ${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Payment'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pay $caregiverName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildBreakdownRow('Base Amount', breakdown['baseAmount'] ?? 0, Colors.black87),
                    _buildBreakdownRow('Platform Fee', breakdown['platformFee'] ?? 0, Colors.orange),
                    const Divider(),
                    _buildBreakdownRow('You Pay', breakdown['totalAmount'] ?? 0, Colors.green, isBold: true),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${caregiverName} receives: KES ${(breakdown['caregiverEarning'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Pay KES ${breakdown['totalAmount']?.toStringAsFixed(2) ?? amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
