import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _defaultModel = 'gemini-1.5-flash';

  /// Sends a prompt with optional context and chat history to Google Gemini API
  static Future<String> sendMessage({
    required String apiKey,
    required String prompt,
    List<Map<String, String>> chatHistory = const [],
    String? systemInstruction,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw Exception('Gemini API Key is missing. Please configure your key in settings.');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_defaultModel:generateContent?key=$cleanKey',
    );

    final List<Map<String, dynamic>> contents = [];

    // Add prior conversation turns
    for (final turn in chatHistory) {
      contents.add({
        'role': turn['role'] == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': turn['text'] ?? ''}
        ],
      });
    }

    // Add current user prompt
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final Map<String, dynamic> requestBody = {
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1500,
      },
    };

    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      requestBody['systemInstruction'] = {
        'parts': [
          {'text': systemInstruction}
        ]
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String? ?? 'No response generated.';
          }
        }
        return 'Empty response from Gemini.';
      } else {
        final errData = jsonDecode(response.body);
        final errMsg = errData['error']?['message'] ?? response.body;
        throw Exception('Gemini API Error (${response.statusCode}): $errMsg');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Failed to connect to Gemini API: $e');
    }
  }

  /// Verifies if an API key is valid by sending a tiny ping prompt
  static Future<bool> validateApiKey(String apiKey) async {
    try {
      final res = await sendMessage(
        apiKey: apiKey,
        prompt: 'Ping test. Reply with: OK',
      );
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

