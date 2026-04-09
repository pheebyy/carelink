import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/paystack_service.dart';
import '../Models/payment_model.dart';

class RefundRequestScreen extends StatefulWidget {
  final PaymentTransaction transaction;

  const RefundRequestScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends State<RefundRequestScreen> {
  final _reasonController = TextEditingController();
  final _detailsController = TextEditingController();
  final _paystackService = PaystackService();
  final _auth = FirebaseAuth.instance;

  bool _isProcessing = false;
  String? _selectedReason;

  final _refundReasons = [
    'Payment Made by Mistake',
    'Duplicate Charge',
    'Service Not Provided',
    'Amount Incorrect',
    'Unauthorized Transaction',
    'Other',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    return _selectedReason != null &&
        _selectedReason!.isNotEmpty &&
        _detailsController.text.isNotEmpty &&
        _detailsController.text.length >= 20;
  }

  Future<void> _submitRefundRequest() async {
    if (!_isFormValid()) {
      _showError('Please fill in all required fields');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final result = await _paystackService.initiateRefund(
        reference: widget.transaction.reference,
        reason: '$_selectedReason: ${_detailsController.text}',
      );

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        _showSuccess(
          'Refund Request Submitted',
          'Your refund has been initiated. The amount KES ${widget.transaction.amount.toStringAsFixed(2)} will be credited within 5-7 business days.',
        );

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        throw Exception(result?['message'] ?? 'Refund request failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Refund'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction Details
            Container(
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
                    'Transaction Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Reference',
                    widget.transaction.reference,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Amount',
                    'KES ${widget.transaction.amount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Status',
                    widget.transaction.status.toUpperCase(),
                    valueColor: _getStatusColor(widget.transaction.status),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Date',
                    _formatDate(widget.transaction.createdAt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Refund Reason
            Text(
              'Refund Reason',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButton<String>(
                value: _selectedReason,
                isExpanded: true,
                underline: const SizedBox(),
                hint: const Text('Select reason for refund'),
                items: _refundReasons
                    .map((reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedReason = value);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Details
            Text(
              'Details (minimum 20 characters)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Provide details about why you need this refund...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_detailsController.text.length}/500 characters',
              style: TextStyle(
                fontSize: 12,
                color: _detailsController.text.length >= 20
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            const SizedBox(height: 24),

            // Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade600, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Refunds typically process within 5-7 business days. You will receive a confirmation email.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (!_isFormValid() || _isProcessing) ? null : _submitRefundRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                        'Submit Refund Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
