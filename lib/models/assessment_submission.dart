import 'dart:convert';

class AssessmentSubmission {
  final String id;
  final String assessmentId;
  final String studentId;
  final String studentName;
  final DateTime submittedAt;
  Map<String, dynamic> answers; // questionId -> student's answer (String, List<String>, etc.)
  Map<String, double> questionScores; // questionId -> awarded score
  double totalScore;
  double maxScore;
  bool isPassed;
  Map<String, String> feedback; // questionId -> explanation or teacher comment
  Map<String, dynamic> aiGradingSuggestions; // questionId -> {suggestedScore, rationale}
  bool isGraded;

  AssessmentSubmission({
    required this.id,
    required this.assessmentId,
    required this.studentId,
    required this.studentName,
    DateTime? submittedAt,
    Map<String, dynamic>? answers,
    Map<String, double>? questionScores,
    this.totalScore = 0.0,
    this.maxScore = 0.0,
    this.isPassed = false,
    Map<String, String>? feedback,
    Map<String, dynamic>? aiGradingSuggestions,
    this.isGraded = false,
  })  : submittedAt = submittedAt ?? DateTime.now(),
        answers = answers ?? {},
        questionScores = questionScores ?? {},
        feedback = feedback ?? {},
        aiGradingSuggestions = aiGradingSuggestions ?? {};

  double get percentage =>
      maxScore > 0 ? (totalScore / maxScore * 100).clamp(0, 100) : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'assessmentId': assessmentId,
        'studentId': studentId,
        'studentName': studentName,
        'submittedAt': submittedAt.toIso8601String(),
        'answers': answers,
        'questionScores': questionScores,
        'totalScore': totalScore,
        'maxScore': maxScore,
        'isPassed': isPassed,
        'feedback': feedback,
        'aiGradingSuggestions': aiGradingSuggestions,
        'isGraded': isGraded,
      };

  factory AssessmentSubmission.fromMap(Map<String, dynamic> map) {
    return AssessmentSubmission(
      id: map['id']?.toString() ?? '',
      assessmentId: map['assessmentId']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      submittedAt: map['submittedAt'] != null
          ? DateTime.tryParse(map['submittedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      answers: (map['answers'] as Map<String, dynamic>?) ?? {},
      questionScores: (map['questionScores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      totalScore: (map['totalScore'] as num?)?.toDouble() ?? 0.0,
      maxScore: (map['maxScore'] as num?)?.toDouble() ?? 0.0,
      isPassed: map['isPassed'] == true,
      feedback: (map['feedback'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
      aiGradingSuggestions:
          (map['aiGradingSuggestions'] as Map<String, dynamic>?) ?? {},
      isGraded: map['isGraded'] == true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AssessmentSubmission.fromJson(String source) =>
      AssessmentSubmission.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
