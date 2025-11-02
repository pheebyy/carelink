import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  late final GenerativeModel _model;
  final List<Content> _chatHistory = [];
  
  AiService({required String apiKey}) {
    // Using gemini-pro - the stable, widely-supported model
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: apiKey,
    );
    _initializeChat();
  }

  void _initializeChat() {
    _chatHistory.clear();
    _chatHistory.add(
      Content.model([
        TextPart(
          '''You are CareLink Assistant, a helpful AI assistant for a healthcare 
          caregiving platform. You help users with:
          - Scheduling and managing care visits
          - Information about available caregivers
          - Payment and billing questions
          - General health and wellness advice
          - Appointment reminders and updates
          
          Be professional, empathetic, and concise. If you don't know something, 
          suggest contacting support.''',
        ),
      ]),
    );
  }

  Future<String> chat(String userMessage) async {
    try {
      // Add user message to history
      _chatHistory.add(Content.text(userMessage));
      
      // Generate response
      final response = await _model.generateContent(_chatHistory);
      final responseText = response.text ?? 'Unable to process your message';
      
      // Add AI response to history
      _chatHistory.add(Content.model([TextPart(responseText)]));
      
      return responseText;
    } catch (e) {
      // Print detailed error for debugging
      print('❌ AI Service Error: $e');
      
      // Return user-friendly error message with hint
      if (e.toString().contains('API key')) {
        return 'API key error. Please generate a new API key from Google AI Studio.';
      } else if (e.toString().contains('quota') || e.toString().contains('limit')) {
        return 'API quota exceeded. Please try again later or check your billing.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        return 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('not found') || e.toString().contains('not supported')) {
        return 'Model not available. Your API key might need to be regenerated from https://aistudio.google.com/app/apikey';
      }
      
      return 'Error: ${e.toString().split('\n').first}';
    }
  }

  void resetChat() {
    _initializeChat();
  }
}