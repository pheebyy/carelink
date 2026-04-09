import 'package:carelink/Models/Job_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'map_location_picker_screen.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _selectedCareType = 'part-time';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPreview = false;
  List<String> _selectedSkills = [];
  double? _selectedLatitude;
  double? _selectedLongitude;

  final List<String> _availableSkills = [
    'Patient Care',
    'Mobility Assistance',
    'Medication Management',
    'Wound Care',
    'Dementia Care',
    'Physical Therapy',
    'Mental Health Support',
    'Cooking & Nutrition',
  ];

  final Map<String, String> _careTypeDescriptions = {
    'part-time': 'Less than 40 hours/week',
    'full-time': '40+ hours/week',
    'overnight': 'Night shift care',
    'weekend': 'Weekend only',
    'temporary': 'Short-term assistance',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPickerScreen(
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
          initialLocationName: _locationController.text,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _locationController.text = result['locationName'] ?? '';
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now().add(Duration(days: 7))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate == null) {
            _endDate = picked.add(const Duration(days: 7));
          }
        } else {
          if (picked.isAfter(_startDate ?? DateTime.now())) {
            _endDate = picked;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('End date must be after start date')),
            );
          }
        }
      });
    }
  }

  Future<void> _postJob() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'You must be logged in to post a job');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final job = JobModel(
        id: '',
        clientId: currentUser.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        careType: _selectedCareType,
        location: _locationController.text.trim(),
        budget: double.tryParse(_budgetController.text.trim()),
        status: 'open',
        startDate: _startDate != null ? Timestamp.fromDate(_startDate!) : null,
        endDate: _endDate != null ? Timestamp.fromDate(_endDate!) : null,
      );

      await _firestore.collection('jobs').add(job.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Job posted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        _titleController.clear();
        _descriptionController.clear();
        _locationController.clear();
        _budgetController.clear();
        setState(() {
          _selectedCareType = 'part-time';
          _startDate = null;
          _endDate = null;
          _selectedSkills.clear();
          _selectedLatitude = null;
          _selectedLongitude = null;
        });

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Unable to post job. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post a Care Job',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          if (!_showPreview)
            TextButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() => _showPreview = true);
                }
              },
              child: const Text('Preview'),
            ),
          if (_showPreview)
            TextButton(
              onPressed: () => setState(() => _showPreview = false),
              child: const Text('Edit'),
            ),
        ],
      ),
      body: _showPreview ? _buildPreview() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 16),

              _buildLabelWithRequired('Job Title'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: _buildInputDecoration(
                  hintText: 'e.g., Elderly Care Companion for Weekend Shifts',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Job title is required';
                  if (value!.length < 5) return 'Title must be at least 5 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabelWithRequired('Care Type'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCareType,
                decoration: _buildInputDecoration(),
                items: _careTypeDescriptions.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Text(e.key.replaceFirst(e.key[0], e.key[0].toUpperCase())),
                              const SizedBox(width: 8),
                              Text('(${e.value})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  )),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCareType = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              _buildLabelWithRequired('Location'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _locationController.text.isEmpty
                                  ? 'Tap to select location on map'
                                  : _locationController.text,
                              style: TextStyle(
                                fontSize: 15,
                                color: _locationController.text.isEmpty
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                              ),
                            ),
                            if (_selectedLatitude != null && _selectedLongitude != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '📍 ${_selectedLatitude?.toStringAsFixed(4)}, ${_selectedLongitude?.toStringAsFixed(4)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.map_outlined, color: Colors.blue.shade600, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Schedule & Duration'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  _startDate != null
                                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                      : 'Select date',
                                  style: TextStyle(
                                    color: _startDate != null
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _startDate != null ? () => _selectDate(context, false) : null,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _startDate != null ? Colors.grey.shade300 : Colors.grey.shade200,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _startDate == null ? Colors.grey.shade50 : null,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 18,
                                    color: _startDate != null
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400),
                                const SizedBox(width: 8),
                                Text(
                                  _endDate != null
                                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                      : 'Select date',
                                  style: TextStyle(
                                    color: _endDate != null
                                        ? Colors.black87
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Budget & Skills'),
              const SizedBox(height: 16),

              _buildLabelWithRequired('Budget (KES)', isRequired: false),
              const SizedBox(height: 8),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  prefixIcon: Icons.attach_money,
                  prefixText: 'KES ',
                  hintText: 'e.g., 500 or 25,000',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value.replaceAll(',', '')) == null) {
                      return 'Enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const Text('Special Skills Required',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSkills
                    .map((skill) => FilterChip(
                          selected: _selectedSkills.contains(skill),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSkills.add(skill);
                              } else {
                                _selectedSkills.remove(skill);
                              }
                            });
                          },
                          label: Text(skill),
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: Colors.blue.shade200,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Job Description'),
              const SizedBox(height: 16),

              _buildLabelWithRequired('Detailed Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: _buildInputDecoration(
                  hintText: 'Describe: duties, care requirements, schedule, living situation...',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Description is required';
                  if (value!.length < 20) return 'Description must be at least 20 characters';
                  return null;
                },
              ),
              
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_descriptionController.text.length}/500',
                    style: TextStyle(
                      fontSize: 12,
                      color: _descriptionController.text.length > 500
                          ? Colors.red
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Submit Buttons
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _postJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey.shade200,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Posting Job...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Post Job',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleController.text,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _selectedCareType.replaceFirst(_selectedCareType[0], _selectedCareType[0].toUpperCase()),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _locationController.text,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_budgetController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(Icons.attach_money, size: 18, color: Colors.green),
                            Text(
                              'KES ${_budgetController.text}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_startDate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              '${_startDate!.day}/${_startDate!.month} - ${_endDate?.day}/${_endDate?.month}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),

                    if (_selectedSkills.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: _selectedSkills
                            .map((skill) => Chip(
                                  label: Text(skill, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.purple.shade100,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Divider(),
                    const SizedBox(height: 16),

                    Text(
                      'About This Job',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _descriptionController.text,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This is how caregivers will see your job listing.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _postJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Posting...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Confirm & Post Job',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => setState(() => _showPreview = false),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Edit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLabelWithRequired(String label, {bool isRequired = true}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    IconData? prefixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade600) : null,
      prefixText: prefixText,
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
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
