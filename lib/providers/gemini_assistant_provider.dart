import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gemini_service.dart';
import '../services/firebase_ai_service.dart';

class GeminiMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  GeminiMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GeminiMessage.fromMap(Map<String, dynamic> map) => GeminiMessage(
        id: map['id'] ?? '',
        text: map['text'] ?? '',
        isUser: map['isUser'] ?? false,
        timestamp: map['timestamp'] != null
            ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class GeminiAssistantProvider extends ChangeNotifier {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  String? _personalApiKey;
  bool _isLoading = false;
  String? _errorMessage;
  final List<GeminiMessage> _messages = [];
  String? _currentUserId;
  bool _isInitialized = false;
  int _initializationEpoch = 0;

  /// The teacher's own API key — private to this user only.
  String? get apiKey => _personalApiKey?.trim().isNotEmpty == true ? _personalApiKey!.trim() : null;
  bool get hasPersonalKey => _personalApiKey != null && _personalApiKey!.trim().isNotEmpty;
  bool get isFirebaseAiConnected => hasPersonalKey;
  bool get hasKey => hasPersonalKey;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<GeminiMessage> get messages => _messages;
  String get activeModel => detectedProvider.defaultModel;

  /// Detects which AI provider this key belongs to (Gemini, OpenAI, Groq, Claude, etc.)
  AiProvider get detectedProvider =>
      apiKey != null ? GeminiService.detectProvider(apiKey!) : AiProvider.unknown;

  String get providerDisplayName => detectedProvider.displayName;

  /// Secure-storage key scoped to this teacher so credentials stay on-device.
  String _secureKey(String uid) => 'ai_api_key_$uid';

  String _historyKey(String uid) => 'gemini_chat_$uid';

  /// Load this teacher's key from secure storage, migrating older preference data.
  Future<void> init({String? userId}) async {
    if (_isInitialized && _currentUserId == userId) return;

    final epoch = ++_initializationEpoch;
    _currentUserId = userId;
    _personalApiKey = null;
    _messages.clear();
    _errorMessage = null;
    _isInitialized = false;
    String? storedKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _initializationEpoch) return;
      if (userId != null) {
        storedKey = await _secureStorage.read(key: _secureKey(userId));
        if (epoch != _initializationEpoch) return;

        if (storedKey == null || storedKey.trim().isEmpty) {
          final legacyKey = prefs.getString('gemini_api_key_$userId') ??
              prefs.getString('teacher_gemini_api_key');
          if (legacyKey != null && legacyKey.trim().isNotEmpty) {
            await _secureStorage.write(
              key: _secureKey(userId),
              value: legacyKey.trim(),
            );
            if (epoch != _initializationEpoch) return;
            storedKey = legacyKey;
          }
        }

        await prefs.remove('gemini_api_key_$userId');
        await prefs.remove('teacher_gemini_api_key');
      }

      final historyJson = userId == null
          ? null
          : prefs.getString(_historyKey(userId)) ??
              prefs.getString('teacher_gemini_chat_history');
      if (historyJson != null) {
        try {
          final list = jsonDecode(historyJson) as List;
          _messages.addAll(list.map((m) => GeminiMessage.fromMap(m)));
          if (userId != null && prefs.getString(_historyKey(userId)) == null) {
            await prefs.setString(_historyKey(userId), historyJson);
          }
        } catch (e) {
          _errorMessage = 'Unable to load saved AI conversation history: $e';
        }
      }
      if (userId != null) {
        await prefs.remove('teacher_gemini_chat_history');
      }
    } catch (e) {
      if (epoch == _initializationEpoch) {
        _errorMessage = 'Unable to load the securely stored AI key: $e';
      }
    }

    if (epoch != _initializationEpoch) return;
    _personalApiKey = userId == null ? null : storedKey;
    _isInitialized = true;
    notifyListeners();
  }

  /// Validates and stores this teacher's API key in OS-backed secure storage.
  Future<bool> setApiKey(String key) async {
    final clean = key.trim();
    if (clean.isEmpty) {
      await removeApiKey();
      return _errorMessage == null;
    }

    final userId = _currentUserId;
    if (userId == null || !_isInitialized) {
      _errorMessage = 'Sign in as a teacher before saving an AI key.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isValid = await GeminiService.validateApiKey(clean);
      if (!isValid) {
        _errorMessage =
            'Invalid API key or unable to reach AI servers. Please check your key.';
        return false;
      }

      if (_currentUserId != userId) return false;

      await _secureStorage.write(key: _secureKey(userId), value: clean);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('gemini_api_key_$userId');
      await prefs.remove('teacher_gemini_api_key');
      if (_currentUserId != userId) return false;
      _personalApiKey = clean;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Could not securely save the AI key on this device: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Removes this teacher's key from secure storage on this device.
  Future<void> removeApiKey() async {
    _errorMessage = null;
    final userId = _currentUserId;
    if (userId != null) {
      try {
        await _secureStorage.delete(key: _secureKey(userId));
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('gemini_api_key_$userId');
        await prefs.remove('teacher_gemini_api_key');
        if (_currentUserId == userId) {
          _personalApiKey = null;
        }
      } catch (e) {
        if (_currentUserId == userId) {
          _errorMessage = 'Could not remove the securely stored AI key: $e';
        }
      }
    } else {
      _personalApiKey = null;
    }
    notifyListeners();
  }

  Future<void> sendMessage(String text, {String? classContext}) async {
    final effectiveKey = apiKey ?? '';
    if (!hasKey || text.trim().isEmpty) {
      if (!hasKey) {
        _errorMessage = 'Lodix AI key is required. Tap the key icon to connect.';
        notifyListeners();
      }
      return;
    }

    final userMsg = GeminiMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await _saveHistory();

    // Sync user message to Firebase if available
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      FirebaseAiService.saveChatMessage(
        userId: _currentUserId!,
        messageId: userMsg.id,
        text: userMsg.text,
        isUser: true,
        timestamp: userMsg.timestamp,
      );
    }

    final history = _messages.sublist(0, _messages.length - 1).map((m) {
      return {
        'role': m.isUser ? 'user' : 'assistant',
        'text': m.text,
      };
    }).toList();

    final systemInstruction =
        'You are Lodix, an expert pedagogical AI teaching assistant for EduSync. '
        'Assist the teacher with creating classroom activities, quizzes, lesson plans, rubrics, '
        'and providing constructive feedback for students. Keep answers structured, practical, and clear.'
        '${classContext != null ? "\nClass Context: $classContext" : ""}';

    try {
      final responseText = await GeminiService.sendMessage(
        apiKey: effectiveKey,
        prompt: text.trim(),
        chatHistory: history,
        systemInstruction: systemInstruction,
        modelName: activeModel,
      );

      final assistantMsg = GeminiMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.add(assistantMsg);

      // Sync assistant message to Firebase
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        FirebaseAiService.saveChatMessage(
          userId: _currentUserId!,
          messageId: assistantMsg.id,
          text: assistantMsg.text,
          isUser: false,
          timestamp: assistantMsg.timestamp,
        );
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
      await _saveHistory();
    }
  }

  Future<void> clearChat() async {
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    if (_currentUserId != null) {
      await prefs.remove(_historyKey(_currentUserId!));
    }
    await prefs.remove('teacher_gemini_chat_history');

    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      FirebaseAiService.clearFirebaseChatHistory(_currentUserId!);
    }

    notifyListeners();
  }

  Future<void> _saveHistory() async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey(_currentUserId!),
      jsonEncode(_messages.map((m) => m.toMap()).toList()),
    );
  }
}
