import 'dart:convert';

class LearningMaterial {
  final String id;
  final String teacherId;
  String title;
  String subject;
  String gradeLevel;
  String content; // The raw text extracted from file or pasted
  String? fileName;
  String? fileType; // pdf, docx, pptx, txt, pasted
  DateTime createdAt;

  // AI-analyzed metadata
  String? summary;
  List<String> keyConcepts;
  List<String> learningObjectives;
  int recommendedQuestionCount;
  String detectedDifficulty;

  LearningMaterial({
    required this.id,
    required this.teacherId,
    required this.title,
    this.subject = 'General Education',
    this.gradeLevel = 'High School',
    required this.content,
    this.fileName,
    this.fileType = 'pasted',
    DateTime? createdAt,
    this.summary,
    List<String>? keyConcepts,
    List<String>? learningObjectives,
    this.recommendedQuestionCount = 10,
    this.detectedDifficulty = 'Medium',
  })  : createdAt = createdAt ?? DateTime.now(),
        keyConcepts = keyConcepts ?? [],
        learningObjectives = learningObjectives ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherId': teacherId,
        'title': title,
        'subject': subject,
        'gradeLevel': gradeLevel,
        'content': content,
        'fileName': fileName,
        'fileType': fileType,
        'createdAt': createdAt.toIso8601String(),
        'summary': summary,
        'keyConcepts': keyConcepts,
        'learningObjectives': learningObjectives,
        'recommendedQuestionCount': recommendedQuestionCount,
        'detectedDifficulty': detectedDifficulty,
      };

  factory LearningMaterial.fromMap(Map<String, dynamic> map) {
    return LearningMaterial(
      id: map['id']?.toString() ?? '',
      teacherId: map['teacherId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Lesson Material',
      subject: map['subject']?.toString() ?? 'General Education',
      gradeLevel: map['gradeLevel']?.toString() ?? 'High School',
      content: map['content']?.toString() ?? '',
      fileName: map['fileName']?.toString(),
      fileType: map['fileType']?.toString() ?? 'pasted',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      summary: map['summary']?.toString(),
      keyConcepts: (map['keyConcepts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      learningObjectives: (map['learningObjectives'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendedQuestionCount:
          (map['recommendedQuestionCount'] as num?)?.toInt() ?? 10,
      detectedDifficulty: map['detectedDifficulty']?.toString() ?? 'Medium',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory LearningMaterial.fromJson(String source) =>
      LearningMaterial.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
