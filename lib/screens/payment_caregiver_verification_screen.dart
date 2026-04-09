import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/Job_model.dart';
import '../services/payment_firestore_service.dart';

/// Screen to verify payment recipient (caregiver) before processing payment
class PaymentCaregiverVerificationScreen extends StatefulWidget {
  final JobModel job;
  final String caregiverId;

  const PaymentCaregiverVerificationScreen({
    Key? key,
    required this.job,
    required this.caregiverId,
  }) : super(key: key);

  @override
  State<PaymentCaregiverVerificationScreen> createState() =>
      _PaymentCaregiverVerificationScreenState();
}

class _PaymentCaregiverVerificationScreenState
    extends State<PaymentCaregiverVerificationScreen> {
  late Future<Map<String, dynamic>> _caregiverFuture;
  bool _confirmed = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _caregiverFuture = _loadCaregiverDetails();
  }

  Future<Map<String, dynamic>> _loadCaregiverDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.caregiverId)
          .get();
      
      if (doc.exists) {
        return doc.data() ?? {};
      }
      return {};
    } catch (e) {
      print('Error loading caregiver details: $e');
      return {};
    }
  }

  Future<void> _confirmAndProceed() async {
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm the caregiver details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Create payment transaction
      final paymentService = PaymentFirestoreService();
      final reference = 'job_${widget.job.id}_${DateTime.now().millisecondsSinceEpoch}';

      final transaction = await paymentService.createTransaction(
        clientId: currentUser.uid,
        caregiverId: widget.caregiverId,
        amount: (widget.job.budget ?? 0).toDouble(),
        reference: reference,
        metadata: {
          'jobId': widget.job.id,
          'jobTitle': widget.job.title,
          'caregiverName': widget.job.careType,
          'verified': true,
          'verifiedAt': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payment verified and ready for processing'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to payment method selection with verified transaction
        Navigator.of(context).pop({'verified': true, 'transaction': transaction});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Caregiver'),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _caregiverFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  const Text('Unable to load caregiver details'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final caregiver = snapshot.data!;
          final name = caregiver['firstName'] ?? 'Unknown';
          final avatar = caregiver['profilePicture'];
          final email = caregiver['email'] ?? '';
          final phone = caregiver['phone'] ?? '';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== CAREGIVER INFO CARD =====
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: avatar != null
                                ? NetworkImage(avatar)
                                : null,
                            backgroundColor: Colors.blue.shade100,
                            child: avatar == null
                                ? Icon(Icons.person,
                                    size: 50,
                                    color: Colors.blue.shade700)
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Name
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          // Email & Phone
                          const SizedBox(height: 12),
                          if (email.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.email,
                                    size: 16,
                                    color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                          if (phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.phone,
                                      size: 16,
                                      color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== JOB DETAILS =====
                  Text(
                    'Job Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    elevation: 0,
                    color: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Title', widget.job.title),
                          const SizedBox(height: 12),
                          _buildDetailRow('Type', widget.job.careType.toUpperCase()),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Amount',
                            'KES ${widget.job.budget?.toStringAsFixed(2) ?? '0.00'}',
                            isBold: true,
                            color: Colors.green,
                          ),
                          if (widget.job.location != null) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow('Location', widget.job.location!),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== VERIFICATION EXPLANATION =====
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info,
                            color: Colors.blue.shade700,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Please verify that you are paying the correct caregiver. Once confirmed, the payment will be processed to their account only.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== CONFIRMATION CHECKBOX =====
                  CheckboxListTile(
                    value: _confirmed,
                    onChanged: (value) {
                      setState(() => _confirmed = value ?? false);
                    },
                    title: const Text(
                      'I confirm this is the correct caregiver',
                      style: TextStyle(fontSize: 14),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  const SizedBox(height: 32),

                  // ===== ACTION BUTTONS =====
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessing
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing
                              ? null
                              : _confirmAndProceed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          child: _isProcessing
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
                              : const Text('Confirm Payment'),
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

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, Color? color}) {
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
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
