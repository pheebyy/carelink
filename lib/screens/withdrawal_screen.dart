import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_firestore_service.dart';
import '../models/payment_model.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _auth = FirebaseAuth.instance;
  final _paymentService = PaymentFirestoreService();
  final _amountController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();

  String _selectedBank = 'KCB Bank';
  final _banks = [
    'KCB Bank',
    'Equity Bank',
    'NCBA Bank',
    'Co-operative Bank',
    'ABSA Bank',
    'Standard Chartered Bank',
    'Family Bank',
    'I&M Bank',
    'Safaricom M-Pesa',
    'Airtel Money',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Withdrawal'),
        centerTitle: true,
      ),
      body: StreamBuilder<CaregiverWallet?>(
        stream: _paymentService.streamCaregiverWallet(user.uid),
        builder: (context, walletSnapshot) {
          if (walletSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final wallet = walletSnapshot.data;
          if (wallet == null) {
            return Center(
              child: Text('Wallet not found'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available balance card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Balance',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KES ${wallet.balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Amount input
                Text(
                  'Withdrawal Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: 'KES ',
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText: 'Minimum: KES 500',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 4),
                _buildAmountInfo(wallet.balance),
                const SizedBox(height: 24),

                // Bank selection
                Text(
                  'Select Bank / Payment Method',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedBank,
                    isExpanded: true,
                    underline: const SizedBox(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: _banks.map((bank) {
                      return DropdownMenuItem<String>(
                        value: bank,
                        child: Text(bank),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBank = value ?? 'KCB Bank';
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Account details
                Text(
                  'Account Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _accountNameController,
                  decoration: InputDecoration(
                    hintText: 'Account Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountNumberController,
                  decoration: InputDecoration(
                    hintText: _selectedBank == 'Safaricom M-Pesa'
                        ? 'Phone Number'
                        : _selectedBank == 'Airtel Money'
                            ? 'Phone Number'
                            : 'Account Number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),

                // Withdrawal summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryRow(
                        'Amount',
                        'KES ${_amountController.text.isEmpty ? '0.00' : double.parse(_amountController.text).toStringAsFixed(2)}',
                      ),
                      const Divider(height: 16),
                      _buildSummaryRow(
                        'Processing Fee',
                        'KES 0.00',
                        isGrey: true,
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'You will receive',
                        'KES ${_amountController.text.isEmpty ? '0.00' : double.parse(_amountController.text).toStringAsFixed(2)}',
                        isBold: true,
                        isGreen: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '⏱️ Processing usually takes 1-24 hours',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isFormValid(wallet.balance)
                        ? () => _submitWithdrawal(wallet)
                        : null,
                    child: const Text(
                      'Request Withdrawal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmountInfo(double balance) {
    final amount = _amountController.text.isEmpty
        ? 0.0
        : double.tryParse(_amountController.text) ?? 0.0;

    String message = '';
    Color color = Colors.grey;

    if (amount < 500 && amount > 0) {
      message = 'Minimum withdrawal is KES 500';
      color = Colors.orange;
    } else if (amount > balance) {
      message = 'Amount exceeds available balance';
      color = Colors.red;
    } else if (amount >= 500 && amount <= balance) {
      message = 'Valid amount';
      color = Colors.green;
    }

    return Text(
      message,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isGreen = false,
    bool isGrey = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isGrey ? Colors.grey.shade600 : Colors.grey.shade800,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isGreen ? Colors.green : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  bool _isFormValid(double balance) {
    final amount = _amountController.text.isEmpty
        ? 0.0
        : double.tryParse(_amountController.text);

    return amount != null &&
        amount >= 500 &&
        amount <= balance &&
        _accountNameController.text.isNotEmpty &&
        _accountNumberController.text.isNotEmpty;
  }

  Future<void> _submitWithdrawal(CaregiverWallet wallet) async {
    final amount = double.parse(_amountController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmRow('Amount', 'KES ${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildConfirmRow('Bank', _selectedBank),
            const SizedBox(height: 8),
            _buildConfirmRow('Account', _accountNameController.text),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Processing usually takes 1-24 hours. You will receive a confirmation email once the transfer is complete.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () {
              Navigator.pop(context);
              _completeWithdrawal(amount);
            },
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _completeWithdrawal(double amount) async {
    try {
      // TODO: Implement withdrawal request creation in Firestore
      // Create withdrawal request document with pending status
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Withdrawal of KES ${amount.toStringAsFixed(2)} requested successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
