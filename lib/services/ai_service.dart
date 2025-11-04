import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final bool _isInitialized;

  AiService({required String apiKey})
      : _isInitialized = apiKey.isNotEmpty &&
            !apiKey.contains('YOUR_GEMINI') {
    if (_isInitialized) {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
      );
      _initializeChat();
    }
  }

  void _initializeChat() {
    _chat = _model.startChat(
      history: [
        Content.text(
          '''You are CareLink Assistant, a helpful and empathetic AI assistant 
for a healthcare caregiving platform.

Your responsibilities:
- Help users schedule and manage care visits
- Answer questions about available caregivers and their qualifications
- Provide information about payments, billing, and invoices
- Offer general health and wellness advice for elderly care
- Send appointment reminders and updates
- Answer FAQs about the platform
- Provide emotional support to family members managing care

Guidelines:
- Be professional, warm, and empathetic
- Keep responses concise and clear (2-3 sentences max)
- When discussing health matters, always recommend consulting a healthcare provider for serious concerns
- If you don't know something specific about the user's account, suggest contacting support
- Never provide medical diagnoses - only general wellness information
- Personalize responses when possible
- Be supportive and understanding of caregiving challenges

Available Features to mention:
- View upcoming visits and reschedule them
- Message caregivers
- Track and manage payments
- Update profile information
- Request emergency support
- Access care plans and health records''',
        ),
      ],
    );
  }

  bool get isInitialized => _isInitialized;

  Future<String> chat(String userMessage) async {
    if (!_isInitialized) {
      return 'AI Assistant is not configured. Please add your Gemini API key in lib/config/api_config.dart';
    }

    try {
      if (userMessage.trim().isEmpty) {
        return 'Please type a message';
      }

      final response = await _chat.sendMessage(
        Content.text(userMessage),
      );

      return response.text ??
          'Unable to process your message. Please try again.';
    } on GenerativeAIException catch (e) {
      print('🔥 Generative AI Error: ${e.message}');
      if (e.message.contains('API_KEY_INVALID')) {
        return 'Invalid API key. Please check your configuration.';
      } else if (e.message.contains('RESOURCE_EXHAUSTED')) {
        return 'I\'m currently busy. Please try again in a moment.';
      }
      return 'I encountered an error: ${e.message}. Please try again.';
    } catch (e) {
      print('🔥 AI Chat Error: $e');
      return 'Sorry, I encountered an unexpected error. Please try again or contact support.';
    }
  }

  void resetChat() {
    if (_isInitialized) {
      _initializeChat();
    }
  }
}