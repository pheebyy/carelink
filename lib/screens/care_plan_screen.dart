import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class CarePlanScreen extends StatefulWidget {
  const CarePlanScreen({super.key});

  @override
  State<CarePlanScreen> createState() => _CarePlanScreenState();
}

class _CarePlanScreenState extends State<CarePlanScreen> {
  final _fs = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  static const Set<String> _allowedFrequencies = {
    'daily',
    'weekly',
    'weekdays',
    'monthly',
    'as needed',
  };

  static const List<MapEntry<String, String>> _frequencyOptions = [
    MapEntry('', 'None'),
    MapEntry('daily', 'Daily'),
    MapEntry('weekly', 'Weekly'),
    MapEntry('weekdays', 'Weekdays'),
    MapEntry('monthly', 'Monthly'),
    MapEntry('as needed', 'As needed'),
  ];

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade600 : null,
      ),
    );
  }

  String _friendlyErrorMessage(
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
    if (msg.contains('network') || msg.contains('socket') || msg.contains('timeout')) {
      return 'No internet connection. Check your network and try again.';
    }

    return fallback;
  }

  String? _validateCarePlanInputs({
    required String type,
    required String title,
    required String description,
    required String time,
    required String frequency,
  }) {
    if (title.trim().isEmpty) {
      return 'Please enter a title';
    }
    if (description.trim().length > 280) {
      return 'Description is too long (max 280 characters)';
    }
    if (type == 'medication' && time.trim().isEmpty) {
      return 'Medication items require a reminder time';
    }

    final normalizedFrequency = frequency.trim().toLowerCase();
    if (normalizedFrequency.isNotEmpty &&
        !_allowedFrequencies.contains(normalizedFrequency)) {
      return 'Frequency must be: Daily, Weekly, Weekdays, Monthly, or As needed';
    }

    return null;
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    if (!mounted) return;

    controller.text = picked.format(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
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
            onPressed: () => _showAddCarePlanDialog(),
            tooltip: 'Add Care Plan Item',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _fs.carePlansStream(_uid),
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
                    Icon(Icons.error_outline, color: Colors.red.shade400, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      _friendlyErrorMessage(
                        snapshot.error ?? Exception('Unknown error'),
                        fallback: 'Unable to load your care plan right now. Please try again.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
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
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No care plans yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddCarePlanDialog(),
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
              final plan = doc.data();
              final planId = doc.id;

              return _buildCarePlanCard(planId, plan);
            },
          );
        },
      ),
    );
  }

  Widget _buildCarePlanCard(String planId, Map<String, dynamic> plan) {
    final type = plan['type'] ?? 'general';
    final title = plan['title'] ?? 'Untitled';
    final description = plan['description'] ?? '';
    final time = plan['time'];
    final frequency = plan['frequency'];
    final isCompleted = plan['isCompleted'] ?? false;

    IconData icon;
    Color color;

    switch (type) {
      case 'medication':
        icon = Icons.medication;
        color = Colors.blue;
        break;
      case 'goal':
        icon = Icons.trending_up;
        color = Colors.green;
        break;
      case 'appointment':
        icon = Icons.calendar_today;
        color = Colors.orange;
        break;
      case 'exercise':
        icon = Icons.fitness_center;
        color = Colors.purple;
        break;
      default:
        icon = Icons.favorite;
        color = Colors.pink;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEditCarePlanDialog(planId, plan),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Checkbox(
                value: isCompleted,
                onChanged: (value) async {
                  try {
                    await _fs.toggleCarePlanCompletion(_uid!, planId, value ?? false);
                    await NotificationService.instance.syncMedicationRemindersForUser(_uid);
                  } catch (e) {
                    if (mounted) {
                      _showMessage(
                        _friendlyErrorMessage(
                          e,
                          fallback: 'Unable to update this care plan item right now. Please try again.',
                        ),
                        isError: true,
                      );
                    }
                  }
                },
                activeColor: Colors.green,
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? Colors.grey : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (time != null || frequency != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (time != null) ...[
                            Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              time,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                          if (time != null && frequency != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('•', style: TextStyle(color: Colors.grey.shade400)),
                            ),
                          if (frequency != null)
                            Text(
                              frequency,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                onPressed: () => _confirmDelete(planId, title),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCarePlanDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final timeController = TextEditingController();
    String selectedType = 'medication';
    String selectedFrequency = '';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Care Plan Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type dropdown
                DropdownButtonFormField<String>(
                  value: selectedType,
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
                  onChanged: (value) {
                    setDialogState(() => selectedType = value!);
                  },
                ),
                const SizedBox(height: 16),
                // Title
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Description
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Time
                TextField(
                  controller: timeController,
                  readOnly: true,
                  onTap: () => _pickTime(timeController),
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
                  value: selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: _frequencyOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.key,
                          child: Text(option.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedFrequency = value ?? '');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                final validationError = _validateCarePlanInputs(
                  type: selectedType,
                  title: titleController.text,
                  description: descriptionController.text,
                  time: timeController.text,
                  frequency: selectedFrequency,
                );

                if (validationError != null) {
                  _showMessage(validationError, isError: true);
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  await _fs.createCarePlan(
                    clientId: _uid!,
                    type: selectedType,
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    time: timeController.text.trim().isEmpty ? null : timeController.text.trim(),
                    frequency: selectedFrequency.trim().isEmpty
                        ? null
                      : selectedFrequency,
                  );

                  await NotificationService.instance.syncMedicationRemindersForUser(_uid);

                  if (mounted) {
                    Navigator.pop(context);
                    _showMessage('Care plan added successfully');
                  }
                } catch (e) {
                  if (mounted) {
                    _showMessage(
                      _friendlyErrorMessage(
                        e,
                        fallback: 'Unable to add care plan item. Please try again.',
                      ),
                      isError: true,
                    );
                  }
                } finally {
                  if (mounted) {
                    setDialogState(() => isSaving = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCarePlanDialog(String planId, Map<String, dynamic> plan) {
    final titleController = TextEditingController(text: plan['title']);
    final descriptionController = TextEditingController(text: plan['description']);
    final timeController = TextEditingController(text: plan['time'] ?? '');
    String selectedType = plan['type'] ?? 'medication';
    final rawFrequency = (plan['frequency'] ?? '').toString().toLowerCase().trim();
    String selectedFrequency = _allowedFrequencies.contains(rawFrequency) ? rawFrequency : '';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Care Plan Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type dropdown
                DropdownButtonFormField<String>(
                  value: selectedType,
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
                  onChanged: (value) {
                    setDialogState(() => selectedType = value!);
                  },
                ),
                const SizedBox(height: 16),
                // Title
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Description
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Time
                TextField(
                  controller: timeController,
                  readOnly: true,
                  onTap: () => _pickTime(timeController),
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
                  value: selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: _frequencyOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.key,
                          child: Text(option.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedFrequency = value ?? '');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                final validationError = _validateCarePlanInputs(
                  type: selectedType,
                  title: titleController.text,
                  description: descriptionController.text,
                  time: timeController.text,
                  frequency: selectedFrequency,
                );

                if (validationError != null) {
                  _showMessage(validationError, isError: true);
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  await _fs.updateCarePlan(_uid!, planId, {
                    'type': selectedType,
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'time': timeController.text.trim().isEmpty ? null : timeController.text.trim(),
                    'frequency': selectedFrequency.trim().isEmpty
                        ? null
                      : selectedFrequency,
                  });

                  await NotificationService.instance.syncMedicationRemindersForUser(_uid);

                  if (mounted) {
                    Navigator.pop(context);
                    _showMessage('Care plan updated successfully');
                  }
                } catch (e) {
                  if (mounted) {
                    _showMessage(
                      _friendlyErrorMessage(
                        e,
                        fallback: 'Unable to update care plan item. Please try again.',
                      ),
                      isError: true,
                    );
                  }
                } finally {
                  if (mounted) {
                    setDialogState(() => isSaving = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String planId, String title) {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete Care Plan'),
          content: Text('Are you sure you want to delete "$title"?'),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      try {
                        await _fs.deleteCarePlan(_uid!, planId);
                        await NotificationService.instance.syncMedicationRemindersForUser(_uid);
                        if (mounted) {
                          Navigator.pop(context);
                          _showMessage('Care plan deleted');
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context);
                          _showMessage(
                            _friendlyErrorMessage(
                              e,
                              fallback: 'Unable to delete care plan item. Please try again.',
                            ),
                            isError: true,
                          );
                        }
                      } finally {
                        if (mounted) {
                          setDialogState(() => isDeleting = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: isDeleting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
