import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdUpdateService {
  static final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Check whether the current app build is managed by Shorebird
  static bool get isShorebirdAvailable => _updater.isAvailable;

  /// Check for any pending over-the-air code push updates
  static Future<bool> isUpdateAvailable() async {
    if (!isShorebirdAvailable) return false;
    try {
      final status = await _updater.checkForUpdate();
      return status == UpdateStatus.outdated;
    } catch (e) {
      debugPrint('Shorebird check error: $e');
      return false;
    }
  }

  /// Download the latest patch in background and apply it for next restart
  static Future<void> downloadUpdateIfAvailable() async {
    if (!isShorebirdAvailable) return;
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        debugPrint('Shorebird: New patch available. Downloading...');
        await _updater.update();
        debugPrint('Shorebird: Patch downloaded successfully. Will activate on next restart.');
      }
    } catch (e) {
      debugPrint('Shorebird download error: $e');
    }
  }

  /// Read current patch number if installed
  static Future<int?> getCurrentPatchNumber() async {
    if (!isShorebirdAvailable) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }
}
