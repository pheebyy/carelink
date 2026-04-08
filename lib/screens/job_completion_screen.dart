import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Models/Job_model.dart';
import '../services/job_service.dart';
import 'review_submission_screen.dart';

class JobCompletionScreen extends StatefulWidget {
  final JobModel job;

  const JobCompletionScreen({
    Key? key,
    required this.job,
  }) : super(key: key);

  @override
  State<JobCompletionScreen> createState() => _JobCompletionScreenState();
}

class _JobCompletionScreenState extends State<JobCompletionScreen> {
  final _jobService = JobService();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final startDate = widget.job.startDate?.toDate();
    final endDate = widget.job.endDate?.toDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Job'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Details Summary
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.job.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Amount', 'KES ${widget.job.budget ?? 0}', Colors.green),
                    const SizedBox(height: 8),
                    _buildDetailRow('Type', widget.job.careType, Colors.blue),
                    if (widget.job.location != null && widget.job.location!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Location', widget.job.location!, Colors.purple),
                    ],
                    if (startDate != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Started',
                        dateFormat.format(startDate),
                        Colors.orange,
                      ),
                    ],
                    if (endDate != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Scheduled to End',
                        dateFormat.format(endDate),
                        Colors.red,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Completion Status
            Text(
              'Completion Status',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),

            // Your confirmation status
            _buildConfirmationCard(
              title: 'Your Status',
              isConfirmed: widget.job.caregiverConfirmedCompletion,
              role: 'Caregiver',
            ),

            const SizedBox(height: 12),

            // Client confirmation status
            _buildConfirmationCard(
              title: 'Client Status',
              isConfirmed: widget.job.clientConfirmedCompletion,
              role: 'Client',
            ),

            const SizedBox(height: 24),

            // Completion Notes
            Text(
              'Completion Notes (Optional)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add any notes about the job completion (e.g., what was done, any issues)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if (!widget.job.caregiverConfirmedCompletion) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting ? null : _confirmCompletion,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirm Job Completion',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You have confirmed completion. Waiting for client confirmation.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Show review button if both confirmed
              if (widget.job.clientConfirmedCompletion) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _goToReviewScreen,
                    child: const Text(
                      'Write a Review',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 12),

            // Info message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Both you and the client must confirm job completion for it to be finalized.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha((0.2 * 255).toInt()),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationCard({
    required String title,
    required bool isConfirmed,
    required String role,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConfirmed ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConfirmed ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConfirmed ? Icons.check_circle : Icons.schedule,
            color: isConfirmed ? Colors.green : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  isConfirmed ? '$role has confirmed' : '$role has not confirmed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isConfirmed ? Colors.green : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCompletion() async {
    setState(() => _isSubmitting = true);

    try {
      await _jobService.confirmCompletion(widget.job.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job completion confirmed! Waiting for client confirmation.'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the screen
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _goToReviewScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSubmissionScreen(job: widget.job),
      ),
    );
  }
}
