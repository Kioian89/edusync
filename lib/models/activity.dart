import 'package:flutter/material.dart';

enum ActivityType { module, assignment, quiz, project, exam, seatwork }
enum ActivityAttachmentAccess { download, viewOnly }

class Activity {
  final String id;
  final String title;
  final String description;
  final String classId;
  final String teacherId;
  final ActivityType type;
  final DateTime deadline;
  final double totalPoints;
  final DateTime createdAt;
  final List<String> attachments;
  final List<String?> attachmentUrls;
  final List<String?> attachmentStoragePaths;
  final ActivityAttachmentAccess attachmentAccess;
  final int? timeLimitMinutes;
  final bool monitorFocusLoss;
  final String? answerSheetTemplate; // In-app answer sheet format/template
  final String? teacherAnswerKey; // Teacher's answer key for grading
  final String? assessmentData; // AI Assessment JSON configuration

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.classId,
    required this.teacherId,
    required this.type,
    required this.deadline,
    required this.totalPoints,
    required this.createdAt,
    List<String>? attachments,
    List<String?>? attachmentUrls,
    List<String?>? attachmentStoragePaths,
    String? attachmentName,
    this.attachmentAccess = ActivityAttachmentAccess.download,
    this.timeLimitMinutes,
    this.monitorFocusLoss = false,
    this.answerSheetTemplate,
    this.teacherAnswerKey,
    this.assessmentData,
  }) : attachments =
           attachments ??            (attachmentName != null ? [attachmentName] : []),
       attachmentUrls = attachmentUrls ?? [],
       attachmentStoragePaths = attachmentStoragePaths ?? [];

  bool get hasAnswerSheetTemplate =>
      answerSheetTemplate != null && answerSheetTemplate!.isNotEmpty;
  bool get isAiAssessment =>
      assessmentData != null && assessmentData!.isNotEmpty;

  String? get attachmentName =>
      attachments.isNotEmpty ? attachments.first : null;

  String? attachmentUrlAt(int index) {
    final storedUrl = index < attachmentUrls.length
        ? attachmentUrls[index]
        : null;
    if (storedUrl != null && storedUrl.isNotEmpty) return storedUrl;
    if (index >= attachments.length) return null;

    final legacyUrl = Uri.tryParse(attachments[index]);
    return legacyUrl != null &&
            (legacyUrl.scheme == 'https' || legacyUrl.scheme == 'http')
        ? attachments[index]
        : null;
  }

  String? attachmentStoragePathAt(int index) =>
      index < attachmentStoragePaths.length
          ? attachmentStoragePaths[index]
          : null;

  bool get requiresProtectedAttempt =>
      attachmentAccess == ActivityAttachmentAccess.viewOnly ||
      timeLimitMinutes != null ||
      monitorFocusLoss;

  bool get isPastDeadline => DateTime.now().isAfter(deadline);

  Color get typeColor {
    switch (type) {
      case ActivityType.module:
        return Colors.teal;
      case ActivityType.assignment:
        return Colors.blue;
      case ActivityType.quiz:
        return Colors.orange;
      case ActivityType.project:
        return Colors.purple;
      case ActivityType.exam:
        return Colors.red;
      case ActivityType.seatwork:
        return Colors.green;
    }
  }

  String get typeLabel {
    switch (type) {
      case ActivityType.module:
        return 'Lesson Module';
      case ActivityType.assignment:
        return 'Assignment';
      case ActivityType.quiz:
        return 'Quiz';
      case ActivityType.project:
        return 'Project';
      case ActivityType.exam:
        return 'Exam';
      case ActivityType.seatwork:
        return 'Seatwork';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'classId': classId,
    'teacherId': teacherId,
    'type': type.name,
    'deadline': deadline.toIso8601String(),
    'totalPoints': totalPoints,
    'createdAt': createdAt.toIso8601String(),
    'attachments': attachments,
    'attachmentUrls': attachmentUrls,
    'attachmentStoragePaths': attachmentStoragePaths,
    'attachmentAccess': attachmentAccess.name,
    'timeLimitMinutes': timeLimitMinutes,
    'monitorFocusLoss': monitorFocusLoss,
    'attachmentName': attachmentName,
    'answerSheetTemplate': answerSheetTemplate,
    'assessmentData': assessmentData,
  };

  factory Activity.fromMap(
    Map<String, dynamic> map, {
    bool includeTeacherAnswerKey = false,
  }) {
    List<String> parsedAttachments = [];
    if (map['attachments'] != null) {
      parsedAttachments = List<String>.from(map['attachments']);
    } else if (map['attachmentName'] != null) {
      parsedAttachments = [map['attachmentName'].toString()];
    }
    final parsedAttachmentUrls = map['attachmentUrls'] == null
        ? <String?>[]
        : List<String?>.from(
            (map['attachmentUrls'] as List).map((url) => url?.toString()),
          );
    final parsedAttachmentPaths = map['attachmentStoragePaths'] == null
        ? <String?>[]
        : List<String?>.from(
            (map['attachmentStoragePaths'] as List).map(
              (path) => path?.toString(),
            ),
          );
    final attachmentAccess = ActivityAttachmentAccess.values.firstWhere(
      (access) => access.name == map['attachmentAccess'],
      orElse: () => ActivityAttachmentAccess.download,
    );

    return Activity(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      classId: map['classId'],
      teacherId: map['teacherId'],
      type: ActivityType.values.firstWhere((t) => t.name == map['type']),
      deadline: DateTime.parse(map['deadline']),
      totalPoints: (map['totalPoints'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt']),
      attachments: parsedAttachments,
      attachmentUrls: parsedAttachmentUrls,
      attachmentStoragePaths: parsedAttachmentPaths,
      attachmentName: map['attachmentName'],
      attachmentAccess: attachmentAccess,
      timeLimitMinutes: (map['timeLimitMinutes'] as num?)?.toInt(),
      monitorFocusLoss: map['monitorFocusLoss'] == true,
      answerSheetTemplate: map['answerSheetTemplate'],
      teacherAnswerKey: includeTeacherAnswerKey
          ? map['teacherAnswerKey']?.toString()
          : null,
      assessmentData: map['assessmentData'],
    );
  }

  Activity copyWith({
    String? teacherAnswerKey,
    List<String?>? attachmentStoragePaths,
  }) => Activity(
    id: id,
    title: title,
    description: description,
    classId: classId,
    teacherId: teacherId,
    type: type,
    deadline: deadline,
    totalPoints: totalPoints,
    createdAt: createdAt,
    attachments: attachments,
    attachmentUrls: attachmentUrls,
    attachmentStoragePaths:
        attachmentStoragePaths ?? this.attachmentStoragePaths,
    attachmentAccess: attachmentAccess,
    timeLimitMinutes: timeLimitMinutes,
    monitorFocusLoss: monitorFocusLoss,
    answerSheetTemplate: answerSheetTemplate,
    teacherAnswerKey: teacherAnswerKey ?? this.teacherAnswerKey,
    assessmentData: assessmentData,
  );
}
