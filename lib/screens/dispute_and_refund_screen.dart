import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/payment_firestore_service.dart';
import '../Models/payment_model.dart';

/// Screen for handling payment disputes and initiating refunds
class DisputeAndRefundScreen extends StatefulWidget {
  final PaymentTransaction? transaction;
  final String? transactionId;

  const DisputeAndRefundScreen({
    Key? key,
    this.transaction,
    this.transactionId,
  }) : super(key: key);

  @override
  State<DisputeAndRefundScreen> createState() => _DisputeAndRefundScreenState();
}

class _DisputeAndRefundScreenState extends State<DisputeAndRefundScreen> {
  late final PaymentFirestoreService _paymentService;
  late Future<PaymentTransaction?> _transactionFuture;

  final _reasonController = TextEditingController();
  final _detailsController = TextEditingController();
  String _selectedReason = 'service_not_provided';
  bool _isSubmitting = false;

  final List<String> _refundReasons = [
    'service_not_provided',
    'service_incomplete',
    'quality_issue',
    'fraud_suspicion',
    'duplicate_charge',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentFirestoreService();

    if (widget.transaction != null) {
      _transactionFuture = Future.value(widget.transaction);
    } else {
      _transactionFuture =
          _paymentService.getTransaction(widget.transactionId ?? '');
    }
  }

  Future<void> _submitDispute(PaymentTransaction transaction) async {
    if (_selectedReason.isEmpty) {
      _showError('Please select a reason for the dispute');
      return;
    }

    if (_detailsController.text.isEmpty) {
      _showError('Please provide details about the dispute');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      // Create dispute record
      final disputeId = 'dispute_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance
          .collection('disputes')
          .doc(disputeId)
          .set({
        'transactionId': transaction.id,
        'transactionReference': transaction.reference,
        'clientId': transaction.clientId,
        'caregiverId': transaction.caregiverId,
        'amount': transaction.amount,
        'reason': _selectedReason,
        'details': _detailsController.text,
        'initiatedBy': currentUser.uid,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Audit log
      await _paymentService.logAuditEvent(
        userId: currentUser.uid,
        eventType: 'refund',
        resource: 'dispute',
        resourceId: disputeId,
        action: 'created',
        details:
            'Dispute filed for transaction ${transaction.reference}: $_selectedReason',
        changes: {
          'reason': _selectedReason,
          'details': _detailsController.text,
        },
      );

      if (mounted) {
        _showSuccess(
          'Dispute submitted successfully!\n\nReference: $disputeId\n\nOur team will review this within 24-48 hours.',
        );

        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context, {'success': true, 'disputeId': disputeId});
        });
      }
    } catch (e) {
      _showError('Failed to submit dispute: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade400,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getReasonLabel(String reason) {
    final labels = {
      'service_not_provided': 'Service Not Provided',
      'service_incomplete': 'Service Incomplete',
      'quality_issue': 'Quality Issue',
      'fraud_suspicion': 'Suspected Fraud',
      'duplicate_charge': 'Duplicate Charge',
      'other': 'Other',
    };
    return labels[reason] ?? reason;
  }

  String _getReasonDescription(String reason) {
    final descriptions = {
      'service_not_provided':
          'The caregiver did not provide the service as agreed',
      'service_incomplete': 'The service was only partially completed',
      'quality_issue': 'The quality of service was significantly below standard',
      'fraud_suspicion':
          'I have reason to believe this payment was fraudulent',
      'duplicate_charge': 'This payment appears to be a duplicate charge',
      'other': 'Something else',
    };
    return descriptions[reason] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File a Dispute'),
        elevation: 0,
      ),
      body: FutureBuilder<PaymentTransaction?>(
        future: _transactionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  const Text('Transaction not found'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final transaction = snapshot.data!;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== TRANSACTION INFO =====
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Details',
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Reference', transaction.reference),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Amount',
                            'KES ${transaction.amount.toStringAsFixed(2)}',
                            isBold: true,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Date',
                            _formatDate(transaction.createdAt),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Caregiver ID',
                            transaction.caregiverId,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== WARNING BANNER =====
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.amber.shade700,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Filing a false dispute is a serious matter and may result in account suspension.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber.shade900,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== DISPUTE FORM =====
                  Text(
                    'Dispute Reason',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Reason dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedReason,
                    decoration: InputDecoration(
                      labelText: 'Select reason',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _refundReasons
                        .map((reason) => DropdownMenuItem(
                              value: reason,
                              child: Text(_getReasonLabel(reason)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedReason = value ?? 'service_not_provided');
                    },
                  ),

                  const SizedBox(height: 12),

                  // Reason description
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      _getReasonDescription(_selectedReason),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== DETAILS SECTION =====
                  Text(
                    'Dispute Details',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _detailsController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: 'Please provide detailed information...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText:
                          'Explain what happened, when it happened, and any relevant details',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== INFO BOX =====
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What happens next?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoPoint(
                          '1. Review',
                          'Our team will review your dispute within 24-48 hours',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoPoint(
                          '2. Investigation',
                          'We may contact both parties to gather more information',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoPoint(
                          '3. Resolution',
                          'We will notify you of the outcome and any refund decision',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ===== ACTION BUTTONS =====
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submitDispute(transaction),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                )
                              : const Text('File Dispute'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPoint(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle,
            size: 16, color: Colors.green.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _detailsController.dispose();
    super.dispose();
  }
}
