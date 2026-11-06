import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gemini_service.dart';

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
        id: map['id'],
        text: map['text'],
        isUser: map['isUser'],
        timestamp: DateTime.parse(map['timestamp']),
      );
}

class GeminiAssistantProvider extends ChangeNotifier {
  String? _apiKey;
  bool _isLoading = false;
  String? _errorMessage;
  final List<GeminiMessage> _messages = [];

  String? get apiKey => _apiKey;
  bool get hasKey => _apiKey != null && _apiKey!.trim().isNotEmpty;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<GeminiMessage> get messages => _messages;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('teacher_gemini_api_key');
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

  Future<bool> setApiKey(String key) async {
    final clean = key.trim();
    if (clean.isEmpty) {
      _apiKey = null;
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
      _apiKey = clean;
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

  Future<void> removeApiKey() async {
    _apiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('teacher_gemini_api_key');
    notifyListeners();
  }

  Future<void> sendMessage(String text, {String? classContext}) async {
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
        apiKey: _apiKey!,
        prompt: text.trim(),
        chatHistory: history,
        systemInstruction: systemInstruction,
      );

      final assistantMsg = GeminiMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.add(assistantMsg);
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

