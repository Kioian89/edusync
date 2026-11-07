import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/activity_provider.dart';
import '../services/firestore_sync_service.dart';
import '../theme/app_theme.dart';

/// A modern pill badge that shows live cloud synchronization status.
class SyncBadge extends StatelessWidget {
  final bool compact;

  const SyncBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.watch<ActivityProvider>().isSyncing;
    final isCloud = FirestoreSyncService.isAvailable;

    final Color statusColor = isSyncing
        ? AppTheme.accentOrbit
        : (isCloud ? AppTheme.accentEmerald : const Color(0xFF64748B));

    final String label = isSyncing
        ? 'Syncing'
        : (isCloud ? 'Live' : 'Local');

    if (compact) {
      return Tooltip(
        message: isSyncing
            ? 'Syncing to cloud…'
            : (isCloud ? 'Cloud Sync Active' : 'Offline / Local Mode'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
