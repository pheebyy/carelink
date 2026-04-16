import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../utils/auth_provider.dart';

class CaregiverVerificationScreen extends StatefulWidget {
  const CaregiverVerificationScreen({super.key});

  @override
  State<CaregiverVerificationScreen> createState() =>
      _CaregiverVerificationScreenState();
}

class _CaregiverVerificationScreenState
    extends State<CaregiverVerificationScreen> {
  final _storageService = StorageService();
  final _firestoreService = FirestoreService();
  final _imagePicker = ImagePicker();

  // Form controllers
  final _licenseNumberCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _passportNumberCtrl = TextEditingController();

  // File holders
  File? _licenseFile;
  File? _idFile;
  File? _passportFile;

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _licenseNumberCtrl.dispose();
    _idNumberCtrl.dispose();
    _passportNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String documentType) async {
    try {
      final XFile? pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          final file = File(pickedFile.path);
          switch (documentType) {
            case 'practice_license':
              _licenseFile = file;
              break;
            case 'national_id':
              _idFile = file;
              break;
            case 'passport_photo':
              _passportFile = file;
              break;
          }
        });
        print('✅ Selected $documentType: ${pickedFile.name}');
      }
    } catch (e) {
      print('🔥 Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _submitDocuments() async {
    // Validation
    if (_licenseNumberCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'License number is required');
      return;
    }
    if (_licenseFile == null) {
      setState(() =>
          _errorMessage = 'Practice license document is required');
      return;
    }

    if (_idNumberCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'ID number is required');
      return;
    }
    if (_idFile == null) {
      setState(() => _errorMessage = 'National ID document is required');
      return;
    }

    if (_passportFile == null) {
      setState(() => _errorMessage = 'Passport photo is required');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = AuthProvider.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final uid = user.uid;
      final List<Map<String, String>> uploadedDocs = [];

      // Upload practice license
      final licenseResult = await _storageService.uploadVerificationDocument(
        uid: uid,
        documentType: 'practice_license',
        bytes: await _licenseFile!.readAsBytes(),
        fileExtension: 'jpg',
        contentType: 'image/jpeg',
      );
      uploadedDocs.add({
        'documentType': 'practice_license',
        'storageUrl': licenseResult['storageUrl']!,
        'fileName': licenseResult['fileName']!,
        'documentValue': _licenseNumberCtrl.text.trim(),
      });

      // Upload national ID
      final idResult = await _storageService.uploadVerificationDocument(
        uid: uid,
        documentType: 'national_id',
        bytes: await _idFile!.readAsBytes(),
        fileExtension: 'jpg',
        contentType: 'image/jpeg',
      );
      uploadedDocs.add({
        'documentType': 'national_id',
        'storageUrl': idResult['storageUrl']!,
        'fileName': idResult['fileName']!,
        'documentValue': _idNumberCtrl.text.trim(),
      });

      // Upload passport photo
      final passportResult = await _storageService.uploadVerificationDocument(
        uid: uid,
        documentType: 'passport_photo',
        bytes: await _passportFile!.readAsBytes(),
        fileExtension: 'jpg',
        contentType: 'image/jpeg',
      );
      uploadedDocs.add({
        'documentType': 'passport_photo',
        'storageUrl': passportResult['storageUrl']!,
        'fileName': passportResult['fileName']!,
        'documentValue': _passportNumberCtrl.text.trim(),
      });

      // Submit to Firestore
      await _firestoreService.submitVerificationDocuments(
        caregiverId: uid,
        documents: uploadedDocs,
      );

      setState(() {
        _successMessage =
            'Documents submitted successfully! Admin will review and verify your documents.';
        _isSubmitting = false;
      });

      // Clear form
      _licenseNumberCtrl.clear();
      _idNumberCtrl.clear();
      _passportNumberCtrl.clear();
      setState(() {
        _licenseFile = null;
        _idFile = null;
        _passportFile = null;
      });

      // Show success and navigate back after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('🔥 Error submitting verification documents: $e');
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isSubmitting = false;
      });
    }
  }

  Widget _buildDocumentSection({
    required String title,
    required String documentType,
    required TextEditingController numberController,
    required File? selectedFile,
    required String numberLabel,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberController,
              decoration: InputDecoration(
                labelText: numberLabel,
                hintText: 'Enter your $numberLabel',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.info),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _pickFile(documentType),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(height: 8),
                    if (selectedFile == null)
                      Column(
                        children: [
                          Text(
                            'Tap to upload document',
                            style: TextStyle(color: Colors.blue.shade400),
                          ),
                          Text(
                            '(JPG, PNG - Max 5MB)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            'File selected: ${selectedFile.path.split('/').last}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Caregiver Verification'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Submit Your Verification Documents',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please provide the following documents to verify your credentials with official Kenyan boards.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Success message
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            if (_errorMessage != null || _successMessage != null)
              const SizedBox(height: 24),

            // Document sections
            _buildDocumentSection(
              title: '1. Practice License',
              documentType: 'practice_license',
              numberController: _licenseNumberCtrl,
              selectedFile: _licenseFile,
              numberLabel: 'License Number/ID',
            ),
            _buildDocumentSection(
              title: '2. National ID',
              documentType: 'national_id',
              numberController: _idNumberCtrl,
              selectedFile: _idFile,
              numberLabel: 'ID Number',
            ),
            _buildDocumentSection(
              title: '3. Passport Photo',
              documentType: 'passport_photo',
              numberController: _passportNumberCtrl,
              selectedFile: _passportFile,
              numberLabel: 'Passport Number (Optional)',
            ),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDocuments,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue.shade600,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit for Verification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '📋 Your documents will be verified against official Kenyan boards by our admin team.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
