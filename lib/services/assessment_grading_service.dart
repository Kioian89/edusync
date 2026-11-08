import 'package:uuid/uuid.dart';
import '../models/assessment.dart';
import '../models/assessment_question.dart';
import '../models/assessment_submission.dart';
import 'assessment_ai_service.dart';

class AssessmentGradingService {
  static const _uuid = Uuid();

  /// Automatically grades an assessment submission.
  /// Subjective questions (essay, situational) can optionally receive AI scoring suggestions.
  static Future<AssessmentSubmission> gradeSubmission({
    required Assessment assessment,
    required String studentId,
    required String studentName,
    required Map<String, dynamic> answers,
    String? geminiApiKey,
    bool runAiForSubjective = true,
  }) async {
    final questionScores = <String, double>{};
    final feedback = <String, String>{};
    final aiGradingSuggestions = <String, dynamic>{};

    var totalScore = 0.0;
    var maxScore = 0.0;
    var hasSubjectivePending = false;

    for (final q in assessment.questions) {
      final qPoints = q.points;
      maxScore += qPoints;
      final studentAns = answers[q.id];

      switch (q.type) {
        case QuestionType.multipleChoice:
        case QuestionType.trueFalse:
          final expected = q.correctAnswer.toString().trim().toLowerCase();
          final given = studentAns?.toString().trim().toLowerCase() ?? '';
          if (given.isNotEmpty && given == expected) {
            questionScores[q.id] = qPoints;
            totalScore += qPoints;
            feedback[q.id] = 'Correct! ${q.explanation ?? ''}';
          } else {
            questionScores[q.id] = 0.0;
            feedback[q.id] = 'Incorrect. Correct answer: ${q.correctAnswer}. ${q.explanation ?? ''}';
          }
          break;

        case QuestionType.identification:
        case QuestionType.fillInTheBlanks:
          final expectedClean = _normalize(q.correctAnswer.toString());
          final givenClean = _normalize(studentAns?.toString() ?? '');
          if (givenClean.isNotEmpty &&
              (givenClean == expectedClean ||
                  expectedClean.contains(givenClean) ||
                  givenClean.contains(expectedClean))) {
            questionScores[q.id] = qPoints;
            totalScore += qPoints;
            feedback[q.id] = 'Correct! ${q.explanation ?? ''}';
          } else {
            questionScores[q.id] = 0.0;
            feedback[q.id] = 'Incorrect. Correct answer: ${q.correctAnswer}. ${q.explanation ?? ''}';
          }
          break;

        case QuestionType.matching:
          // studentAns is expected to be Map<String, String> (premise -> response)
          if (studentAns is Map && q.matchingPairs.isNotEmpty) {
            var correctPairs = 0;
            q.matchingPairs.forEach((premise, target) {
              final studentSelected = studentAns[premise]?.toString().trim().toLowerCase();
              if (studentSelected == target.trim().toLowerCase()) {
                correctPairs++;
              }
            });
            final pairPoints = (correctPairs / q.matchingPairs.length) * qPoints;
            final rounded = double.parse(pairPoints.toStringAsFixed(1));
            questionScores[q.id] = rounded;
            totalScore += rounded;
            feedback[q.id] = 'Matched $correctPairs of ${q.matchingPairs.length} pairs correctly.';
          } else {
            questionScores[q.id] = 0.0;
            feedback[q.id] = 'Matching not answered.';
          }
          break;

        case QuestionType.enumeration:
          // studentAns can be List or newline-separated String
          List<String> studentItems = [];
          if (studentAns is List) {
            studentItems = studentAns.map((e) => _normalize(e.toString())).toList();
          } else if (studentAns is String) {
            studentItems = studentAns
                .split(RegExp(r'[\n,]'))
                .map((e) => _normalize(e))
                .where((e) => e.isNotEmpty)
                .toList();
          }

          List<String> targetItems = [];
          if (q.correctAnswer is List) {
            targetItems = (q.correctAnswer as List).map((e) => _normalize(e.toString())).toList();
          } else if (q.correctAnswer is String) {
            targetItems = q.correctAnswer
                .toString()
                .split(RegExp(r'[\n,]'))
                .map((e) => _normalize(e))
                .where((e) => e.isNotEmpty)
                .toList();
          }

          if (targetItems.isNotEmpty) {
            var matched = 0;
            for (final target in targetItems) {
              if (studentItems.any((si) => si.contains(target) || target.contains(si))) {
                matched++;
              }
            }
            final enumPoints = (matched / targetItems.length).clamp(0.0, 1.0) * qPoints;
            final rounded = double.parse(enumPoints.toStringAsFixed(1));
            questionScores[q.id] = rounded;
            totalScore += rounded;
            feedback[q.id] = 'Identified $matched of ${targetItems.length} required items.';
          } else {
            questionScores[q.id] = 0.0;
          }
          break;

        case QuestionType.shortAnswer:
        case QuestionType.essay:
        case QuestionType.situational:
        case QuestionType.problemSolving:
          hasSubjectivePending = true;
          final answerText = studentAns?.toString().trim() ?? '';

          if (answerText.isEmpty) {
            questionScores[q.id] = 0.0;
            feedback[q.id] = 'No answer submitted.';
          } else if (runAiForSubjective) {
            try {
              final aiResult = await AssessmentAiService.gradeSubjectiveAnswer(
                question: q.question,
                studentAnswer: answerText,
                rubricOrIdealAnswer: q.correctAnswer.toString(),
                maxPoints: qPoints,
                apiKey: geminiApiKey,
              );
              final suggestedScore = (aiResult['suggestedScore'] as num).toDouble();
              questionScores[q.id] = suggestedScore;
              totalScore += suggestedScore;
              aiGradingSuggestions[q.id] = aiResult;
              feedback[q.id] = 'AI Suggested: ${aiResult['feedback']} (Subject to teacher review)';
            } catch (_) {
              questionScores[q.id] = 0.0;
              feedback[q.id] = 'Pending teacher review.';
            }
          } else {
            questionScores[q.id] = 0.0;
            feedback[q.id] = 'Pending teacher review.';
          }
          break;
      }
    }

    final percentage = maxScore > 0 ? (totalScore / maxScore) * 100 : 0.0;
    final isPassed = percentage >= assessment.passingScore;

    return AssessmentSubmission(
      id: _uuid.v4(),
      assessmentId: assessment.id,
      studentId: studentId,
      studentName: studentName,
      submittedAt: DateTime.now(),
      answers: answers,
      questionScores: questionScores,
      totalScore: double.parse(totalScore.toStringAsFixed(1)),
      maxScore: double.parse(maxScore.toStringAsFixed(1)),
      isPassed: isPassed,
      feedback: feedback,
      aiGradingSuggestions: aiGradingSuggestions,
      isGraded: !hasSubjectivePending,
    );
  }

  static String _normalize(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
