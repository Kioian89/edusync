import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_auth_service.dart';

class SupabaseStorageService {
  static const bucketName = 'activity-documents';
  static const _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cpatnmzqhvckskkjqkzd.supabase.co',
  );
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_lMNzd_Goi9WC8HfOVJ5BqA_pTp8oZ63',
  );
  static const _pathPrefix = 'supabase://';
  static bool _initialized = false;
  static String? _initializationError;

  static Future<bool> initializeFromDefines() async {
    if (_url.isEmpty && _publishableKey.isEmpty) return false;
    if (_url.isEmpty || _publishableKey.isEmpty) {
      throw StateError(
        'Set both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to enable file storage.',
      );
    }

    try {
      await Supabase.initialize(
        url: _url,
        publishableKey: _publishableKey,
        accessToken: () async {
          final user = FirebaseAuthService.currentUser;
          if (user == null) return null;
          return user.getIdToken();
        },
      );
      _initialized = true;
    } catch (error) {
      _initializationError = error.toString();
      rethrow;
    }
    return true;
  }

  /// Synchronizes Firebase custom user claims via Supabase Edge Function `sync-user-claims`.
  /// Updates `role: authenticated`, `edusync_role`, and `class_ids` based on Firestore profiles
  /// and class rosters. If the current Firebase user is affected, forces a token refresh.
  static Future<bool> syncUserClaims({
    String? userId,
    List<String>? userIds,
    String? classId,
  }) async {
    if (_initializationError != null || !_initialized) {
      return false;
    }

    try {
      final payload = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) payload['userId'] = userId;
      if (userIds != null && userIds.isNotEmpty) {
        payload['userIds'] = userIds.toSet().toList();
      }
      if (classId != null && classId.isNotEmpty) payload['classId'] = classId;

      final response = await Supabase.instance.client.functions.invoke(
        'sync-user-claims',
        body: payload,
      );

      if (response.status >= 200 && response.status < 300) {
        final currentUser = FirebaseAuthService.currentUser;
        if (currentUser != null) {
          final isCurrentAffected = userId == currentUser.uid ||
              (userIds != null && userIds.contains(currentUser.uid)) ||
              (userId == null && userIds == null);
          if (isCurrentAffected) {
            try {
              await currentUser.getIdTokenResult(true);
            } catch (_) {}
          }
        }
        return true;
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> authorizeClassAccess({
    required String classId,
    required String userId,
    required String role,
  }) async {
    if (_initializationError != null) {
      throw StateError('Supabase could not initialize: $_initializationError');
    }
    if (!_initialized) {
      throw StateError(
        'Supabase Storage is not configured. Set SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY when launching the app.',
      );
    }

    final user = FirebaseAuthService.currentUser;
    if (user == null || user.uid != userId) {
      throw StateError('Sign in with the Firebase account for this user.');
    }

    var token = await user.getIdTokenResult();
    var claims = token.claims ?? const <String, dynamic>{};
    var classIds = claims['class_ids'];
    if (claims['role'] != 'authenticated' ||
        claims['edusync_role'] != role ||
        classIds is! List ||
        !classIds.whereType<String>().contains(classId)) {
      // Attempt on-demand claim sync in case the edge function hasn't run yet
      await syncUserClaims(userId: userId, classId: classId);
      token = await user.getIdTokenResult(true);
      claims = token.claims ?? const <String, dynamic>{};
      classIds = claims['class_ids'];
    }

    if (claims['role'] != 'authenticated' ||
        claims['edusync_role'] != role ||
        classIds is! List ||
        !classIds.whereType<String>().contains(classId)) {
      throw StateError(
        'This Firebase account is missing the required Supabase class access '
        'claims. Refresh the Firebase ID token after an administrator updates '
        'the claims.',
      );
    }
  }

  static Future<String> upload({
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    await Supabase.instance.client.storage
        .from(bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return '$_pathPrefix$path';
  }

  static bool isSupabasePath(String path) => path.startsWith(_pathPrefix);

  static String _storagePath(String path) => path.substring(_pathPrefix.length);

  static Future<Uint8List> download(String path) => Supabase
      .instance
      .client
      .storage
      .from(bucketName)
      .download(_storagePath(path));

  static Future<String> createSignedUrl(
    String path, {
    int expiresInSeconds = 300,
  }) => Supabase.instance.client.storage
      .from(bucketName)
      .createSignedUrl(_storagePath(path), expiresInSeconds);

  static Future<void> delete(String path) async {
    await Supabase.instance.client.storage.from(bucketName).remove([
      _storagePath(path),
    ]);
  }
}
