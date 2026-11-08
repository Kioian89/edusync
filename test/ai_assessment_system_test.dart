import 'package:flutter_test/flutter_test.dart';
import 'package:edusync/models/assessment.dart';
import 'package:edusync/models/assessment_question.dart';
import 'package:edusync/models/learning_material.dart';
import 'package:edusync/services/assessment_ai_service.dart';
import 'package:edusync/services/assessment_grading_service.dart';

void main() {
  group('AI-Powered Assessment & Quiz Engine Tests', () {
    test('AI Lesson Analyzer extracts key concepts & recommends question count',
        () async {
      const sampleLesson = '''
PHOTOSYNTHESIS AND CELLULAR RESPIRATION
Photosynthesis is the biological process by which green plants convert solar energy into glucose in chloroplasts.
The chemical equation is 6CO2 + 6H2O + light -> C6H12O6 + 6O2.
It has two stages: Light-Dependent Reactions across the thylakoid membrane and Light-Independent Calvin Cycle in the stroma.
Cellular respiration breaks down glucose to produce 36-38 ATP in the mitochondria.
''';

      final analysis = await AssessmentAiService.analyzeLessonMaterial(
        lessonContent: sampleLesson,
        subject: 'Biology',
        gradeLevel: 'Grade 9',
      );

      expect(analysis.keyConcepts.isNotEmpty, isTrue);
      expect(analysis.learningObjectives.isNotEmpty, isTrue);
      expect(analysis.recommendedQuestionCount, greaterThanOrEqualTo(5));
      expect(analysis.recommendedQuestionCount, lessThanOrEqualTo(50));
      expect(analysis.isContentSufficient, isTrue);
    });

    test('Question Generator supports all 10 required question types', () async {
      const sampleLesson =
          'Photosynthesis occurs in chloroplasts. Calvin cycle happens in the stroma.';

      final allTypes = QuestionType.values.toList();
      expect(allTypes.length, equals(10));

      final questions = await AssessmentAiService.generateAssessmentQuestions(
        lessonContent: sampleLesson,
        title: 'Photosynthesis Quiz',
        subject: 'Biology',
        gradeLevel: 'Grade 9',
        questionCount: 10,
        questionTypes: allTypes,
        difficulty: 'Medium',
      );

      expect(questions.length, equals(10));
      for (final q in questions) {
        expect(q.id.isNotEmpty, isTrue);
        expect(q.question.isNotEmpty, isTrue);
        expect(q.points, greaterThan(0));
      }

      // Verify specific question types exist
      expect(questions.any((q) => q.type == QuestionType.multipleChoice), isTrue);
      expect(questions.any((q) => q.type == QuestionType.trueFalse), isTrue);
      expect(questions.any((q) => q.type == QuestionType.identification), isTrue);
      expect(questions.any((q) => q.type == QuestionType.fillInTheBlanks), isTrue);
      expect(questions.any((q) => q.type == QuestionType.matching), isTrue);
      expect(questions.any((q) => q.type == QuestionType.enumeration), isTrue);
    });

    test('Automated Checking Engine checks objective answers accurately', () async {
      final q1 = AssessmentQuestion(
        id: 'q1',
        type: QuestionType.multipleChoice,
        question: 'Where does photosynthesis occur?',
        options: ['Chloroplast', 'Mitochondria', 'Nucleus', 'Ribosome'],
        correctAnswer: 'Chloroplast',
        points: 2.0,
      );

      final q2 = AssessmentQuestion(
        id: 'q2',
        type: QuestionType.trueFalse,
        question: 'True or False: Oxygen is produced during photosynthesis.',
        options: ['True', 'False'],
        correctAnswer: 'True',
        points: 1.0,
      );

      final q3 = AssessmentQuestion(
        id: 'q3',
        type: QuestionType.identification,
        question: 'Name the primary pigment absorbing sunlight in plants.',
        correctAnswer: 'Chlorophyll',
        points: 2.0,
      );

      final assessment = Assessment(
        id: 'assess-1',
        title: 'Biology Test',
        classId: 'class-1',
        teacherId: 'teacher-1',
        questions: [q1, q2, q3],
        passingScore: 75.0,
      );

      // Student answers: Q1 correct, Q2 correct, Q3 slightly trimmed/case variant
      final studentAnswers = {
        'q1': 'Chloroplast',
        'q2': 'True',
        'q3': '  chlorophyll  ',
      };

      final submission = await AssessmentGradingService.gradeSubmission(
        assessment: assessment,
        studentId: 'student-1',
        studentName: 'Alice Santos',
        answers: studentAnswers,
        runAiForSubjective: false,
      );

      expect(submission.totalScore, equals(5.0));
      expect(submission.maxScore, equals(5.0));
      expect(submission.percentage, equals(100.0));
      expect(submission.isPassed, isTrue);
      expect(submission.isGraded, isTrue);
      expect(submission.questionScores['q1'], equals(2.0));
      expect(submission.questionScores['q2'], equals(1.0));
      expect(submission.questionScores['q3'], equals(2.0));
    });

    test('Automated Checking correctly penalizes wrong answers', () async {
      final q1 = AssessmentQuestion(
        id: 'q1',
        type: QuestionType.multipleChoice,
        question: 'What is the powerhouse of the cell?',
        options: ['Chloroplast', 'Mitochondria', 'Golgi', 'Vacuole'],
        correctAnswer: 'Mitochondria',
        points: 10.0,
      );

      final assessment = Assessment(
        id: 'assess-2',
        title: 'Cell Biology',
        classId: 'class-1',
        teacherId: 'teacher-1',
        questions: [q1],
        passingScore: 75.0,
      );

      final wrongAnswers = {'q1': 'Chloroplast'};

      final submission = await AssessmentGradingService.gradeSubmission(
        assessment: assessment,
        studentId: 'student-2',
        studentName: 'Bob Reyes',
        answers: wrongAnswers,
        runAiForSubjective: false,
      );

      expect(submission.totalScore, equals(0.0));
      expect(submission.percentage, equals(0.0));
      expect(submission.isPassed, isFalse);
    });

    test('LearningMaterial model serializes and deserializes properly', () {
      final mat = LearningMaterial(
        id: 'mat-1',
        teacherId: 'teacher-1',
        title: 'Module 1 - Ecosystem Dynamics',
        content: 'Producers, consumers, and decomposers form a food web.',
        subject: 'General Science',
        gradeLevel: 'Grade 7',
        keyConcepts: ['Food Web', 'Trophic Levels'],
        learningObjectives: ['Describe energy flow in an ecosystem'],
        recommendedQuestionCount: 15,
        detectedDifficulty: 'Medium',
      );

      final jsonStr = mat.toJson();
      final revived = LearningMaterial.fromJson(jsonStr);

      expect(revived.id, equals(mat.id));
      expect(revived.title, equals(mat.title));
      expect(revived.keyConcepts.length, equals(2));
      expect(revived.recommendedQuestionCount, equals(15));
    });
  });
}
