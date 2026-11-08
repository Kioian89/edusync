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

  /// Effective API key: Personal/teacher key first, then school-wide Firebase key.
  /// No compile-time or hardcoded keys — the teacher always provides the key.
  String? get apiKey {
    if (_personalApiKey != null && _personalApiKey!.trim().isNotEmpty) {
      return _personalApiKey!.trim();
    }
    if (_firebaseApiKey != null && _firebaseApiKey!.trim().isNotEmpty) {
      return _firebaseApiKey!.trim();
    }
    return null;
  }
  bool get hasPersonalKey => _personalApiKey != null && _personalApiKey!.trim().isNotEmpty;
  bool get isFirebaseAiConnected =>
      (_firebaseApiKey != null && _firebaseApiKey!.trim().isNotEmpty);
  bool get hasKey =>
      (apiKey != null && apiKey!.trim().isNotEmpty);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<GeminiMessage> get messages => _messages;
  String get activeModel => _activeModel;

  /// Initialize provider: load local cache, and sync Firebase Gemini configuration
  Future<void> init({String? userId}) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    _personalApiKey = prefs.getString('teacher_gemini_api_key');

    // 1. Fetch school-wide Firebase Gemini configuration (set by teacher)
    try {
      if (FirebaseAiService.isAvailable) {
        final fbConfig = await FirebaseAiService.fetchFirebaseGeminiConfig();
        if (fbConfig != null && fbConfig['isEnabled'] != false && fbConfig['apiKey'] != null) {
          _firebaseApiKey = (fbConfig['apiKey'] as String?)?.trim();
          if (fbConfig['model'] != null) {
            _activeModel = fbConfig['model'] as String;
          }
        }
        // No auto-seeding — only teacher can set the key via the UI
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

  /// Sets the teacher's Gemini API key — saves locally AND syncs to Firebase
  /// so ALL users in the school (teachers + students) can use AI features
  /// without entering a key themselves.
  Future<bool> setApiKey(String key) async {
    final clean = key.trim();
    if (clean.isEmpty) {
      _personalApiKey = null;
      _firebaseApiKey = null;
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
      // Save locally for quick access
      _personalApiKey = clean;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('teacher_gemini_api_key', clean);

      // Always sync to Firebase so all users school-wide get AI access
      _firebaseApiKey = clean;
      FirebaseAiService.setFirebaseGeminiConfig(
        apiKey: clean,
        model: _activeModel,
        isEnabled: true,
      ).catchError((e) => debugPrint('Firebase key sync note: $e'));

      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Invalid Gemini API key or unable to reach Google servers.';
      notifyListeners();
      return false;
    }
  }

  /// Removes the teacher's key locally and disables it school-wide in Firebase.
  Future<void> setFirebaseCentralKey(String key, {String model = 'gemini-2.0-flash'}) async {
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
    _firebaseApiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('teacher_gemini_api_key');
    // Disable school-wide key in Firebase
    FirebaseAiService.setFirebaseGeminiConfig(
      apiKey: '',
      isEnabled: false,
    ).catchError((e) => debugPrint('Firebase key remove note: $e'));
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
