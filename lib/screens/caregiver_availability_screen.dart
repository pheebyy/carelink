import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/availability_model.dart';
import '../services/availability_service.dart';

class CaregiverAvailabilityScreen extends StatefulWidget {
  const CaregiverAvailabilityScreen({Key? key}) : super(key: key);

  @override
  State<CaregiverAvailabilityScreen> createState() =>
      _CaregiverAvailabilityScreenState();
}

class _CaregiverAvailabilityScreenState
    extends State<CaregiverAvailabilityScreen> {
  final _availabilityService = AvailabilityService();
  final _auth = FirebaseAuth.instance;
  late DateTime _focusedDay;
  final Set<DateTime> _selectedDates = {};
  String _status = 'available';
  String _breakReason = '';

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _loadCurrentAvailability();
  }

  Future<void> _loadCurrentAvailability() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final availability =
          await _availabilityService.getAvailability(userId);
      if (availability != null) {
        setState(() {
          _selectedDates.clear();
          for (var date in availability.unavailableDates) {
            _selectedDates.add(date);
          }
          _status = availability.status;
          _breakReason = availability.breakReason ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading availability: $e')),
        );
      }
    }
  }

  Future<void> _saveAvailability() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _availabilityService.setAvailability(
        caregiverId: userId,
        unavailableDates: _selectedDates.toList(),
        status: _status,
        breakReason: _status == 'on_break' ? _breakReason : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(' Availability updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving availability: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Availability')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Availability'),
        elevation: 0,
      ),
      body: StreamBuilder<CaregiversAvailability?>(
        stream: _availabilityService.streamAvailability(userId),
        builder: (context, snapshot) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Calendar Section
                Card(
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Calendar header with navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                                setState(() {
                                  _focusedDay = DateTime(
                                      _focusedDay.year, _focusedDay.month - 1);
                                });
                              },
                            ),
                            Text(
                              '${_getMonthName(_focusedDay.month)} ${_focusedDay.year}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                setState(() {
                                  _focusedDay = DateTime(
                                      _focusedDay.year, _focusedDay.month + 1);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Weekday headers
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                              .map((day) => Center(
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        // Calendar days
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.2,
                          children: _buildCalendarDays(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Legend
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade200,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Today', style: TextStyle(fontSize: 12)),
                      ),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Unavailable', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Status Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildStatusChip('available', 'Available'),
                          _buildStatusChip('unavailable', 'Unavailable'),
                          _buildStatusChip('on_break', 'On Break'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Break Reason Field (only show if on_break selected)
                      if (_status == 'on_break')
                        TextFormField(
                          initialValue: _breakReason,
                          decoration: InputDecoration(
                            labelText: 'Reason for break',
                            hintText: 'E.g., Medical leave, Vacation...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => _breakReason = value);
                          },
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Summary
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Status: ${_status.replaceAll('_', ' ').toUpperCase()}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        Text(
                          'Unavailable dates: ${_selectedDates.length}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loadCurrentAvailability,
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveAvailability,
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Info Box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Select dates when you\'re not available. These dates won\'t appear in job searches.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String value, String label) {
    final isSelected = _status == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _status = value;
          if (value != 'on_break') {
            _breakReason = '';
          }
        });
      },
      selectedColor: Colors.blue.shade200,
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey.shade300,
      ),
    );
  }

  List<Widget> _buildCalendarDays() {
    final firstDayOfMonth =
        DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth =
        DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

    final days = <Widget>[];

    // Empty cells before first day
    for (int i = 0; i < firstWeekday; i++) {
      days.add(const SizedBox.shrink());
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, day);
      final isSelected = _selectedDates.any((d) =>
          d.year == date.year && d.month == date.month && d.day == date.day);
      final isToday = DateTime.now().year == date.year &&
          DateTime.now().month == date.month &&
          DateTime.now().day == date.day;

      days.add(
        GestureDetector(
          onTap: date.isBefore(DateTime.now())
              ? null
              : () {
                  setState(() {
                    if (isSelected) {
                      _selectedDates.removeWhere((d) =>
                          d.year == date.year &&
                          d.month == date.month &&
                          d.day == date.day);
                    } else {
                      _selectedDates.add(date);
                    }
                  });
                },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.red.shade400
                  : isToday
                      ? Colors.blue.shade200
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: date.isBefore(DateTime.now())
                      ? Colors.grey.shade400
                      : Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return days;
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
