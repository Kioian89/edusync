import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized service handling Firebase Authentication and user profile synchronization.
class FirebaseAuthService {
  /// Check if Firebase has been initialized in the app.
  static bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Safe accessor for FirebaseAuth instance.
  static fb.FirebaseAuth? get auth {
    if (!isFirebaseAvailable) return null;
    try {
      return fb.FirebaseAuth.instance;
    } catch (e) {
      debugPrint('FirebaseAuth instance unavailable: $e');
      return null;
    }
  }

  /// Safe accessor for Cloud Firestore instance.
  static FirebaseFirestore? get firestore {
    if (!isFirebaseAvailable) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('FirebaseFirestore instance unavailable: $e');
      return null;
    }
  }

  /// Get currently signed-in Firebase user, if any.
  static fb.User? get currentUser => auth?.currentUser;

  /// Stream of authentication state changes.
  static Stream<fb.User?> get authStateChanges =>
      auth?.authStateChanges() ?? const Stream.empty();

  /// Sign up a new user with Email and Password in Firebase Auth.
  static Future<fb.UserCredential?> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = auth;
    if (client == null) return null;

    final cred = await client.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (cred.user != null && displayName.isNotEmpty) {
      await cred.user!.updateDisplayName(displayName.trim());
    }

    return cred;
  }

  /// Sign in an existing user with Email and Password in Firebase Auth.
  static Future<fb.UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = auth;
    if (client == null) return null;

    return await client.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign out current user from Firebase Auth.
  static Future<void> signOut() async {
    final client = auth;
    if (client != null) {
      await client.signOut();
    }
  }

  /// Send password reset link to user's email address.
  static Future<void> sendPasswordReset(String email) async {
    final client = auth;
    if (client == null) {
      throw Exception('Firebase Authentication is not available.');
    }
    await client.sendPasswordResetEmail(email: email.trim());
  }

  /// Save or update user profile document in Firestore collection 'users'.
  static Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String email,
    required String role,
    String? classId,
  }) async {
    final db = firestore;
    if (db == null) return;

    try {
      await db.collection('users').doc(uid).set({
        'id': uid,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': role,
        'classId': classId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveUserProfile warning: $e');
    }
  }

  /// Fetch user profile from Firestore collection 'users'.
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final db = firestore;
    if (db == null) return null;

    try {
      final doc = await db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
    } catch (e) {
      debugPrint('Firestore getUserProfile error: $e');
    }
    return null;
  }

  /// Human-friendly error translation for FirebaseAuthException error codes.
  static String getFriendlyErrorMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email. Please check your credentials.';
      case 'email-already-in-use':
        return 'An account with this email address already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact administrator.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Console.';
      case 'network-request-failed':
        return 'Network connection error. Check your internet connection.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again after a few minutes.';
      default:
        return e.message ?? 'Authentication error occurred (${e.code}).';
    }
  }
}

