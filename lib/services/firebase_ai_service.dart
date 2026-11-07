import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Service connecting Gemini AI with the official Firebase AI Logic SDK
/// and Cloud Firestore backend.
class FirebaseAiService {
  static bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static FirebaseFirestore? get _db {
    if (!isAvailable) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('Firestore instance unavailable: $e');
      return null;
    }
  }

  /// Gets a GenerativeModel instance powered by the Firebase AI Logic SDK.
  /// Automatically authenticates through Firebase project infrastructure.
  static GenerativeModel? getFirebaseAiModel({
    String modelName = 'gemini-1.5-flash',
    String? systemInstruction,
  }) {
    if (!isAvailable) return null;
    try {
      final ai = FirebaseAI.googleAI();
      return ai.generativeModel(
        model: modelName,
        systemInstruction: systemInstruction != null && systemInstruction.isNotEmpty
            ? Content.system(systemInstruction)
            : null,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 1500,
        ),
      );
    } catch (e) {
      debugPrint('Firebase AI Logic SDK model init: $e');
      return null;
    }
  }

  /// Generates a response directly using the Firebase AI Logic SDK.
  static Future<String?> generateWithFirebaseAI({
    required String prompt,
    List<Map<String, String>> chatHistory = const [],
    String? systemInstruction,
    String modelName = 'gemini-1.5-flash',
  }) async {
    final model = getFirebaseAiModel(
      modelName: modelName,
      systemInstruction: systemInstruction,
    );
    if (model == null) return null;

    try {
      final historyContent = chatHistory.map((turn) {
        final isModel = turn['role'] == 'assistant' || turn['role'] == 'model';
        return isModel
            ? Content.model([TextPart(turn['text'] ?? '')])
            : Content.text(turn['text'] ?? '');
      }).toList();

      final chat = model.startChat(history: historyContent);
      final response = await chat.sendMessage(Content.text(prompt));
      return response.text;
    } catch (e) {
      debugPrint('Firebase AI Logic SDK generation failed, will try key fallback: $e');
      return null;
    }
  }

  /// Fetches shared Gemini AI configuration stored in Firebase Cloud Firestore.
  static Future<Map<String, dynamic>?> fetchFirebaseGeminiConfig() async {
    final db = _db;
    if (db == null) return null;

    try {
      final doc = await db.collection('config').doc('gemini').get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }

      final fallbackDoc = await db.collection('system').doc('ai').get();
      if (fallbackDoc.exists && fallbackDoc.data() != null) {
        return fallbackDoc.data();
      }
    } catch (e) {
      debugPrint('Note: Firebase Gemini config fetch: $e');
    }
    return null;
  }

  /// Sets or updates the central Gemini AI configuration in Firebase (Admin/Teacher tool).
  static Future<void> setFirebaseGeminiConfig({
    required String apiKey,
    String model = 'gemini-1.5-flash',
    bool isEnabled = true,
  }) async {
    final db = _db;
    if (db == null) return;

    try {
      await db.collection('config').doc('gemini').set({
        'apiKey': apiKey.trim(),
        'model': model,
        'isEnabled': isEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving Firebase Gemini config: $e');
    }
  }

  /// Syncs an AI chat message to Firebase Firestore so chat history is preserved across devices.
  static Future<void> saveChatMessage({
    required String userId,
    required String messageId,
    required String text,
    required bool isUser,
    required DateTime timestamp,
  }) async {
    final db = _db;
    if (db == null || userId.isEmpty) return;

    try {
      await db
          .collection('users')
          .doc(userId)
          .collection('ai_conversations')
          .doc(messageId)
          .set({
        'id': messageId,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving AI message to Firebase: $e');
    }
  }

  /// Streams real-time AI conversation history for the signed-in user from Firebase.
  static Stream<List<Map<String, dynamic>>> streamChatHistory(String userId) {
    final db = _db;
    if (db == null || userId.isEmpty) return const Stream.empty();

    return db
        .collection('users')
        .doc(userId)
        .collection('ai_conversations')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((d) => d.data()).toList();
    });
  }

  /// Clears user's AI conversation history in Firebase.
  static Future<void> clearFirebaseChatHistory(String userId) async {
    final db = _db;
    if (db == null || userId.isEmpty) return;

    try {
      final snapshot = await db
          .collection('users')
          .doc(userId)
          .collection('ai_conversations')
          .get();

      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing Firebase AI chat history: $e');
    }
  }
}
