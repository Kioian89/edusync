import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'supabase_storage_service.dart';

class ActivityAttachmentService {
  static const _uuid = Uuid();

  static Future<List<String>> uploadFiles({
    required String activityId,
    required String classId,
    required String teacherId,
    required List<PlatformFile> files,
  }) => _uploadSupabaseFiles(
    classId: classId,
    userId: teacherId,
    role: 'teacher',
    storagePath: 'activity_attachments/$classId/$teacherId/$activityId',
    files: files,
  );

  static Future<List<String>> uploadSubmissionFiles({
    required String activityId,
    required String classId,
    required String studentId,
    required List<PlatformFile> files,
  }) => _uploadSupabaseFiles(
    classId: classId,
    userId: studentId,
    role: 'student',
    storagePath: 'activity_submissions/$classId/$activityId/$studentId',
    files: files,
  );

  static Future<void> deleteStorageFiles(List<String> storagePaths) async {
    for (final storagePath in storagePaths) {
      try {
        if (SupabaseStorageService.isSupabasePath(storagePath)) {
          await SupabaseStorageService.delete(storagePath);
        } else {
          await FirebaseStorage.instance.ref(storagePath).delete();
        }
      } catch (error) {
        debugPrint('Failed to clean up activity attachment: $error');
      }
    }
  }

  static Future<List<String>> _uploadSupabaseFiles({
    required String classId,
    required String userId,
    required String role,
    required String storagePath,
    required List<PlatformFile> files,
  }) async {
    if (files.isEmpty) return const [];
    await SupabaseStorageService.authorizeClassAccess(
      classId: classId,
      userId: userId,
      role: role,
    );

    final storagePaths = <String>[];
    try {
      for (final file in files) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw StateError('Could not read the selected file "${file.name}".');
        }

        final extension = file.extension?.toLowerCase();
        final suffix = extension == null || extension.isEmpty
            ? ''
            : '.$extension';
        storagePaths.add(
          await SupabaseStorageService.upload(
            path: '$storagePath/${_uuid.v4()}$suffix',
            bytes: bytes,
            contentType: _contentType(extension),
          ),
        );
      }
      return storagePaths;
    } catch (_) {
      await deleteStorageFiles(storagePaths);
      rethrow;
    }
  }

  static Future<String?> downloadUrl({
    String? storagePath,
    String? legacyUrl,
  }) async {
    if (storagePath != null && storagePath.isNotEmpty) {
      if (SupabaseStorageService.isSupabasePath(storagePath)) {
        return SupabaseStorageService.createSignedUrl(storagePath);
      }
      return FirebaseStorage.instance.ref(storagePath).getDownloadURL();
    }
    return legacyUrl;
  }

  static Future<bool> openDownloadUrl(String url) async {
    final parsed = Uri.tryParse(url);
    if (parsed != null && parsed.scheme == 'supabase') {
      final signedUrl = await SupabaseStorageService.createSignedUrl(url);
      return launchUrl(
        Uri.parse(signedUrl),
        mode: LaunchMode.externalApplication,
      );
    }
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static Future<Uint8List> getAttachmentBytes({
    String? storagePath,
    String? legacyUrl,
  }) async {
    if (storagePath != null &&
        SupabaseStorageService.isSupabasePath(storagePath)) {
      return SupabaseStorageService.download(storagePath);
    }
    final reference = storagePath != null && storagePath.isNotEmpty
        ? FirebaseStorage.instance.ref(storagePath)
        : legacyUrl != null && legacyUrl.isNotEmpty
        ? FirebaseStorage.instance.refFromURL(legacyUrl)
        : null;
    if (reference == null) {
      throw StateError('This attachment is not available in secure storage.');
    }
    final bytes = await reference.getData(50 * 1024 * 1024);
    if (bytes == null) {
      throw StateError('The attachment could not be downloaded.');
    }
    return bytes;
  }

  static String? _contentType(String? extension) {
    return switch (extension) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'txt' => 'text/plain',
      _ => null,
    };
  }
}
