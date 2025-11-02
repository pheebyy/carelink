/// API Configuration
/// 
/// IMPORTANT: Get your own Google AI API key from:
/// https://makersuite.google.com/app/apikey
/// 
/// Then replace 'YOUR_GOOGLE_AI_API_KEY_HERE' with your actual key.

class ApiConfig {
  // Google Gemini AI API Key
  // TODO: Replace with your actual API key from Google AI Studio
  static const String geminiApiKey = 'AIzaSyBSLDSeSRlHvet3NOsz2xODmvxzayzCMYA';
  
  /// Check if API key is configured
  static bool get isConfigured => 
      geminiApiKey != '' && 
      geminiApiKey.isNotEmpty;
}
