import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Azure Communication Service for SMS notifications and messaging
class AzureCommunicationService {
  static final AzureCommunicationService _instance = AzureCommunicationService._internal();
  factory AzureCommunicationService() => _instance;
  AzureCommunicationService._internal();

  late String _endpoint;
  late String _accessKey;
  bool _initialized = false;

  /// Initialize service with credentials from .env
  void initialize() {
    _endpoint = dotenv.env['AZURE_COMMUNICATION_ENDPOINT'] ?? '';
    _accessKey = dotenv.env['AZURE_COMMUNICATION_KEY'] ?? '';

    if (_endpoint.isEmpty || _accessKey.isEmpty) {
      print('⚠️ Warning: Azure Communication credentials not found in .env');
      _initialized = false;
      return;
    }

    // Remove trailing slash from endpoint if present
    if (_endpoint.endsWith('/')) {
      _endpoint = _endpoint.substring(0, _endpoint.length - 1);
    }

    _initialized = true;
    print('✅ Azure Communication Service initialized');
    print('   Endpoint: $_endpoint');
  }

  bool get isInitialized => _initialized;

  // ================================
  // 💬 SMS FUNCTIONALITY
  // ================================

  /// Send SMS notification to caregiver about new booking
  Future<bool> sendBookingNotification({
    required String caregiverPhone,
    required String clientName,
    required String bookingDate,
    required String serviceType,
  }) async {
    if (!_initialized) {
      print('❌ Azure Communication Service not initialized');
      return false;
    }

    try {
      final message = '''
🏥 New Carelink Booking!

Client: $clientName
Date: $bookingDate
Service: $serviceType

Open the Carelink app to accept or decline.
      '''.trim();

      print('📱 Sending SMS to $caregiverPhone');
      
      final response = await http.post(
        Uri.parse('$_endpoint/sms?api-version=2021-03-07'),
        headers: {
          'Ocp-Apim-Subscription-Key': _accessKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '+18445791556', // Azure default test number
          'smsRecipients': [
            {'to': caregiverPhone} // Format: +254700000000
          ],
          'message': message,
        }),
      );

      if (response.statusCode == 202 || response.statusCode == 200) {
        print('✅ SMS sent successfully');
        return true;
      } else {
        print('❌ SMS failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('🔥 Error sending SMS: $e');
      return false;
    }
  }

  /// Send payment confirmation SMS
  Future<bool> sendPaymentConfirmation({
    required String phone,
    required String recipientName,
    required double amount,
    required String reference,
  }) async {
    if (!_initialized) {
      print('❌ Service not initialized');
      return false;
    }

    try {
      final message = '''
✅ Payment Confirmed

Dear $recipientName,
Your payment of KSh ${amount.toStringAsFixed(2)} has been processed.

Reference: $reference

Thank you for using Carelink!
      '''.trim();

      print('📱 Sending payment confirmation to $phone');
      
      final response = await http.post(
        Uri.parse('$_endpoint/sms?api-version=2021-03-07'),
        headers: {
          'Ocp-Apim-Subscription-Key': _accessKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '+18445791556',
          'smsRecipients': [{'to': phone}],
          'message': message,
        }),
      );

      if (response.statusCode == 202 || response.statusCode == 200) {
        print('✅ Payment SMS sent successfully');
        return true;
      } else {
        print('❌ Payment SMS failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('🔥 Error sending payment SMS: $e');
      return false;
    }
  }

  /// Send booking reminder SMS
  Future<bool> sendBookingReminder({
    required String phone,
    required String name,
    required String bookingDate,
    required String bookingTime,
  }) async {
    if (!_initialized) return false;

    try {
      final message = '''
⏰ Carelink Reminder

Hi $name,
You have an upcoming booking on:
📅 $bookingDate at $bookingTime

Please be on time. Thank you!
      '''.trim();

      final response = await http.post(
        Uri.parse('$_endpoint/sms?api-version=2021-03-07'),
        headers: {
          'Ocp-Apim-Subscription-Key': _accessKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '+18445791556',
          'smsRecipients': [{'to': phone}],
          'message': message,
        }),
      );

      return response.statusCode == 202 || response.statusCode == 200;
    } catch (e) {
      print('🔥 Error sending reminder: $e');
      return false;
    }
  }

  /// Send verification code SMS
  Future<bool> sendVerificationCode({
    required String phone,
    required String code,
  }) async {
    if (!_initialized) return false;

    try {
      final message = '''
🔐 Carelink Verification Code

Your verification code is: $code

This code will expire in 10 minutes.
Do not share this code with anyone.
      '''.trim();

      final response = await http.post(
        Uri.parse('$_endpoint/sms?api-version=2021-03-07'),
        headers: {
          'Ocp-Apim-Subscription-Key': _accessKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '+18445791556',
          'smsRecipients': [{'to': phone}],
          'message': message,
        }),
      );

      return response.statusCode == 202 || response.statusCode == 200;
    } catch (e) {
      print('🔥 Error sending verification code: $e');
      return false;
    }
  }

  /// Generic SMS sender
  Future<bool> sendSMS({
    required String phone,
    required String message,
  }) async {
    if (!_initialized) {
      print('❌ Service not initialized');
      return false;
    }

    try {
      print('📱 Sending SMS to $phone');
      
      final response = await http.post(
        Uri.parse('$_endpoint/sms?api-version=2021-03-07'),
        headers: {
          'Ocp-Apim-Subscription-Key': _accessKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '+18445791556',
          'smsRecipients': [{'to': phone}],
          'message': message,
        }),
      );

      if (response.statusCode == 202 || response.statusCode == 200) {
        print('✅ SMS sent successfully');
        return true;
      } else {
        print('❌ SMS failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('🔥 Error sending SMS: $e');
      return false;
    }
  }
}
