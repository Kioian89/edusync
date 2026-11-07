import 'dart:convert';
import 'package:flutter/material.dart';
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
  String? _personalApiKey;
  String? _firebaseApiKey;
  String _activeModel = GeminiService.defaultModelName;
  bool _isLoading = false;
  String? _errorMessage;
  final List<GeminiMessage> _messages = [];
  String? _currentUserId;

  static const String compileTimeApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Effective API key: Personal key takes precedence over central Firebase key, then compile-time key
  String? get apiKey =>
      _personalApiKey ??
      _firebaseApiKey ??
      (compileTimeApiKey.isNotEmpty ? compileTimeApiKey : null);
  bool get hasPersonalKey => _personalApiKey != null && _personalApiKey!.trim().isNotEmpty;
  bool get isFirebaseAiConnected =>
      FirebaseAiService.isAvailable ||
      (_firebaseApiKey != null && _firebaseApiKey!.trim().isNotEmpty);
  bool get hasKey =>
      (apiKey != null && apiKey!.trim().isNotEmpty) ||
      FirebaseAiService.isAvailable;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<GeminiMessage> get messages => _messages;
  String get activeModel => _activeModel;

  /// Initialize provider: load local cache, and sync Firebase Gemini configuration
  Future<void> init({String? userId}) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    _personalApiKey = prefs.getString('teacher_gemini_api_key');

    // 1. Fetch Firebase-managed Gemini configuration
    try {
      if (FirebaseAiService.isAvailable) {
        final fbConfig = await FirebaseAiService.fetchFirebaseGeminiConfig();
        if (fbConfig != null && fbConfig['isEnabled'] != false) {
          _firebaseApiKey = fbConfig['apiKey'] as String?;
          if (fbConfig['model'] != null) {
            _activeModel = fbConfig['model'] as String;
          }
        }
      }
    } catch (_) {}

    // 2. Load cached chat history
    final historyJson = prefs.getString('teacher_gemini_chat_history');
    if (historyJson != null) {
      try {
        final list = jsonDecode(historyJson) as List;
        _messages.clear();
        _messages.addAll(list.map((m) => GeminiMessage.fromMap(m)));
      } catch (_) {}
    }

    notifyListeners();
  }

  /// Sets or updates personal Gemini API key
  Future<bool> setApiKey(String key) async {
    final clean = key.trim();
    if (clean.isEmpty) {
      _personalApiKey = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('teacher_gemini_api_key');
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final isValid = await GeminiService.validateApiKey(clean);
    _isLoading = false;

    if (isValid) {
      _personalApiKey = clean;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('teacher_gemini_api_key', clean);
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Invalid Gemini API key or unable to reach Google servers.';
      notifyListeners();
      return false;
    }
  }

  /// Saves the Gemini API key centrally into Firebase (for all teachers in school)
  Future<void> setFirebaseCentralKey(String key, {String model = 'gemini-1.5-flash'}) async {
    final clean = key.trim();
    if (clean.isEmpty) return;

    await FirebaseAiService.setFirebaseGeminiConfig(
      apiKey: clean,
      model: model,
      isEnabled: true,
    );
    _firebaseApiKey = clean;
    _activeModel = model;
    notifyListeners();
  }

  Future<void> removeApiKey() async {
    _personalApiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('teacher_gemini_api_key');
    notifyListeners();
  }

  Future<void> sendMessage(String text, {String? classContext}) async {
    final effectiveKey = apiKey ?? '';
    if (!hasKey || text.trim().isEmpty) return;

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
        'You are an expert pedagogical AI teaching assistant for EduSync. '
        'Assist the teacher with creating classroom activities, quizzes, lesson plans, rubrics, '
        'and providing constructive feedback for students. Keep answers structured, practical, and clear.'
        '${classContext != null ? "\nClass Context: $classContext" : ""}';

    try {
      final responseText = await GeminiService.sendMessage(
        apiKey: effectiveKey,
        prompt: text.trim(),
        chatHistory: history,
        systemInstruction: systemInstruction,
        modelName: _activeModel,
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
    await prefs.remove('teacher_gemini_chat_history');

    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      FirebaseAiService.clearFirebaseChatHistory(_currentUserId!);
    }

    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'teacher_gemini_chat_history',
      jsonEncode(_messages.map((m) => m.toMap()).toList()),
    );
  }
}
