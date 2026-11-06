import 'package:flutter/material.dart';
import '../models/submission.dart';

class StatusBadge extends StatelessWidget {
  final SubmissionStatus status;
  final bool large;

  const StatusBadge({super.key, required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    final submission = _mockSubmission();
    final fontSize = large ? 12.0 : 11.0;
    final padding = large
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: submission.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: submission.statusColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: submission.statusColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            submission.statusLabel,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: submission.statusColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Submission _mockSubmission() => Submission(
        id: '',
        activityId: '',
        studentId: '',
        studentName: '',
        status: status,
      );
}
