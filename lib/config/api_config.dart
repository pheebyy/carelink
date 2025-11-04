import 'package:flutter_dotenv/flutter_dotenv.dart';

   class ApiConfig {
     static String get geminiApiKey {
       return dotenv.env['GEMINI_API_KEY'] ?? '';
     }
     
     static bool get isConfigured {
       return geminiApiKey.isNotEmpty;
     }
   }