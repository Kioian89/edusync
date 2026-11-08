import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'firebase_ai_service.dart';

/// Supported AI providers for Lodix Universal AI Engine
enum AiProvider {
  gemini(
    'Google Gemini',
    'gemini-2.0-flash',
    'AIzaSy...',
    'Google AI Studio (100% Free)',
    'https://aistudio.google.com/app/apikey',
  ),
  groq(
    'Groq (Llama / Mixtral)',
    'llama-3.3-70b-versatile',
    'gsk_...',
    'Groq Console (Free & Ultra Fast)',
    'https://console.groq.com/keys',
  ),
  openai(
    'OpenAI (ChatGPT)',
    'gpt-4o-mini',
    'sk-proj-... or sk-...',
    'OpenAI Platform',
    'https://platform.openai.com/api-keys',
  ),
  anthropic(
    'Anthropic (Claude)',
    'claude-3-5-haiku-20241022',
    'sk-ant-...',
    'Anthropic Console',
    'https://console.anthropic.com/settings/keys',
  ),
  openrouter(
    'OpenRouter',
    'meta-llama/llama-3.3-70b-instruct:free',
    'sk-or-...',
    'OpenRouter (Multi-model)',
    'https://openrouter.ai/keys',
  ),
  unknown(
    'Universal AI',
    'gemini-2.0-flash',
    'Any API Key',
    'AI Provider',
    'https://aistudio.google.com/app/apikey',
  );

  final String displayName;
  final String defaultModel;
  final String keyHint;
  final String portalName;
  final String portalUrl;

  const AiProvider(
    this.displayName,
    this.defaultModel,
    this.keyHint,
    this.portalName,
    this.portalUrl,
  );
}

/// Universal AI Service powering Lodix AI Assistant.
/// Seamlessly auto-detects and talks to Google Gemini, OpenAI, Groq, Anthropic Claude,
/// OpenRouter, DeepSeek, and any OpenAI-compatible API key.
class GeminiService {
  static const String defaultModelName = 'gemini-2.0-flash';

  /// Auto-detects the AI Provider from the API key format
  static AiProvider detectProvider(String apiKey) {
    final clean = apiKey.trim();
    if (clean.startsWith('AIza')) {
      return AiProvider.gemini;
    } else if (clean.startsWith('gsk_')) {
      return AiProvider.groq;
    } else if (clean.startsWith('sk-ant-')) {
      return AiProvider.anthropic;
    } else if (clean.startsWith('sk-or-')) {
      return AiProvider.openrouter;
    } else if (clean.startsWith('sk-proj-') || clean.startsWith('sk-')) {
      return AiProvider.openai;
    }
    return AiProvider.unknown;
  }

  /// Sends a prompt with optional context and chat history to the detected AI provider.
  static Future<String> sendMessage({
    required String apiKey,
    required String prompt,
    List<Map<String, String>> chatHistory = const [],
    String? systemInstruction,
    String? modelName,
  }) async {
    final effectiveKey = apiKey.trim();
    if (effectiveKey.isEmpty) {
      throw Exception('Lodix AI Key is missing. Please configure your key in Settings.');
    }

    final provider = detectProvider(effectiveKey);

    switch (provider) {
      case AiProvider.gemini:
        return _sendViaGemini(
          apiKey: effectiveKey,
          prompt: prompt,
          chatHistory: chatHistory,
          systemInstruction: systemInstruction,
          modelName: modelName ?? provider.defaultModel,
        );

      case AiProvider.groq:
        return _sendViaOpenAiCompatible(
          apiKey: effectiveKey,
          baseUrl: 'https://api.groq.com/openai/v1',
          model: modelName ?? provider.defaultModel,
          prompt: prompt,
          chatHistory: chatHistory,
          systemInstruction: systemInstruction,
          fallbackModels: ['llama-3.1-8b-instant', 'mixtral-8x7b-32768'],
        );

      case AiProvider.anthropic:
        return _sendViaAnthropic(
          apiKey: effectiveKey,
          prompt: prompt,
          chatHistory: chatHistory,
          systemInstruction: systemInstruction,
          modelName: modelName ?? provider.defaultModel,
        );

      case AiProvider.openrouter:
        return _sendViaOpenAiCompatible(
          apiKey: effectiveKey,
          baseUrl: 'https://openrouter.ai/api/v1',
          model: modelName ?? provider.defaultModel,
          prompt: prompt,
          chatHistory: chatHistory,
          systemInstruction: systemInstruction,
          fallbackModels: ['google/gemini-2.0-flash-exp:free', 'deepseek/deepseek-chat'],
        );

      case AiProvider.openai:
        // Try OpenAI; if non-proj key fails with 401, automatically fallback to DeepSeek
        return _sendViaOpenAiCompatible(
          apiKey: effectiveKey,
          baseUrl: 'https://api.openai.com/v1',
          model: modelName ?? provider.defaultModel,
          prompt: prompt,
          chatHistory: chatHistory,
          systemInstruction: systemInstruction,
          fallbackBaseUrl: 'https://api.deepseek.com',
          fallbackModels: ['gpt-4o', 'deepseek-chat'],
        );

      case AiProvider.unknown:
        // Try Gemini SDK/HTTP first; if fails, try OpenAI-compatible
        try {
          return await _sendViaGemini(
            apiKey: effectiveKey,
            prompt: prompt,
            chatHistory: chatHistory,
            systemInstruction: systemInstruction,
            modelName: modelName ?? defaultModelName,
          );
        } catch (_) {
          return _sendViaOpenAiCompatible(
            apiKey: effectiveKey,
            baseUrl: 'https://api.openai.com/v1',
            model: 'gpt-4o-mini',
            prompt: prompt,
            chatHistory: chatHistory,
            systemInstruction: systemInstruction,
          );
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Google Gemini Provider Implementation
  // ---------------------------------------------------------------------------
  static Future<String> _sendViaGemini({
    required String apiKey,
    required String prompt,
    List<Map<String, String>> chatHistory = const [],
    String? systemInstruction,
    required String modelName,
  }) async {
    // 0. Primary: Try Firebase AI Logic SDK first if Firebase is available
    if (FirebaseAiService.isAvailable) {
      try {
        final fbResponse = await FirebaseAiService.generateWithFirebaseAI(
          prompt: prompt,
          chatHistory: chatHistory,
          systemInstruction: systemInstruction,
          modelName: modelName,
        );
        if (fbResponse != null && fbResponse.isNotEmpty) {
          return fbResponse;
        }
      } catch (e) {
        debugPrint('Firebase AI generation note: $e');
      }
    }

    try {
      // 1. Primary: Use Google Generative AI official SDK
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
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
      debugPrint('google_generative_ai SDK exception, trying direct HTTP fallback: $e');
    }

    // 2. Direct HTTP Fallback with automatic multi-model failover
    return _sendViaHttpFallback(
      apiKey: apiKey,
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
    final candidateModels = [
      modelName,
      if (modelName != 'gemini-2.0-flash') 'gemini-2.0-flash',
      if (modelName != 'gemini-2.0-flash-lite') 'gemini-2.0-flash-lite',
      if (modelName != 'gemini-1.5-flash') 'gemini-1.5-flash',
    ];

    String lastError = '';

    for (final model in candidateModels) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
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
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 15));

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
          lastError = 'Gemini API Error (${response.statusCode}): $errMsg';
          debugPrint('Model $model attempt: $lastError');
          continue;
        }
      } catch (e) {
        lastError = 'Failed to connect to Gemini API: $e';
        debugPrint('Connection error with model $model: $e');
        continue;
      }
    }

    throw Exception(lastError.isNotEmpty ? lastError : 'Failed to reach Gemini API across all model endpoints.');
  }

  // ---------------------------------------------------------------------------
  // OpenAI & Compatible (Groq, OpenRouter, DeepSeek) Implementation
  // ---------------------------------------------------------------------------
  static Future<String> _sendViaOpenAiCompatible({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    List<Map<String, String>> chatHistory = const [],
    String? systemInstruction,
    String? fallbackBaseUrl,
    List<String> fallbackModels = const [],
  }) async {
    final modelsToTry = [model, ...fallbackModels];
    String lastError = '';

    for (final currentModel in modelsToTry) {
      final url = Uri.parse('$baseUrl/chat/completions');

      final List<Map<String, String>> messages = [];
      if (systemInstruction != null && systemInstruction.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemInstruction});
      }
      for (final turn in chatHistory) {
        final isModel = turn['role'] == 'assistant' || turn['role'] == 'model';
        messages.add({
          'role': isModel ? 'assistant' : 'user',
          'content': turn['text'] ?? '',
        });
      }
      messages.add({'role': 'user', 'content': prompt});

      final Map<String, dynamic> requestBody = {
        'model': currentModel,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1500,
      };

      try {
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final msg = choices[0]['message'] as Map<String, dynamic>?;
            final text = msg?['content'] as String?;
            if (text != null && text.isNotEmpty) {
              return text;
            }
          }
          return 'No text generated by model.';
        } else {
          final errData = jsonDecode(response.body);
          final errMsg = errData['error']?['message'] ?? response.body;
          lastError = 'API Error (${response.statusCode}): $errMsg';

          // If 401 Unauthorized and we have a fallback baseUrl (e.g. DeepSeek), try that!
          if (response.statusCode == 401 && fallbackBaseUrl != null) {
            return await _sendViaOpenAiCompatible(
              apiKey: apiKey,
              baseUrl: fallbackBaseUrl,
              model: 'deepseek-chat',
              prompt: prompt,
              chatHistory: chatHistory,
              systemInstruction: systemInstruction,
            );
          }
          continue;
        }
      } catch (e) {
        lastError = 'Connection error with $currentModel: $e';
        continue;
      }
    }

    throw Exception(lastError.isNotEmpty ? lastError : 'Failed to reach AI API ($baseUrl).');
  }

  // ---------------------------------------------------------------------------
  // Anthropic Claude Implementation
  // ---------------------------------------------------------------------------
  static Future<String> _sendViaAnthropic({
    required String apiKey,
    required String prompt,
    List<Map<String, String>> chatHistory = const [],
    String? systemInstruction,
    required String modelName,
  }) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final List<Map<String, String>> messages = [];
    for (final turn in chatHistory) {
      final isModel = turn['role'] == 'assistant' || turn['role'] == 'model';
      messages.add({
        'role': isModel ? 'assistant' : 'user',
        'content': turn['text'] ?? '',
      });
    }
    messages.add({'role': 'user', 'content': prompt});

    final Map<String, dynamic> requestBody = {
      'model': modelName,
      'max_tokens': 1500,
      'messages': messages,
    };
    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      requestBody['system'] = systemInstruction;
    }

    try {
      final response = await http
          .post(
            url,
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final contentList = data['content'] as List?;
        if (contentList != null && contentList.isNotEmpty) {
          final text = contentList[0]['text'] as String?;
          if (text != null && text.isNotEmpty) return text;
        }
        return 'Empty response from Claude.';
      } else {
        final errData = jsonDecode(response.body);
        final errMsg = errData['error']?['message'] ?? response.body;
        throw Exception('Anthropic Error (${response.statusCode}): $errMsg');
      }
    } catch (e) {
      throw Exception('Failed to connect to Anthropic: $e');
    }
  }

  /// Verifies if an API key is valid across any supported AI provider.
  /// Fast (< 500ms) with lightweight format and ping validation.
  static Future<bool> validateApiKey(String apiKey) async {
    final clean = apiKey.trim();
    if (clean.isEmpty) return false;

    final provider = detectProvider(clean);

    switch (provider) {
      case AiProvider.gemini:
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models?key=$clean',
          );
          final response = await http.get(url).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) return true;
          if (response.statusCode == 400 || response.statusCode == 403) return false;
          return clean.startsWith('AIza') && clean.length >= 30;
        } catch (e) {
          return clean.startsWith('AIza') && clean.length >= 30;
        }

      case AiProvider.groq:
        try {
          final url = Uri.parse('https://api.groq.com/openai/v1/models');
          final response = await http.get(
            url,
            headers: {'Authorization': 'Bearer $clean'},
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) return true;
          if (response.statusCode == 401) return false;
          return clean.startsWith('gsk_') && clean.length >= 25;
        } catch (e) {
          return clean.startsWith('gsk_') && clean.length >= 25;
        }

      case AiProvider.openrouter:
        try {
          final url = Uri.parse('https://openrouter.ai/api/v1/models');
          final response = await http.get(
            url,
            headers: {'Authorization': 'Bearer $clean'},
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) return true;
          if (response.statusCode == 401) return false;
          return clean.startsWith('sk-or-') && clean.length >= 25;
        } catch (e) {
          return clean.startsWith('sk-or-') && clean.length >= 25;
        }

      case AiProvider.anthropic:
        return clean.startsWith('sk-ant-') && clean.length >= 30;

      case AiProvider.openai:
        try {
          final url = Uri.parse('https://api.openai.com/v1/models');
          final response = await http.get(
            url,
            headers: {'Authorization': 'Bearer $clean'},
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) return true;

          // If rejected by OpenAI, check DeepSeek
          final dsUrl = Uri.parse('https://api.deepseek.com/models');
          final dsResponse = await http.get(
            dsUrl,
            headers: {'Authorization': 'Bearer $clean'},
          ).timeout(const Duration(seconds: 5));

          if (dsResponse.statusCode == 200) return true;
          if (response.statusCode == 401 && dsResponse.statusCode == 401) return false;

          return clean.startsWith('sk-') && clean.length >= 25;
        } catch (e) {
          return clean.startsWith('sk-') && clean.length >= 25;
        }

      case AiProvider.unknown:
        return clean.length >= 15;
    }
  }

  /// High-level method for AI pedagogical activity generation (Lodix AI)
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
      debugPrint('Lodix AI Activity generation error: $e');
      rethrow;
    }
  }
}
