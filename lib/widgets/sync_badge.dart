import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/activity_provider.dart';

/// A small animated dot that shows green (synced) or orange (saving).
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.watch<ActivityProvider>().isSyncing;
    return Tooltip(
      message: isSyncing ? 'Saving…' : 'All saved',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSyncing ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
          boxShadow: [
            BoxShadow(
              color: (isSyncing
                      ? const Color(0xFFFF9800)
                      : const Color(0xFF4CAF50))
                  .withValues(alpha: 0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

