import 'package:flutter/material.dart';

enum SubmissionStatus { pending, submitted, graded, missing }

class Submission {
  final String id;
  final String activityId;
  final String studentId;
  final String studentName;
  SubmissionStatus status;
  final DateTime? submittedAt;
  double? grade;
  String? feedback;
  final List<String> fileNames;
  final List<String?> fileUrls;
  final String? studentAnswerSheet; // In-app completed answer sheet content
  final String? assessmentSubmissionData; // Assessment submission JSON

  Submission({
    required this.id,
    required this.activityId,
    required this.studentId,
    required this.studentName,
    required this.status,
    this.submittedAt,
    this.grade,
    this.feedback,
    List<String>? fileNames,
    List<String?>? fileUrls,
    String? fileName,
    this.studentAnswerSheet,
    this.assessmentSubmissionData,
  }) : fileNames = fileNames ?? (fileName != null ? [fileName] : []),
       fileUrls = fileUrls ?? [];

  String? get fileName => fileNames.isNotEmpty ? fileNames.first : null;
  bool get hasAssessmentSubmission =>
      assessmentSubmissionData != null && assessmentSubmissionData!.isNotEmpty;

  Color get statusColor {
    switch (status) {
      case SubmissionStatus.pending:
        return Colors.orange;
      case SubmissionStatus.submitted:
        return Colors.blue;
      case SubmissionStatus.graded:
        return Colors.green;
      case SubmissionStatus.missing:
        return Colors.red;
    }
  }

  String get statusLabel {
    switch (status) {
      case SubmissionStatus.pending:
        return 'Pending';
      case SubmissionStatus.submitted:
        return 'Submitted';
      case SubmissionStatus.graded:
        return 'Graded';
      case SubmissionStatus.missing:
        return 'Missing';
    }
  }

  IconData get statusIcon {
    switch (status) {
      case SubmissionStatus.pending:
        return Icons.hourglass_top_rounded;
      case SubmissionStatus.submitted:
        return Icons.check_circle_rounded;
      case SubmissionStatus.graded:
        return Icons.verified_rounded;
      case SubmissionStatus.missing:
        return Icons.highlight_off_rounded;
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'activityId': activityId,
    'studentId': studentId,
    'studentName': studentName,
    'status': status.name,
    'submittedAt': submittedAt?.toIso8601String(),
    'grade': grade,
    'feedback': feedback,
    'fileNames': fileNames,
    'fileUrls': fileUrls,
    'fileName': fileName,
    'studentAnswerSheet': studentAnswerSheet,
    'assessmentSubmissionData': assessmentSubmissionData,
  };

  factory Submission.fromMap(Map<String, dynamic> map) {
    List<String> parsedFiles = [];
    if (map['fileNames'] != null) {
      parsedFiles = List<String>.from(map['fileNames']);
    } else if (map['fileName'] != null) {
      parsedFiles = [map['fileName'].toString()];
    }
    final parsedFileUrls = map['fileUrls'] == null
        ? <String?>[]
        : List<String?>.from(
            (map['fileUrls'] as List).map((url) => url?.toString()),
          );

    return Submission(
      id: map['id'],
      activityId: map['activityId'],
      studentId: map['studentId'],
      studentName: map['studentName'],
      status: SubmissionStatus.values.firstWhere(
        (s) => s.name == map['status'],
      ),
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'])
          : null,
      grade: map['grade'] != null ? (map['grade'] as num).toDouble() : null,
      feedback: map['feedback'],
      fileNames: parsedFiles,
      fileUrls: parsedFileUrls,
      fileName: map['fileName'],
      studentAnswerSheet: map['studentAnswerSheet'],
      assessmentSubmissionData: map['assessmentSubmissionData'],
    );
  }
}
