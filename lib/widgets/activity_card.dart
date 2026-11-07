import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../models/submission.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final Submission? submission;
  final VoidCallback? onTap;
  final int? submittedCount;
  final int? totalStudents;

  const ActivityCard({
    super.key,
    required this.activity,
    this.submission,
    this.onTap,
    this.submittedCount,
    this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isPast = activity.isPastDeadline;
    final now = DateTime.now();
    final isDueSoon = !isPast && activity.deadline.difference(now).inHours <= 24;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: isDueSoon
              ? AppTheme.accentOrbit.withValues(alpha: 0.35)
              : AppTheme.borderLight,
          width: isDueSoon ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Modern Type Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: activity.typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getTypeIcon(activity.type), size: 13, color: activity.typeColor),
                          const SizedBox(width: 5),
                          Text(
                            activity.typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: activity.typeColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (submission != null)
                      StatusBadge(status: submission!.status)
                    else if (submittedCount != null && totalStudents != null)
                      _teacherProgress(context),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activity.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    activity.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                // Bottom Info Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: isPast
                            ? AppTheme.statusMissing
                            : (isDueSoon ? AppTheme.accentOrbit : AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isDueSoon
                              ? 'Due Today • ${DateFormat('h:mm a').format(activity.deadline)}'
                              : 'Due ${dateFormat.format(activity.deadline)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isPast
                                ? AppTheme.statusMissing
                                : (isDueSoon ? AppTheme.accentOrbit : AppTheme.textSecondary),
                            fontWeight: isPast || isDueSoon ? FontWeight.w800 : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${activity.totalPoints.toInt()} pts',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (activity.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity.attachments.length == 1
                              ? activity.attachments.first
                              : '${activity.attachments.length} attached files',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teacherProgress(BuildContext context) {
    final pct = totalStudents! > 0 ? submittedCount! / totalStudents! : 0.0;
    final isComplete = pct == 1.0;
    final color = isComplete ? AppTheme.statusGraded : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_circle_rounded : Icons.people_alt_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            '$submittedCount/$totalStudents Turn-ins',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(ActivityType type) {
    switch (type) {
      case ActivityType.module:
        return Icons.menu_book_rounded;
      case ActivityType.assignment:
        return Icons.assignment_rounded;
      case ActivityType.quiz:
        return Icons.help_outline_rounded;
      case ActivityType.project:
        return Icons.science_rounded;
      case ActivityType.exam:
        return Icons.description_rounded;
      case ActivityType.seatwork:
        return Icons.task_alt_rounded;
    }
  }
}
