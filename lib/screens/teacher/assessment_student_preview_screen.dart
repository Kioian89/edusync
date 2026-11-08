import 'package:flutter/material.dart';
import '../../models/assessment.dart';
import '../../models/assessment_question.dart';
import '../../theme/app_theme.dart';

class AssessmentStudentPreviewScreen extends StatefulWidget {
  final Assessment assessment;

  const AssessmentStudentPreviewScreen({super.key, required this.assessment});

  @override
  State<AssessmentStudentPreviewScreen> createState() =>
      _AssessmentStudentPreviewScreenState();
}

class _AssessmentStudentPreviewScreenState
    extends State<AssessmentStudentPreviewScreen> {
  final Map<String, dynamic> _answers = {};

  @override
  Widget build(BuildContext context) {
    final a = widget.assessment;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Student Preview Mode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Container(
            color: AppTheme.accentAmber.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 4),
            width: double.infinity,
            child: const Center(
              child: Text(
                '👀 PREVIEW ONLY — Answers submitted here will not be recorded.',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentAmber),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
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
                  a.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textMain),
                ),
                if (a.instructions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    a.instructions,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _chip(Icons.menu_book_rounded, a.subject),
                    const SizedBox(width: 8),
                    _chip(Icons.format_list_numbered_rounded,
                        '${a.questions.length} Questions'),
                    const SizedBox(width: 8),
                    _chip(Icons.star_rounded, '${a.totalPoints} pts'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Questions
          for (var i = 0; i < a.questions.length; i++) ...[
            _buildQuestionCard(i, a.questions[i]),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, AssessmentQuestion q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${index + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary)),
              Text('${q.points} pt${q.points > 1 ? "s" : ""}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 12),
          _buildInputForPreview(q),
        ],
      ),
    );
  }

  Widget _buildInputForPreview(AssessmentQuestion q) {
    switch (q.type) {
      case QuestionType.multipleChoice:
        return Column(
          children: q.options.map((opt) {
            final isSelected = _answers[q.id] == opt;
            return InkWell(
              onTap: () => setState(() => _answers[q.id] = opt),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.borderLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
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
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.borderLight,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      val,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
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
        return TextField(
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
        return TextField(
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Type your comprehensive response...',
            fillColor: Color(0xFFF8FAFC),
          ),
          onChanged: (v) => _answers[q.id] = v,
        );

      default:
        return TextField(
          decoration: const InputDecoration(
            hintText: 'Enter answer...',
            fillColor: Color(0xFFF8FAFC),
          ),
          onChanged: (v) => _answers[q.id] = v,
        );
    }
  }
}
