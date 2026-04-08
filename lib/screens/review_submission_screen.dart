import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/Job_model.dart';
import '../services/job_service.dart';

class ReviewSubmissionScreen extends StatefulWidget {
  final JobModel job;

  const ReviewSubmissionScreen({
    Key? key,
    required this.job,
  }) : super(key: key);

  @override
  State<ReviewSubmissionScreen> createState() => _ReviewSubmissionScreenState();
}

class _ReviewSubmissionScreenState extends State<ReviewSubmissionScreen> {
  final _jobService = JobService();
  final _commentController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitting = false;
  bool _hasReviewed = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyReviewed();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkIfAlreadyReviewed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final hasReviewed = await _jobService.hasUserReviewedJob(widget.job.id, uid);
      if (mounted) {
        setState(() => _hasReviewed = hasReviewed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isCaregiver = uid == widget.job.caregiverId;

    if (_hasReviewed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                'Review Already Submitted',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thank you for your feedback!',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Leave a Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job info
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Job: ${widget.job.title}',
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isCaregiver ? 'Your Client' : 'Your Caregiver',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Star Rating
            Text(
              'Rate Your Experience',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),

            Center(
              child: Column(
                children: [
                  // Star display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = (index + 1).toDouble();
                      final isFilled = starValue <= _rating;
                      final isHalf = starValue - 0.5 == _rating;

                      return GestureDetector(
                        onTapDown: (details) {
                          final box = context.findRenderObject() as RenderBox;
                          final localPosition = box.globalToLocal(details.globalPosition);
                          final starPosition = localPosition.dx;
                          final starWidth = box.size.width / 5;

                          if (starPosition % starWidth < starWidth / 2) {
                            setState(() => _rating = starValue - 0.5);
                          } else {
                            setState(() => _rating = starValue);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            isFilled
                                ? Icons.star
                                : isHalf
                                    ? Icons.star_half
                                    : Icons.star_outline,
                            size: 50,
                            color: isFilled || isHalf ? Colors.amber : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getRatingLabel(_rating),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Comment
            Text(
              'Share Your Experience',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please provide constructive feedback (minimum 10 characters)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _commentController,
              maxLines: 5,
              minLines: 4,
              maxLength: 500,
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tell us about your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
                helperText:
                    '${_commentController.text.length}/500 characters',
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isFormValid() && !_isSubmitting ? _submitReview : null,
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
                        'Submit Review',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Info
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
                      'Your honest feedback helps build trust in the community. Be professional and fair.',
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

  bool _isFormValid() {
    return _commentController.text.trim().length >= 10;
  }

  String _getRatingLabel(double rating) {
    if (rating < 2) return 'Poor';
    if (rating < 3) return 'Fair';
    if (rating < 4) return 'Good';
    if (rating < 5) return 'Very Good';
    return 'Excellent';
  }

  Future<void> _submitReview() async {
    if (!_isFormValid()) return;

    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final isCaregiver = uid == widget.job.caregiverId;
      final revieweeId = isCaregiver ? widget.job.clientId : widget.job.caregiverId!;
      final reviewerRole = isCaregiver ? 'caregiver' : 'client';

      await _jobService.submitReview(
        jobId: widget.job.id,
        reviewerId: uid,
        revieweeId: revieweeId,
        reviewerRole: reviewerRole,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
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
}
