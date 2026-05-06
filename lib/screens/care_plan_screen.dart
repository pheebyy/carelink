import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

// ---------------------------------------------------------------------------
// ViewModel — keeps all business logic out of the widget tree
// ---------------------------------------------------------------------------
class CarePlanViewModel extends ChangeNotifier {
  CarePlanViewModel({required this.uid, required FirestoreService fs}) : _fs = fs;

  final String uid;
  final FirestoreService _fs;

  static const Set<String> allowedFrequencies = {
    'daily',
    'weekly',
    'weekdays',
    'monthly',
    'as needed',
  };

  static const List<MapEntry<String, String>> frequencyOptions = [
    MapEntry('', 'None'),
    MapEntry('daily', 'Daily'),
    MapEntry('weekly', 'Weekly'),
    MapEntry('weekdays', 'Weekdays'),
    MapEntry('monthly', 'Monthly'),
    MapEntry('as needed', 'As needed'),
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> get carePlansStream =>
      _fs.carePlansStream(uid);

  String? validateInputs({
    required String type,
    required String title,
    required String description,
    required String time,
    required String frequency,
  }) {
    if (title.trim().isEmpty) return 'Please enter a title';
    if (description.trim().length > 280) {
      return 'Description is too long (max 280 characters)';
    }
    if (type == 'medication' && time.trim().isEmpty) {
      return 'Medication items require a reminder time';
    }
    final normalizedFrequency = frequency.trim().toLowerCase();
    if (normalizedFrequency.isNotEmpty &&
        !allowedFrequencies.contains(normalizedFrequency)) {
      return 'Frequency must be: Daily, Weekly, Weekdays, Monthly, or As needed';
    }
    return null;
  }

  String friendlyError(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
          return 'Service is temporarily unavailable. Please try again in a moment.';
        case 'network-request-failed':
          return 'No internet connection. Check your network and try again.';
        case 'deadline-exceeded':
          return 'The request took too long. Please try again.';
        case 'not-found':
          return 'The item could not be found. It may have been removed.';
        default:
          return fallback;
      }
    }
    final msg = error.toString().toLowerCase();
    if (msg.contains('permission-denied')) {
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('timeout')) {
      return 'No internet connection. Check your network and try again.';
    }
    return fallback;
  }

  Future<void> createCarePlan({
    required String type,
    required String title,
    required String description,
    String? time,
    String? frequency,
  }) async {
    await _fs.createCarePlan(
      clientId: uid,
      type: type,
      title: title,
      description: description,
      time: time,
      frequency: frequency,
    );
    await _syncNotifications();
  }

  Future<void> updateCarePlan(
    String planId,
    Map<String, dynamic> data,
  ) async {
    await _fs.updateCarePlan(uid, planId, data);
    await _syncNotifications();
  }

  Future<void> deleteCarePlan(String planId) async {
    await _fs.deleteCarePlan(uid, planId);
    await _syncNotifications();
  }

  Future<void> toggleCompletion(String planId, bool value) async {
    await _fs.toggleCarePlanCompletion(uid, planId, value);
    await _syncNotifications();
  }

  Future<void> _syncNotifications() async {
    try {
      await NotificationService.instance.syncMedicationRemindersForUser(uid);
    } catch (e) {
      // Notification sync is best-effort; log but don't surface to user.
      debugPrint('[CarePlanViewModel] Notification sync failed: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class CarePlanScreen extends StatefulWidget {
  const CarePlanScreen({super.key});

  @override
  State<CarePlanScreen> createState() => _CarePlanScreenState();
}

class _CarePlanScreenState extends State<CarePlanScreen> {
  late final CarePlanViewModel _vm;
  bool _authReady = false;

  @override
  void initState() {
    super.initState();
    // Resolve UID at init time via a stream so auth-state changes are caught.
    FirebaseAuth.instance.authStateChanges().first.then((user) {
      if (!mounted) return;
      if (user != null) {
        setState(() {
          _vm = CarePlanViewModel(uid: user.uid, fs: FirestoreService());
          _authReady = true;
        });
      } else {
        setState(() => _authReady = true); // authReady but no user
      }
    });
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade600 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_authReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ignore: use_late_for_private_fields_and_variables
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Care Plan'),
          backgroundColor: Colors.green,
        ),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Care Plan'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Care Plan Item',
            onPressed: () => _showCarePlanDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _vm.carePlansStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade400, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      _vm.friendlyError(
                        snapshot.error ?? Exception('Unknown error'),
                        fallback:
                            'Unable to load your care plan right now. Please try again.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    // The stream auto-recovers; this button is just reassuring UX.
                    TextButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            );
          }

          final carePlans = snapshot.data?.docs ?? [];

          if (carePlans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No care plans yet',
                    style: TextStyle(
                        fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showCarePlanDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Care Plan'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: carePlans.length,
            itemBuilder: (context, index) {
              final doc = carePlans[index];
              return _CarePlanCard(
                planId: doc.id,
                plan: doc.data(),
                vm: _vm,
                onEdit: () => _showCarePlanDialog(
                  planId: doc.id,
                  existing: doc.data(),
                ),
                onDeleteConfirm: () => _confirmDelete(
                  doc.id,
                  doc.data()['title'] ?? 'Untitled',
                ),
                onError: (msg) => _showMessage(msg, isError: true),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Unified add/edit dialog — extracted into its own StatefulWidget so that
  // TextEditingControllers are properly disposed when the dialog closes.
  // ---------------------------------------------------------------------------
  void _showCarePlanDialog({
    String? planId,
    Map<String, dynamic>? existing,
  }) {
    showDialog(
      context: context,
      builder: (_) => _CarePlanDialog(
        planId: planId,
        existing: existing,
        vm: _vm,
        onSuccess: (msg) => _showMessage(msg),
        onError: (msg) => _showMessage(msg, isError: true),
      ),
    );
  }

  void _confirmDelete(String planId, String title) {
    showDialog(
      context: context,
      builder: (_) => _DeleteDialog(
        planId: planId,
        title: title,
        vm: _vm,
        onSuccess: () => _showMessage('Care plan deleted'),
        onError: (msg) => _showMessage(msg, isError: true),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Care plan card — extracted to keep _CarePlanScreenState lean
// ---------------------------------------------------------------------------
class _CarePlanCard extends StatelessWidget {
  const _CarePlanCard({
    required this.planId,
    required this.plan,
    required this.vm,
    required this.onEdit,
    required this.onDeleteConfirm,
    required this.onError,
  });

  final String planId;
  final Map<String, dynamic> plan;
  final CarePlanViewModel vm;
  final VoidCallback onEdit;
  final VoidCallback onDeleteConfirm;
  final void Function(String) onError;

  static const _typeConfig = <String, (IconData, Color)>{
    'medication': (Icons.medication, Colors.blue),
    'goal': (Icons.trending_up, Colors.green),
    'appointment': (Icons.calendar_today, Colors.orange),
    'exercise': (Icons.fitness_center, Colors.purple),
  };

  @override
  Widget build(BuildContext context) {
    final type = plan['type'] ?? 'general';
    final title = plan['title'] ?? 'Untitled';
    final description = plan['description'] ?? '';
    final time = plan['time'] as String?;
    final frequency = plan['frequency'] as String?;
    final isCompleted = plan['isCompleted'] ?? false;

    final (icon, color) =
        _typeConfig[type] ?? (Icons.favorite, Colors.pink);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Completion checkbox
              Checkbox(
                value: isCompleted,
                activeColor: Colors.green,
                onChanged: (value) async {
                  try {
                    await vm.toggleCompletion(planId, value ?? false);
                  } catch (e) {
                    onError(vm.friendlyError(e,
                        fallback:
                            'Unable to update this item. Please try again.'));
                  }
                },
              ),
              const SizedBox(width: 12),
              // Type icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24,
                    semanticLabel: type),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompleted
                                  ? Colors.grey
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        // Edit affordance so tappability is obvious
                        Icon(Icons.edit_outlined,
                            size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ],
                    if (time != null || frequency != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (time != null) ...[
                            Icon(Icons.schedule,
                                size: 14,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              time,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                          if (time != null && frequency != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              child: Text('•',
                                  style: TextStyle(
                                      color: Colors.grey.shade400)),
                            ),
                          if (frequency != null)
                            Text(
                              frequency,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Delete button
              Semantics(
                label: 'Delete $title',
                child: IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red.shade400),
                  onPressed: onDeleteConfirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unified add / edit dialog — StatefulWidget so controllers are disposed
// ---------------------------------------------------------------------------
class _CarePlanDialog extends StatefulWidget {
  const _CarePlanDialog({
    this.planId,
    this.existing,
    required this.vm,
    required this.onSuccess,
    required this.onError,
  });

  final String? planId;
  final Map<String, dynamic>? existing;
  final CarePlanViewModel vm;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  bool get isEditing => planId != null;

  @override
  State<_CarePlanDialog> createState() => _CarePlanDialogState();
}

class _CarePlanDialogState extends State<_CarePlanDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _timeController;

  late String _selectedType;
  late String _selectedFrequency;
  bool _isSaving = false;

  // Character counter state
  int _descLength = 0;
  static const int _maxDescLength = 280;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?['title'] ?? '');
    _descriptionController =
        TextEditingController(text: e?['description'] ?? '');
    _timeController =
        TextEditingController(text: e?['time'] ?? '');
    _selectedType = e?['type'] ?? 'medication';
    final rawFreq =
        (e?['frequency'] ?? '').toString().toLowerCase().trim();
    _selectedFrequency =
        CarePlanViewModel.allowedFrequencies.contains(rawFreq)
            ? rawFreq
            : '';
    _descLength = _descriptionController.text.length;
    _descriptionController.addListener(() {
      if (mounted) setState(() => _descLength = _descriptionController.text.length);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    _timeController.text = picked.format(context);
  }

  Future<void> _submit() async {
    final validationError = widget.vm.validateInputs(
      type: _selectedType,
      title: _titleController.text,
      description: _descriptionController.text,
      time: _timeController.text,
      frequency: _selectedFrequency,
    );
    if (validationError != null) {
      widget.onError(validationError);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final time = _timeController.text.trim().isEmpty
          ? null
          : _timeController.text.trim();
      final frequency = _selectedFrequency.trim().isEmpty
          ? null
          : _selectedFrequency;

      if (widget.isEditing) {
        await widget.vm.updateCarePlan(widget.planId!, {
          'type': _selectedType,
          'title': title,
          'description': description,
          'time': time,
          'frequency': frequency,
        });
      } else {
        await widget.vm.createCarePlan(
          type: _selectedType,
          title: title,
          description: description,
          time: time,
          frequency: frequency,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess(
          widget.isEditing
              ? 'Care plan updated successfully'
              : 'Care plan added successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        widget.onError(widget.vm.friendlyError(
          e,
          fallback: widget.isEditing
              ? 'Unable to update care plan item. Please try again.'
              : 'Unable to add care plan item. Please try again.',
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverLimit = _descLength > _maxDescLength;
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Care Plan Item' : 'Add Care Plan Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'medication', child: Text('Medication')),
                DropdownMenuItem(value: 'goal', child: Text('Goal')),
                DropdownMenuItem(value: 'appointment', child: Text('Appointment')),
                DropdownMenuItem(value: 'exercise', child: Text('Exercise')),
                DropdownMenuItem(value: 'general', child: Text('General')),
              ],
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 16),
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Description with live counter
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: const OutlineInputBorder(),
                counterText: '$_descLength / $_maxDescLength',
                counterStyle: TextStyle(
                  color: isOverLimit ? Colors.red : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Time
            TextField(
              controller: _timeController,
              readOnly: true,
              onTap: _pickTime,
              decoration: const InputDecoration(
                labelText: 'Time (optional)',
                hintText: 'Tap to choose time',
                suffixIcon: Icon(Icons.access_time),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Frequency
            DropdownButtonFormField<String>(
              value: _selectedFrequency,
              decoration: const InputDecoration(
                labelText: 'Frequency (optional)',
                border: OutlineInputBorder(),
              ),
              items: CarePlanViewModel.frequencyOptions
                  .map((o) => DropdownMenuItem<String>(
                        value: o.key,
                        child: Text(o.value),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedFrequency = v ?? ''),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style:
              ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Delete confirmation dialog — also a StatefulWidget for loading state
// ---------------------------------------------------------------------------
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({
    required this.planId,
    required this.title,
    required this.vm,
    required this.onSuccess,
    required this.onError,
  });

  final String planId;
  final String title;
  final CarePlanViewModel vm;
  final VoidCallback onSuccess;
  final void Function(String) onError;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Care Plan'),
      content: Text('Are you sure you want to delete "${widget.title}"?'),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isDeleting
              ? null
              : () async {
                  setState(() => _isDeleting = true);
                  try {
                    await widget.vm.deleteCarePlan(widget.planId);
                    if (mounted) {
                      Navigator.pop(context);
                      widget.onSuccess();
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      widget.onError(widget.vm.friendlyError(
                        e,
                        fallback:
                            'Unable to delete care plan item. Please try again.',
                      ));
                    }
                  } finally {
                    if (mounted) setState(() => _isDeleting = false);
                  }
                },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: _isDeleting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }
}
