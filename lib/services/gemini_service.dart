import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  late GenerativeModel _model;
  bool _initialized = false;
  String? _initError;

  // List of models to try in order (updated based on API availability)
  final List<String> _modelsToTry = [
    'gemini-2.0-flash',      // Latest Gemini 2.0 model
    'gemini-2.0-flash-exp',  // Experimental version
    'gemini-1.5-flash',      // Gemini 1.5 Flash
    'gemini-1.5-pro',        // Gemini 1.5 Pro
    'gemini-pro',            // Fallback to stable version
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final apiKey = dotenv.env['GEMINI_API'] ?? '';
      
      if (apiKey.isEmpty) {
        _initError = 'GEMINI_API key not found in .env file';
        throw Exception(_initError);
      }

      print('🔑 Initializing Gemini with API key: ${apiKey.substring(0, 10)}...');

      // Try each model until one works
      Exception? lastError;
      for (final modelName in _modelsToTry) {
        try {
          print('🔍 Trying model: $modelName');
          
          _model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              temperature: 0.7,
              topK: 40,
              topP: 0.95,
              maxOutputTokens: 1024,
            ),
            safetySettings: [
              SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
              SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
              SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
              SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
            ],
          );

          // Test the model with a simple request
          print('🧪 Testing model $modelName...');
          final testContent = [Content.text('Hello')];
          await _model.generateContent(testContent);
          
          print('✅ Model $modelName works! Gemini Service initialized successfully');
          _initialized = true;
          _initError = null;
          return; // Success!
          
        } catch (e) {
          print('❌ Model $modelName failed: $e');
          lastError = e as Exception;
          continue; // Try next model
        }
      }
      
      // If we get here, all models failed
      _initError = 'All models failed. Last error: ${lastError.toString()}';
      throw Exception(_initError);
      
    } catch (e) {
      _initError = e.toString();
      print('❌ Gemini initialization error: $e');
      rethrow;
    }
  }

  Future<String> generateResponse({
    required String userMessage,
    required String systemContext,
  }) async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        return 'Sorry, I couldn\'t initialize the AI service. Please check your setup:\n\n'
            '1. Verify your API key in Google AI Studio\n'
            '2. Check your internet connection\n'
            '3. Make sure the API is enabled in your Google Cloud project\n\n'
            'Error: ${e.toString()}';
      }
    }

    try {
      // FIXED: More flexible, natural instructions
      final prompt = '''
You are a helpful community safety assistant. You have access to verified crime data and safe location information.

$systemContext

User Question: $userMessage

Instructions:
- Answer naturally and helpfully based on the data provided above
- If the data shows no incidents, that's good news - say so positively!
- For general questions (like "how to report"), provide helpful guidance even without specific data
- Be conversational, clear, and reassuring
- Use emojis and formatting to make responses engaging
- If you truly cannot answer from the data, suggest alternative ways to help
''';

      print('📤 Sending request to Gemini...');
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      print('✅ Received response from Gemini');

      if (response.text == null || response.text!.isEmpty) {
        // Check if blocked by safety filters
        if (response.candidates.isNotEmpty == true) {
          final candidate = response.candidates.first;
          if (candidate.finishReason == FinishReason.safety) {
            return 'I couldn\'t generate a response due to safety concerns. Please rephrase your question.';
          }
        }
        return 'I apologize, but I couldn\'t generate a response at this time. Please try again.';
      }

      return response.text!;
    } catch (e) {
      print('❌ Gemini API Error: $e');
      
      // More specific error messages
      if (e.toString().contains('API key')) {
        return 'There\'s an issue with the API key. Please verify it in Google AI Studio.\n\nError: ${e.toString()}';
      } else if (e.toString().contains('quota')) {
        return 'The AI service has reached its usage limit. Please try again later.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        return 'I\'m having trouble connecting to the AI service. Please check your internet connection and try again.';
      } else if (e.toString().contains('model')) {
        return 'The AI model is not available. This might be a configuration issue.\n\nError: ${e.toString()}';
      }
      
      return 'I\'m having trouble connecting right now. Please try again in a moment.\n\nError: ${e.toString()}';
    }
  }

  Future<String> generateSafetyResponse({
    required String userMessage,
    required List<Map<String, dynamic>> nearbyHotspots,
    required List<Map<String, dynamic>> nearbySafeSpots,
    String? userLocation,
  }) async {
    // Build context from crime data
    final StringBuffer context = StringBuffer();
    context.writeln('=== VERIFIED CRIME DATA ===');
    context.writeln('Location: ${userLocation ?? "User's area"}');
    context.writeln('');

    // Add hotspot information
    if (nearbyHotspots.isNotEmpty) {
      context.writeln('Recent Crime Incidents (${nearbyHotspots.length} total):');
      
      // Group by crime type
      final Map<String, List<Map<String, dynamic>>> crimesByType = {};
      for (final hotspot in nearbyHotspots) {
        final crimeType = hotspot['crime_type']?['name'] ?? 'Unknown';
        crimesByType.putIfAbsent(crimeType, () => []).add(hotspot);
      }

      // Summarize each crime type
      crimesByType.forEach((type, incidents) {
        final level = incidents.first['crime_type']?['level'] ?? 'unknown';
        context.writeln('- $type (${incidents.length} incidents, severity: $level)');
        
        // Add recent incident details
        if (incidents.length <= 3) {
          for (final incident in incidents) {
            final time = incident['time']?.toString() ?? 'Unknown time';
            final status = incident['active_status'] ?? 'unknown';
            context.writeln('  • Reported: ${_formatDateTime(time)}, Status: $status');
          }
        }
      });
      context.writeln('');
    } else {
      context.writeln('✅ GOOD NEWS: No recent crime incidents reported in this area (within 5km).');
      context.writeln('');
    }

    // Add safe spot information
    if (nearbySafeSpots.isNotEmpty) {
      context.writeln('Nearby Safe Spots (${nearbySafeSpots.length} total):');
      final Map<String, List<Map<String, dynamic>>> spotsByType = {};
      for (final spot in nearbySafeSpots) {
        final typeName = spot['safe_spot_types']?['name'] ?? 'Unknown';
        spotsByType.putIfAbsent(typeName, () => []).add(spot);
      }

      spotsByType.forEach((type, spots) {
        context.writeln('- $type: ${spots.length} location(s)');
        for (final spot in spots.take(3)) {
          context.writeln('  • ${spot['name']}');
        }
      });
      context.writeln('');
    }

    context.writeln('=== END OF VERIFIED DATA ===');

    return await generateResponse(
      userMessage: userMessage,
      systemContext: context.toString(),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dt = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      } else {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      }
    } catch (e) {
      return dateTimeStr;
    }
  }

  // Quick safety tips generator
  Future<String> generateSafetyTips({
    required String locationDescription,
    required List<String> crimeTypes,
  }) async {
    final context = '''
Location: $locationDescription
Common crime types in this area: ${crimeTypes.join(', ')}

Generate 3-5 practical safety tips specific to this area and these crime types.
''';

    return await generateResponse(
      userMessage: 'What safety precautions should I take?',
      systemContext: context,
    );
  }

  String? get lastError => _initError;
  bool get isInitialized => _initialized;
}