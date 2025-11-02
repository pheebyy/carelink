# AI Assistant Setup Guide

## Getting Your Google AI API Key

To enable the AI assistant chatbot in CareLink, you need a Google AI (Gemini) API key.

### Step 1: Get Your Free API Key

1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click **"Get API Key"** or **"Create API Key"**
4. Copy the generated API key (it looks like: `AIzaSy...`)

### Step 2: Configure the API Key

1. Open `lib/config/api_config.dart` in your project
2. Replace `'YOUR_GOOGLE_AI_API_KEY_HERE'` with your actual API key:

```dart
class ApiConfig {
  static const String geminiApiKey = 'AIzaSy...YOUR_ACTUAL_KEY_HERE';
  // ...
}
```

3. Save the file

### Step 3: Test the AI Assistant

1. Run the app:
   ```bash
   flutter run
   ```

2. Navigate to Client Dashboard
3. Tap the blue chat prompt card
4. Try asking a question like "When is my next visit?"

## Troubleshooting

### Error: "API key not configured"
- Make sure you replaced `'YOUR_GOOGLE_AI_API_KEY_HERE'` in `api_config.dart`
- The key should start with `AIzaSy`

### Error: "API key error"
- Your API key might be invalid
- Check that you copied the entire key
- Try generating a new key from Google AI Studio

### Error: "API quota exceeded"
- Free tier has usage limits
- Check your usage at [Google AI Studio](https://makersuite.google.com/)
- Consider enabling billing for higher limits

### Error: "Network error"
- Check your internet connection
- Make sure you're not behind a firewall blocking API calls

## API Key Security

⚠️ **Important**: Never commit your API key to version control!

Add this line to your `.gitignore`:
```
lib/config/api_config.dart
```

Or use environment variables for production apps.

## Free Tier Limits

Google AI (Gemini) free tier includes:
- 60 requests per minute
- Generous monthly quota
- No credit card required

For more details, visit [Google AI Pricing](https://ai.google.dev/pricing)
