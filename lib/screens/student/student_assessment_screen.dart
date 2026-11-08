import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity.dart';
import '../../models/assessment.dart';
import '../../models/assessment_question.dart';
import '../../models/assessment_submission.dart';
import '../../models/submission.dart';
import '../../providers/activity_provider.dart';
import '../../providers/assessment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gemini_assistant_provider.dart';
import '../../services/assessment_grading_service.dart';
import '../../theme/app_theme.dart';

class StudentAssessmentScreen extends StatefulWidget {
  final Activity activity;
  final Assessment assessment;
  final Submission? existingSubmission;

  const StudentAssessmentScreen({
    super.key,
    required this.activity,
    required this.assessment,
    this.existingSubmission,
  });

  @override
  State<StudentAssessmentScreen> createState() =>
      _StudentAssessmentScreenState();
}

class _StudentAssessmentScreenState extends State<StudentAssessmentScreen> {
  final Map<String, dynamic> _answers = {};
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isSubmitting = false;
  AssessmentSubmission? _resultSubmission;

  @override
  void initState() {
    super.initState();
    final a = widget.assessment;

    // Check if student already took it
    final auth = context.read<AuthProvider>();
    final studentId = auth.currentUser?.id ?? '';
    final existing =
        context.read<AssessmentProvider>().getStudentSubmission(a.id, studentId);

    if (existing != null) {
      _resultSubmission = existing;
    } else if (a.timeLimitMinutes != null && a.timeLimitMinutes! > 0) {
      _secondsRemaining = a.timeLimitMinutes! * 60;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondsRemaining <= 1) {
          t.cancel();
          _submitAssessment(autoSubmit: true);
        } else {
          setState(() => _secondsRemaining--);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerFormatted {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmSubmit() async {
    final answeredCount = _answers.keys
        .where((k) =>
            _answers[k] != null && _answers[k].toString().trim().isNotEmpty)
        .length;
    final total = widget.assessment.questions.length;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Submit Assessment?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          'You have answered $answeredCount of $total questions.\n\n'
          'Are you sure you want to finish and submit your work?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Review Answers'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit Now'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      _submitAssessment();
    }
  }

  Future<void> _submitAssessment({bool autoSubmit = false}) async {
    _timer?.cancel();
    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final geminiKey = context.read<GeminiAssistantProvider>().apiKey;
    final activityProv = context.read<ActivityProvider>();
    final assessmentProv = context.read<AssessmentProvider>();
    final student = auth.currentUser;

    final submissionResult = await AssessmentGradingService.gradeSubmission(
      assessment: widget.assessment,
      studentId: student?.id ?? 'student',
      studentName: student?.name ?? 'Student',
      answers: _answers,
      geminiApiKey: geminiKey,
      runAiForSubjective: true,
    );

    // Save in AssessmentProvider
    await assessmentProv.recordSubmission(submissionResult);

    // Update ActivityProvider submission record
    await activityProv.submitActivity(
      activityId: widget.activity.id,
      studentId: student?.id ?? 'student',
      studentName: student?.name ?? 'Student',
      status: submissionResult.isGraded
          ? SubmissionStatus.graded
          : SubmissionStatus.submitted,
      grade: submissionResult.totalScore,
      assessmentSubmissionData: submissionResult.toJson(),
    );

    setState(() {
      _isSubmitting = false;
      _resultSubmission = submissionResult;
    });

    if (autoSubmit && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Time expired! Your assessment has been submitted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resultSubmission != null) {
      return _buildResultsView(_resultSubmission!);
    }

    final a = widget.assessment;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          a.title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain),
        ),
        actions: [
          if (a.timeLimitMinutes != null && a.timeLimitMinutes! > 0)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _secondsRemaining < 120
                    ? AppTheme.statusMissing.withValues(alpha: 0.15)
                    : AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _secondsRemaining < 120
                        ? AppTheme.statusMissing
                        : AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _timerFormatted,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _secondsRemaining < 120
                          ? AppTheme.statusMissing
                          : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderLight)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_answers.length} of ${a.questions.length} Answered',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting ? null : _confirmSubmit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Answers',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Header Instructions Card
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu_book_rounded,
                          size: 16, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${a.subject} • ${a.gradeLevel}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary),
                    ),
                    const Spacer(),
                    Text(
                      '${a.totalPoints} Total Pts',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  a.instructions,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Questions List
          for (var i = 0; i < a.questions.length; i++) ...[
            _buildInteractiveQuestionCard(i, a.questions[i]),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractiveQuestionCard(int index, AssessmentQuestion q) {
    return Container(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Question ${index + 1}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary)),
              ),
              Text('${q.points.toStringAsFixed(0)} pt',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          if (q.caseScenario != null && q.caseScenario!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                q.caseScenario!,
                style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary),
              ),
            ),
          ],
          Text(
            q.question,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain),
          ),
          const SizedBox(height: 14),
          _buildQuestionInput(q),
        ],
      ),
    );
  }

  Widget _buildQuestionInput(AssessmentQuestion q) {
    switch (q.type) {
      case QuestionType.multipleChoice:
        return Column(
          children: q.options.map((opt) {
            final isSelected = _answers[q.id] == opt;
            return InkWell(
              onTap: () => setState(() => _answers[q.id] = opt),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.borderLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textMain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );

      case QuestionType.trueFalse:
        return Row(
          children: ['True', 'False'].map((val) {
            final isSelected = _answers[q.id] == val;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _answers[q.id] = val),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      val,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w700,
                        color:
                            isSelected ? AppTheme.primary : AppTheme.textMain,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );

      case QuestionType.identification:
      case QuestionType.fillInTheBlanks:
        return TextFormField(
          initialValue: _answers[q.id]?.toString() ?? '',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            hintText: 'Type your answer here...',
            fillColor: Color(0xFFF8FAFC),
          ),
          onChanged: (v) => _answers[q.id] = v,
        );

      case QuestionType.shortAnswer:
      case QuestionType.essay:
      case QuestionType.situational:
      case QuestionType.problemSolving:
        return TextFormField(
          initialValue: _answers[q.id]?.toString() ?? '',
          maxLines: 4,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Write your comprehensive answer...',
            fillColor: Color(0xFFF8FAFC),
          ),
          onChanged: (v) => _answers[q.id] = v,
        );

      default:
        return TextFormField(
          initialValue: _answers[q.id]?.toString() ?? '',
          decoration: const InputDecoration(
            hintText: 'Enter answer...',
            fillColor: Color(0xFFF8FAFC),
          ),
          onChanged: (v) => _answers[q.id] = v,
        );
    }
  }

  // --- POST-SUBMISSION RESULTS VIEW ---
  Widget _buildResultsView(AssessmentSubmission sub) {
    final a = widget.assessment;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Assessment Results',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Score Hero Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: sub.isPassed
                  ? AppTheme.primaryGradient
                  : const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFF991B1B)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.heroShadow,
            ),
            child: Column(
              children: [
                Icon(
                  sub.isPassed
                      ? Icons.verified_rounded
                      : Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  sub.isPassed ? 'Assessment Passed!' : 'Needs Improvement',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Score: ${sub.totalScore.toStringAsFixed(1)} / ${sub.maxScore.toStringAsFixed(0)} (${sub.percentage.toStringAsFixed(0)}%)',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Question by question review (if permitted)
          if (a.allowShowAnswersAfterSubmit) ...[
            const Text('Question Review & Feedback',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (var i = 0; i < a.questions.length; i++) ...[
              _buildResultQuestionItem(i, a.questions[i], sub),
              const SizedBox(height: 10),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Detailed answers and answer keys are hidden as per teacher settings.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultQuestionItem(
      int index, AssessmentQuestion q, AssessmentSubmission sub) {
    final awarded = sub.questionScores[q.id] ?? 0.0;
    final isFullScore = awarded >= q.points;
    final studentAns = sub.answers[q.id];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullScore
              ? AppTheme.statusGraded.withValues(alpha: 0.3)
              : AppTheme.statusMissing.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Q${index + 1} (${q.type.label})',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFullScore
                      ? AppTheme.statusGraded.withValues(alpha: 0.12)
                      : AppTheme.statusMissing.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${awarded.toStringAsFixed(1)} / ${q.points.toStringAsFixed(0)} pt',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isFullScore
                        ? AppTheme.statusGraded
                        : AppTheme.statusMissing,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(q.question,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Your Answer: ${studentAns ?? "None"}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isFullScore
                    ? AppTheme.statusGraded
                    : AppTheme.statusMissing,
              )),
          if (!isFullScore) ...[
            const SizedBox(height: 4),
            Text('Correct Answer: ${q.correctAnswer}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary)),
          ],
          if (q.explanation != null && q.explanation!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Explanation: ${q.explanation}',
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
  }
}
