import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/assessment.dart';
import '../../models/assessment_submission.dart';
import '../../providers/assessment_provider.dart';
import '../../theme/app_theme.dart';

class AssessmentAnalyticsScreen extends StatelessWidget {
  final Assessment assessment;
  final String activityId;

  const AssessmentAnalyticsScreen({
    super.key,
    required this.assessment,
    required this.activityId,
  });

  @override
  Widget build(BuildContext context) {
    final assessmentProv = context.watch<AssessmentProvider>();
    final submissions = assessmentProv.getSubmissionsForAssessment(assessment.id);

    final totalCompleted = submissions.length;
    final totalPoints = assessment.totalPoints;

    double avgScore = 0.0;
    double highestScore = 0.0;
    double lowestScore = totalPoints;
    int passCount = 0;

    if (totalCompleted > 0) {
      double sum = 0.0;
      for (final s in submissions) {
        sum += s.totalScore;
        if (s.totalScore > highestScore) highestScore = s.totalScore;
        if (s.totalScore < lowestScore) lowestScore = s.totalScore;
        if (s.isPassed) passCount++;
      }
      avgScore = sum / totalCompleted;
    } else {
      lowestScore = 0.0;
    }

    final passRate = totalCompleted > 0 ? (passCount / totalCompleted * 100) : 0.0;

    // Item Analysis: track missed count per question
    final missedCounts = <String, int>{};
    for (final q in assessment.questions) {
      missedCounts[q.id] = 0;
    }
    for (final s in submissions) {
      s.questionScores.forEach((qId, score) {
        final q = assessment.questions.firstWhere(
          (item) => item.id == qId,
          orElse: () => assessment.questions.first,
        );
        if (score < q.points) {
          missedCounts[qId] = (missedCounts[qId] ?? 0) + 1;
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Assessment Analytics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.primary),
            tooltip: 'Export Summary',
            onPressed: () {
              final summaryText = '''
Assessment Performance Report: ${assessment.title}
Subject: ${assessment.subject} • Grade: ${assessment.gradeLevel}
Total Submissions: $totalCompleted
Class Average: ${avgScore.toStringAsFixed(1)} / $totalPoints (${(avgScore / (totalPoints > 0 ? totalPoints : 1) * 100).toStringAsFixed(1)}%)
Highest Score: ${highestScore.toStringAsFixed(1)} / $totalPoints
Lowest Score: ${lowestScore.toStringAsFixed(1)} / $totalPoints
Passing Rate: ${passRate.toStringAsFixed(1)}% ($passCount passed, ${totalCompleted - passCount} failed)
''';
              Clipboard.setData(ClipboardData(text: summaryText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Performance report copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textMain),
                ),
                const SizedBox(height: 4),
                Text(
                  '${assessment.subject} • ${assessment.gradeLevel} • ${assessment.questions.length} Items • ${assessment.totalPoints} Total Points',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Overview KPI Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Submissions',
                  '$totalCompleted',
                  Icons.people_outline_rounded,
                  AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Average Score',
                  '${avgScore.toStringAsFixed(1)} pt',
                  Icons.assessment_outlined,
                  AppTheme.accentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Passing Rate',
                  '${passRate.toStringAsFixed(0)}%',
                  Icons.verified_outlined,
                  AppTheme.statusGraded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Score Range',
                  '${lowestScore.toStringAsFixed(0)} - ${highestScore.toStringAsFixed(0)}',
                  Icons.show_chart_rounded,
                  AppTheme.accentOrbit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Item Analysis (Questions Missed)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.troubleshoot_rounded,
                        color: AppTheme.statusPending, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Item Analysis (Error Rate)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMain),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Questions students missed most often, indicating concepts that may need review.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                if (totalCompleted == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('No submissions recorded yet.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ),
                  )
                else
                  for (var i = 0; i < assessment.questions.length; i++) ...[
                    _buildItemAnalysisRow(
                      i + 1,
                      assessment.questions[i],
                      missedCounts[assessment.questions[i].id] ?? 0,
                      totalCompleted,
                    ),
                    if (i < assessment.questions.length - 1)
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Student Submissions Table
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Student Results',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMain),
                    ),
                    Text(
                      '$totalCompleted Completed',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (submissions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('Waiting for students to submit answers.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ),
                  )
                else
                  for (final sub in submissions) ...[
                    _buildStudentResultRow(sub, totalPoints),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemAnalysisRow(
      int index, dynamic q, int missedCount, int total) {
    final missedPct = total > 0 ? (missedCount / total * 100) : 0.0;
    final isHighError = missedPct >= 50.0;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isHighError
                ? AppTheme.statusMissing.withValues(alpha: 0.1)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('Q$index',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isHighError
                        ? AppTheme.statusMissing
                        : AppTheme.textMain)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.question,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                'Type: ${q.type.label} • Correct: ${q.correctAnswer}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${missedPct.toStringAsFixed(0)}% Missed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isHighError
                    ? AppTheme.statusMissing
                    : AppTheme.statusGraded,
              ),
            ),
            Text('$missedCount / $total',
                style:
                    const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentResultRow(
      AssessmentSubmission sub, double maxPoints) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(
              sub.studentName.isNotEmpty
                  ? sub.studentName[0].toUpperCase()
                  : 'S',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.studentName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain)),
                Text(
                  '${sub.submittedAt.month}/${sub.submittedAt.day} ${sub.submittedAt.hour}:${sub.submittedAt.minute.toString().padLeft(2, '0')}',
                  style:
                      const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: sub.isPassed
                  ? AppTheme.statusGraded.withValues(alpha: 0.12)
                  : AppTheme.statusMissing.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${sub.totalScore.toStringAsFixed(1)} / ${maxPoints.toStringAsFixed(0)} (${sub.percentage.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: sub.isPassed
                    ? AppTheme.statusGraded
                    : AppTheme.statusMissing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
