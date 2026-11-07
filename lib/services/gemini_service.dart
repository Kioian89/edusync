import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'firebase_ai_service.dart';

class GeminiService {
  static const String defaultModelName = 'gemini-3.8-flash';

  /// Default API key loaded securely from compile-time dart-define
  static String get defaultApiKey {
    return const String.fromEnvironment('GEMINI_API_KEY');
  }

  /// Sends a prompt with optional context and chat history to Google Gemini API
  /// Uses official google_generative_ai SDK with resilient HTTP fallback.
  static Future<String> sendMessage({
    required String apiKey,
    required String prompt,
    List<Map<String, String>> chatHistory = const [],
    String? systemInstruction,
    String modelName = defaultModelName,
  }) async {
    final effectiveKey = apiKey.trim().isNotEmpty ? apiKey.trim() : defaultApiKey;

    // 0. Primary: Try Firebase AI Logic SDK first if Firebase is available
    if (FirebaseAiService.isAvailable) {
      final fbResponse = await FirebaseAiService.generateWithFirebaseAI(
        prompt: prompt,
        chatHistory: chatHistory,
        systemInstruction: systemInstruction,
        modelName: modelName,
      );
      if (fbResponse != null && fbResponse.isNotEmpty) {
        return fbResponse;
      }
    }

    if (effectiveKey.isEmpty) {
      throw Exception('Gemini API Key is missing. Please configure your key in settings or Firebase.');
    }

    try {
      // 1. Primary: Use Google Generative AI official SDK
      final model = GenerativeModel(
        model: modelName,
        apiKey: effectiveKey,
        systemInstruction: systemInstruction != null && systemInstruction.isNotEmpty
            ? Content.system(systemInstruction)
            : null,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 1500,
        ),
      );

      final historyContent = chatHistory.map((turn) {
        final isModel = turn['role'] == 'assistant' || turn['role'] == 'model';
        return isModel
            ? Content.model([TextPart(turn['text'] ?? '')])
            : Content.text(turn['text'] ?? '');
      }).toList();

      final chat = model.startChat(history: historyContent);
      final response = await chat.sendMessage(Content.text(prompt));

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      }
    } catch (e) {
      debugPrint('google_generative_ai SDK exception, trying direct endpoint: $e');
    }

    // 2. Direct HTTP Fallback in case of client package edge cases
    return _sendViaHttpFallback(
      apiKey: effectiveKey,
      prompt: prompt,
      chatHistory: chatHistory,
      systemInstruction: systemInstruction,
      modelName: modelName,
    );
  }

  static Future<String> _sendViaHttpFallback({
    required String apiKey,
    required String prompt,
    List<Map<String, String>> chatHistory = const [],
    String? systemInstruction,
    required String modelName,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    final List<Map<String, dynamic>> contents = [];

    for (final turn in chatHistory) {
      contents.add({
        'role': (turn['role'] == 'assistant' || turn['role'] == 'model') ? 'model' : 'user',
        'parts': [
          {'text': turn['text'] ?? ''}
        ],
      });
    }

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

  /// High-level method for AI pedagogical activity generation
  static Future<Map<String, String>> generateActivityTask({
    required String apiKey,
    required String topic,
    List<String> fileNames = const [],
    String gradeLevel = 'High School',
  }) async {
    final prompt =
        'You are an expert curriculum developer. Based on the topic "$topic" '
        '${fileNames.isNotEmpty ? "and attached files: ${fileNames.join(', ')}" : ""}, '
        'generate a structured student learning activity in JSON format with exactly 3 keys:\n'
        '1. "description": A thorough lesson prompt, guide questions in Parts I, II, and III.\n'
        '2. "answerSheetTemplate": A clean, formatted fill-in worksheet template for the student.\n'
        '3. "teacherKey": An evaluation rubric and answer guide with suggested point values.\n'
        'Return ONLY valid raw JSON with keys: description, answerSheetTemplate, teacherKey.';

    try {
      final raw = await sendMessage(
        apiKey: apiKey,
        prompt: prompt,
        systemInstruction: 'Output valid JSON only without markdown formatting.',
      );

      // Clean markdown code blocks if returned
      String cleaned = raw.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }

      final parsed = jsonDecode(cleaned.trim()) as Map<String, dynamic>;
      return {
        'title': topic.isNotEmpty ? topic : 'Classroom Learning Activity',
        'description': parsed['description']?.toString() ?? '',
        'answerSheetTemplate': parsed['answerSheetTemplate']?.toString() ?? '',
        'teacherKey': parsed['teacherKey']?.toString() ?? '',
      };
    } catch (e) {
      debugPrint('AI Activity generation error: $e');
      rethrow;
    }
  }
}
