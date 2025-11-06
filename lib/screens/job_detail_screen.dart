import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _fs = FirestoreService();
  final _msgCtrl = TextEditingController();
  final _bidAmountCtrl = TextEditingController();
  final _proposalCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  
  bool _hasPlacedBid = false;

  @override
  void initState() {
    super.initState();
    _checkIfUserHasBid();
  }

  Future<void> _checkIfUserHasBid() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final hasBid = await _fs.hasUserBidOnJob(widget.jobId, uid);
      if (mounted) {
        setState(() => _hasPlacedBid = hasBid);
      }
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _bidAmountCtrl.dispose();
    _proposalCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _showBidDialog() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Place Your Bid'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _bidAmountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bid Amount (₦)',
                  hintText: 'Enter your bid amount',
                  prefixText: '₦',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _durationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Estimated Duration (hours)',
                  hintText: 'How long will it take?',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _proposalCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Proposal',
                  hintText: 'Why should the client choose you?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 500,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_bidAmountCtrl.text.trim());
              final duration = int.tryParse(_durationCtrl.text.trim());
              final proposal = _proposalCtrl.text.trim();

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid bid amount')),
                );
                return;
              }

              if (proposal.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your proposal')),
                );
                return;
              }

              try {
                await _fs.createBid(
                  jobId: widget.jobId,
                  caregiverId: uid,
                  amount: amount,
                  proposal: proposal,
                  estimatedDuration: duration,
                );

                if (mounted) {
                  Navigator.pop(context);
                  setState(() => _hasPlacedBid = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bid placed successfully!')),
                  );
                  _bidAmountCtrl.clear();
                  _proposalCtrl.clear();
                  _durationCtrl.clear();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Submit Bid'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _fs.jobStream(widget.jobId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final job = snapshot.data!.data();
          if (job == null) {
            return const Center(child: Text('Job not found'));
          }

          final isClient = job['clientId'] == uid;
          final isOpen = (job['status'] ?? '').toLowerCase() == 'open';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Job Header
                      _buildJobHeader(job),
                      const Divider(height: 32),
                      
                      // Bids Section (visible to both client and caregivers)
                      _buildBidsSection(job, uid, isClient),
                      
                      const Divider(height: 32),
                      
                      // Messages Section
                      _buildMessagesSection(uid),
                    ],
                  ),
                ),
              ),
              
              // Bottom Actions
              SafeArea(
                child: _buildBottomActions(isClient, isOpen, uid),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJobHeader(Map<String, dynamic> job) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job['title'] ?? 'Untitled Job',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(job['status'] ?? 'unknown'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              job['description'] ?? 'No description',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.category, 'Type: ${job['careType'] ?? 'N/A'}'),
                if (job['budget'] != null)
                  _buildInfoChip(Icons.attach_money, 'Budget: ₦${job['budget']}'),
                if (job['location'] != null)
                  _buildInfoChip(Icons.location_on, job['location']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor = Colors.grey;
    String displayStatus = status.toUpperCase();
    
    switch (status.toLowerCase()) {
      case 'open':
        bgColor = Colors.green;
        break;
      case 'assigned':
        bgColor = Colors.blue;
        break;
      case 'completed':
        bgColor = Colors.purple;
        break;
      case 'closed':
        bgColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: bgColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildBidsSection(Map<String, dynamic> job, String? uid, bool isClient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bids',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (!isClient && !_hasPlacedBid && job['status'] == 'open')
              TextButton.icon(
                onPressed: _showBidDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Place Bid'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _fs.jobBidsStream(widget.jobId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final bids = snapshot.data!.docs;
            
            if (bids.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'No bids yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bids.length,
              itemBuilder: (context, index) {
                final bid = bids[index].data();
                final bidId = bids[index].id;
                return _buildBidCard(bid, bidId, isClient);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBidCard(Map<String, dynamic> bid, String bidId, bool isClient) {
    final status = bid['status'] ?? 'pending';
    final amount = bid['amount'] ?? 0.0;
    final proposal = bid['proposal'] ?? '';
    final duration = bid['estimatedDuration'];
    final caregiverId = bid['caregiverId'];
    
    Color statusColor = Colors.orange;
    if (status == 'approved') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₦${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (duration != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Estimated: $duration hours',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              proposal,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
            
            // Approve/Reject buttons (only for client and pending bids)
            if (isClient && status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await _fs.rejectBid(widget.jobId, bidId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bid rejected')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _fs.approveBid(widget.jobId, bidId, caregiverId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bid approved! Caregiver assigned.')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesSection(String? uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Messages',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _fs.messagesStream(widget.jobId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final msgs = snap.data!.docs;
              if (msgs.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: msgs.length,
                itemBuilder: (context, index) {
                  final m = msgs[index].data();
                  final isMe = m['senderId'] == uid;
                  final ts = m['timestamp'];
                  final time = ts is Timestamp ? ts.toDate() : null;
                  
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.green.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['text'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (time != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(bool isClient, bool isOpen, String? uid) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.green,
            onPressed: () async {
              final text = _msgCtrl.text.trim();
              if (text.isEmpty || uid == null) return;
              
              try {
                await _fs.sendMessage(
                  jobId: widget.jobId,
                  senderId: uid,
                  text: text,
                );
                _msgCtrl.clear();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
