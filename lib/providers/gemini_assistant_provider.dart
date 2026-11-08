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
  // ignore: prefer_final_fields
  String _activeModel = GeminiService.defaultModelName;
  bool _isLoading = false;
  String? _errorMessage;
  final List<GeminiMessage> _messages = [];
  String? _currentUserId;

  /// The teacher's own API key — private to this user only.
  String? get apiKey => _personalApiKey?.trim().isNotEmpty == true ? _personalApiKey!.trim() : null;
  bool get hasPersonalKey => _personalApiKey != null && _personalApiKey!.trim().isNotEmpty;
  bool get isFirebaseAiConnected => hasPersonalKey;
  bool get hasKey => hasPersonalKey;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<GeminiMessage> get messages => _messages;
  String get activeModel => _activeModel;

  /// Pref key scoped to this teacher's userId so keys never bleed across accounts.
  String _prefKey(String uid) => 'gemini_api_key_$uid';

  /// Initialize: load this teacher's personal key from local storage.
  /// No global Firebase config is ever read — key is strictly per-user.
  Future<void> init({String? userId}) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();

    // Load key scoped to this user (fallback to legacy key for existing installs)
    if (userId != null) {
      _personalApiKey = prefs.getString(_prefKey(userId))
          ?? prefs.getString('teacher_gemini_api_key');
    } else {
      _personalApiKey = prefs.getString('teacher_gemini_api_key');
    }

    // Load cached chat history
    final histKey = userId != null ? 'gemini_chat_$userId' : 'teacher_gemini_chat_history';
    final historyJson = prefs.getString(histKey);
    if (historyJson != null) {
      try {
        final list = jsonDecode(historyJson) as List;
        _messages.clear();
        _messages.addAll(list.map((m) => GeminiMessage.fromMap(m)));
      } catch (_) {}
    }

    notifyListeners();
  }

  /// Sets this teacher's personal Gemini API key.
  /// Stored locally under a user-scoped key — NEVER shared with other users.
  Future<bool> setApiKey(String key) async {
    final clean = key.trim();
    if (clean.isEmpty) {
      _personalApiKey = null;
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserId != null) await prefs.remove(_prefKey(_currentUserId!));
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
      // Save under user-scoped key
      if (_currentUserId != null) {
        await prefs.setString(_prefKey(_currentUserId!), clean);
      }
      // Also save legacy key for backwards compat
      await prefs.setString('teacher_gemini_api_key', clean);
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Invalid Gemini API key or unable to reach Google servers.';
      notifyListeners();
      return false;
    }
  }

  /// Removes this teacher's key from their device only.
  Future<void> removeApiKey() async {
    _personalApiKey = null;
    final prefs = await SharedPreferences.getInstance();
    if (_currentUserId != null) await prefs.remove(_prefKey(_currentUserId!));
    await prefs.remove('teacher_gemini_api_key');
    notifyListeners();
  }

  Future<void> sendMessage(String text, {String? classContext}) async {
    final effectiveKey = apiKey ?? '';
    if (!hasKey || text.trim().isEmpty) {
      if (!hasKey) {
        _errorMessage = 'Gemini API key is required. Tap the key icon to connect.';
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
