import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/paystack_service.dart';
import 'card_payment_screen.dart';
import 'mpesa_payment_screen.dart';
import 'saved_cards_screen.dart';

/// Modern payment method selection screen
class PaymentMethodScreen extends StatefulWidget {
  final double amount;
  final String paymentType;
  final Map<String, dynamic>? metadata;
  final String? email;

  const PaymentMethodScreen({
    Key? key,
    required this.amount,
    this.paymentType = 'client_payment',
    this.metadata,
    this.email,
  }) : super(key: key);

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final _paystackService = PaystackService();
  List<Map<String, dynamic>> _savedCards = [];
  String? _userEmail;
  bool _isLoadingCards = true;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    // Get user email
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userEmail = widget.email ?? user?.email ?? '';
    });

    // Load saved cards
    if (user != null) {
      await _loadSavedCards(user.uid);
    } else {
      setState(() => _isLoadingCards = false);
    }
  }

  Future<void> _loadSavedCards(String userId) async {
    try {
      setState(() => _isLoadingCards = true);
      final cards = await _paystackService.getSavedCards(userId);
      if (mounted) {
        setState(() {
          _savedCards = cards;
          _isLoadingCards = false;
        });
      }
    } catch (e) {
      print('Error loading cards: $e');
      if (mounted) {
        setState(() => _isLoadingCards = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.amount + _paystackService.calculateClientFee(widget.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Method'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Amount Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Amount to Pay',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'KSh ${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: KSh ${widget.amount.toStringAsFixed(2)} + Fee: KSh ${_paystackService.calculateClientFee(widget.amount).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildPaymentSummary(totalAmount),
                const SizedBox(height: 20),

                // Saved Cards Section
                const Text(
                  'Saved Cards',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isLoadingCards)
                  const Center(child: CircularProgressIndicator())
                else if (_savedCards.isEmpty)
                  _buildEmptySavedCardState()
                else ...[
                  ..._savedCards.map((card) => _buildSavedCardTile(card)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _navigateToSavedCards,
                      icon: const Icon(Icons.settings),
                      label: const Text('Manage Cards'),
                    ),
                  ),
                ],
                const Divider(height: 32),

                const Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // M-Pesa Option
                _buildPaymentMethodCard(
                  icon: Icons.phone_android,
                  iconColor: Colors.green,
                  title: 'M-Pesa',
                  subtitle: 'Pay instantly with your phone',
                  helperText: 'We will send an STK push from Paystack to your Safaricom line.',
                  statusLabel: 'Live',
                  statusColor: Colors.green,
                  onTap: () => _navigateToMpesa(),
                ),

                const SizedBox(height: 12),

                // Card Payment Option
                _buildPaymentMethodCard(
                  icon: Icons.credit_card,
                  iconColor: Colors.blue,
                  title: 'Debit/Credit Card',
                  subtitle: 'Visa, Mastercard, Verve',
                  helperText: 'Secure Paystack checkout opens in-app. No card data stored on this device.',
                  statusLabel: _savedCards.isEmpty ? null : 'Save tokens',
                  statusColor: Colors.blue,
                  onTap: () => _navigateToCardPayment(),
                ),

                const SizedBox(height: 12),

                // Bank Transfer Option
                _buildPaymentMethodCard(
                  icon: Icons.account_balance,
                  iconColor: Colors.purple,
                  title: 'Bank Transfer',
                  subtitle: 'Direct bank transfer',
                  helperText: 'Manual settlement coming soon. Use M-Pesa or card for now.',
                  statusLabel: 'Soon',
                  statusColor: Colors.purple,
                  enabled: false,
                  onTap: () => _showComingSoon('Bank Transfer'),
                ),

                const SizedBox(height: 24),

                // Security Notice
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your payment is secured by Paystack with bank-level encryption',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCardTile(Map<String, dynamic> card) {
    final cardType = card['cardType'] ?? 'Card';
    final last4 = card['last4'] ?? '****';
    final expiry = '${card['expiryMonth']}/${card['expiryYear']}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(
            _getCardIcon(cardType),
            color: Colors.blue.shade700,
          ),
        ),
        title: Text('$cardType •••• $last4'),
        subtitle: Text('Expires $expiry'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _payWithSavedCard(card),
      ),
    );
  }

  Widget _buildEmptySavedCardState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No saved cards yet',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Save a card the next time you pay with card to enable one-tap payments.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _navigateToCardPayment,
            icon: const Icon(Icons.credit_card),
            label: const Text('Pay with new card'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? helperText,
    String? statusLabel,
    Color? statusColor,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (statusLabel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor ?? Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (helperText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        helperText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: enabled ? Colors.grey.shade400 : Colors.grey.shade300,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummary(double totalAmount) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount'),
                Text('KSh ${widget.amount.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Processing Fee'),
                Text('KSh ${_paystackService.calculateClientFee(widget.amount).toStringAsFixed(2)}'),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'KSh ${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCardIcon(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  void _navigateToMpesa() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MpesaPaymentScreen(
          amount: widget.amount,
          email: _userEmail ?? '',
          paymentType: widget.paymentType,
          metadata: widget.metadata,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  void _navigateToCardPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardPaymentScreen(
          amount: widget.amount,
          email: _userEmail ?? '',
          paymentType: widget.paymentType,
          metadata: widget.metadata,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  void _navigateToSavedCards() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedCardsScreen(userId: user.uid),
      ),
    ).then((_) => _loadSavedCards(user.uid));
  }

  void _payWithSavedCard(Map<String, dynamic> card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Pay KSh ${widget.amount.toStringAsFixed(2)} with ${card['cardType']} •••• ${card['last4']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      final result = await _paystackService.chargeSavedCard(
        userId: user!.uid,
        authorizationCode: card['authorizationCode'],
        amount: widget.amount,
        type: widget.paymentType,
      );

      Navigator.pop(context); // Close loading

      if (result != null && result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payment successful!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showError('Payment failed. Please try again.');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      _showError('Error processing payment: $e');
    }
  }

  void _showComingSoon(String method) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$method coming soon!')),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
