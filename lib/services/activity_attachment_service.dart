import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'firebase_auth_service.dart';

class ActivityAttachmentService {
  static const _uuid = Uuid();

  static Future<List<String>> uploadFiles({
    required String activityId,
    required List<PlatformFile> files,
  }) => _uploadFiles(
    storagePath: 'activity_attachments/$activityId',
    files: files,
  );

  static Future<List<String>> uploadSubmissionFiles({
    required String activityId,
    required String studentId,
    required List<PlatformFile> files,
  }) => _uploadFiles(
    storagePath: 'activity_submissions/$activityId/$studentId',
    files: files,
  );

  static Future<List<String>> _uploadFiles({
    required String storagePath,
    required List<PlatformFile> files,
  }) async {
    if (files.isEmpty) return const [];
    if (!FirebaseAuthService.isFirebaseAvailable) {
      throw StateError(
        'Connect to Firebase before attaching files to an activity.',
      );
    }

    final uploadedReferences = <Reference>[];
    final downloadUrls = <String>[];
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
        final reference = FirebaseStorage.instance.ref(
          '$storagePath/${_uuid.v4()}$suffix',
        );
        uploadedReferences.add(reference);
        final task = await reference.putData(
          bytes,
          SettableMetadata(
            contentType: _contentType(extension),
            customMetadata: {'fileName': file.name},
          ),
        );
        downloadUrls.add(await task.ref.getDownloadURL());
      }
      return downloadUrls;
    } catch (error) {
      for (final reference in uploadedReferences) {
        try {
          await reference.delete();
        } catch (cleanupError) {
          debugPrint(
            'Failed to clean up uploaded activity attachment: $cleanupError',
          );
        }
      }
      rethrow;
    }
  }

  static Future<bool> openDownloadUrl(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

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
