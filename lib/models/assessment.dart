import 'dart:convert';
import 'assessment_question.dart';

class Assessment {
  final String id;
  String title;
  String instructions;
  String classId;
  String teacherId;
  String subject;
  String gradeLevel;
  String topic;
  String difficulty; // Easy, Medium, Hard, Mixed
  int? timeLimitMinutes; // 0 or null = no time limit
  double passingScore;
  double totalPoints;
  bool isPublished;
  bool allowShowAnswersAfterSubmit;
  List<AssessmentQuestion> questions;
  String? lessonMaterial; // Source text/summary used by AI
  DateTime createdAt;
  DateTime? deadline;

  Assessment({
    required this.id,
    required this.title,
    this.instructions = 'Read each question carefully and select or write the best answer.',
    required this.classId,
    required this.teacherId,
    this.subject = 'General Education',
    this.gradeLevel = 'High School',
    this.topic = '',
    this.difficulty = 'Medium',
    this.timeLimitMinutes,
    this.passingScore = 75.0, // percent or point threshold
    this.totalPoints = 0.0,
    this.isPublished = false,
    this.allowShowAnswersAfterSubmit = true,
    List<AssessmentQuestion>? questions,
    this.lessonMaterial,
    DateTime? createdAt,
    this.deadline,
  })  : questions = questions ?? [],
        createdAt = createdAt ?? DateTime.now() {
    recalculateTotalPoints();
  }

  void recalculateTotalPoints() {
    if (questions.isEmpty) return;
    totalPoints = questions.fold<double>(0.0, (sum, q) => sum + q.points);
  }

  int get questionCount => questions.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'instructions': instructions,
        'classId': classId,
        'teacherId': teacherId,
        'subject': subject,
        'gradeLevel': gradeLevel,
        'topic': topic,
        'difficulty': difficulty,
        'timeLimitMinutes': timeLimitMinutes,
        'passingScore': passingScore,
        'totalPoints': totalPoints,
        'isPublished': isPublished,
        'allowShowAnswersAfterSubmit': allowShowAnswersAfterSubmit,
        'questions': questions.map((q) => q.toMap()).toList(),
        'lessonMaterial': lessonMaterial,
        'createdAt': createdAt.toIso8601String(),
        'deadline': deadline?.toIso8601String(),
      };

  factory Assessment.fromMap(Map<String, dynamic> map) {
    final rawQuestions = (map['questions'] as List<dynamic>?) ?? [];
    final questionsList = rawQuestions
        .map((q) => AssessmentQuestion.fromMap(q as Map<String, dynamic>))
        .toList();

    return Assessment(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Assessment',
      instructions: map['instructions']?.toString() ??
          'Read each question carefully and select or write the best answer.',
      classId: map['classId']?.toString() ?? '',
      teacherId: map['teacherId']?.toString() ?? '',
      subject: map['subject']?.toString() ?? 'General Education',
      gradeLevel: map['gradeLevel']?.toString() ?? 'High School',
      topic: map['topic']?.toString() ?? '',
      difficulty: map['difficulty']?.toString() ?? 'Medium',
      timeLimitMinutes: map['timeLimitMinutes'] as int?,
      passingScore: (map['passingScore'] as num?)?.toDouble() ?? 75.0,
      totalPoints: (map['totalPoints'] as num?)?.toDouble() ?? 0.0,
      isPublished: map['isPublished'] == true,
      allowShowAnswersAfterSubmit: map['allowShowAnswersAfterSubmit'] != false,
      questions: questionsList,
      lessonMaterial: map['lessonMaterial']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'].toString())
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Assessment.fromJson(String source) =>
      Assessment.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
