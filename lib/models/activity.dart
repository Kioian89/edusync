import 'package:flutter/material.dart';

enum ActivityType { module, assignment, quiz, project, exam, seatwork }

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
    String? attachmentName,
    this.answerSheetTemplate,
    this.teacherAnswerKey,
    this.assessmentData,
  }) : attachments =
           attachments ?? (attachmentName != null ? [attachmentName] : []),
       attachmentUrls = attachmentUrls ?? [];

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
    'attachmentName': attachmentName,
    'answerSheetTemplate': answerSheetTemplate,
    'teacherAnswerKey': teacherAnswerKey,
    'assessmentData': assessmentData,
  };

  factory Activity.fromMap(Map<String, dynamic> map) {
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
      attachmentName: map['attachmentName'],
      answerSheetTemplate: map['answerSheetTemplate'],
      teacherAnswerKey: map['teacherAnswerKey'],
      assessmentData: map['assessmentData'],
    );
  }
}
