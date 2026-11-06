import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/activity.dart';
import '../models/announcement.dart';
import '../models/submission.dart';
import '../models/user.dart';

class ActivityProvider extends ChangeNotifier {
  List<Activity> _activities = [];
  List<Submission> _submissions = [];
  List<Announcement> _announcements = [];
  final _uuid = const Uuid();
  bool _isSyncing = false;

  List<Activity> get activities => _activities;
  List<Submission> get submissions => _submissions;
  List<Announcement> get announcements => _announcements;
  bool get isSyncing => _isSyncing;

  List<Announcement> announcementsForClass(String classId) =>
      _announcements.where((a) => a.classId == classId).toList()
        ..sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

  List<Activity> activitiesForClass(String classId) =>
      _activities.where((a) => a.classId == classId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Activity> activitiesForTeacher(String teacherId) =>
      _activities.where((a) => a.teacherId == teacherId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Submission> submissionsForActivity(String activityId) =>
      _submissions.where((s) => s.activityId == activityId).toList();

  List<Submission> submissionsForStudent(String studentId) =>
      _submissions.where((s) => s.studentId == studentId).toList();

  Submission? submissionForStudentActivity(String studentId, String activityId) {
    try {
      return _submissions
          .firstWhere((s) => s.studentId == studentId && s.activityId == activityId);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = prefs.getString('activities');
    final submissionsJson = prefs.getString('submissions');
    final announcementsJson = prefs.getString('announcements');

    if (activitiesJson != null) {
      final list = jsonDecode(activitiesJson) as List;
      _activities =
          list.map((m) => Activity.fromMap(Map<String, dynamic>.from(m))).toList();
    }
    if (submissionsJson != null) {
      final list = jsonDecode(submissionsJson) as List;
      _submissions =
          list.map((m) => Submission.fromMap(Map<String, dynamic>.from(m))).toList();
    }
    if (announcementsJson != null) {
      final list = jsonDecode(announcementsJson) as List;
      _announcements =
          list.map((m) => Announcement.fromMap(Map<String, dynamic>.from(m))).toList();
    }
  }

  Future<void> _saveData() async {
    _isSyncing = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'activities', jsonEncode(_activities.map((a) => a.toMap()).toList()));
    await prefs.setString(
        'submissions', jsonEncode(_submissions.map((s) => s.toMap()).toList()));
    await prefs.setString(
        'announcements', jsonEncode(_announcements.map((a) => a.toMap()).toList()));
    _isSyncing = false;
    notifyListeners();
  }

  // ─── Announcements ───────────────────────────────────────────────────────────

  Future<void> createAnnouncement({
    required String classId,
    required String teacherName,
    required String title,
    required String message,
    bool isPinned = false,
  }) async {
    final a = Announcement(
      id: _uuid.v4(),
      classId: classId,
      teacherName: teacherName,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      isPinned: isPinned,
    );
    _announcements.add(a);
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteAnnouncement(String id) async {
    _announcements.removeWhere((a) => a.id == id);
    await _saveData();
    notifyListeners();
  }

  // ─── Activities ──────────────────────────────────────────────────────────────

  Future<void> createActivity({
    required String title,
    required String description,
    required String classId,
    required String teacherId,
    required ActivityType type,
    required DateTime deadline,
    required double totalPoints,
    List<String>? attachments,
    String? attachmentName,
    String? answerSheetTemplate,
    String? teacherAnswerKey,
    required List<String> studentIds,
  }) async {
    final activity = Activity(
      id: _uuid.v4(),
      title: title,
      description: description,
      classId: classId,
      teacherId: teacherId,
      type: type,
      deadline: deadline,
      totalPoints: totalPoints,
      createdAt: DateTime.now(),
      attachments: attachments,
      attachmentName: attachmentName,
      answerSheetTemplate: answerSheetTemplate,
      teacherAnswerKey: teacherAnswerKey,
    );
    _activities.add(activity);

    for (final studentId in studentIds) {
      _submissions.add(Submission(
        id: _uuid.v4(),
        activityId: activity.id,
        studentId: studentId,
        studentName: '',
        status: SubmissionStatus.pending,
      ));
    }

    await _saveData();
    notifyListeners();
  }

  /// Automatically enroll newly added student into existing activities of their class
  Future<void> onStudentEnrolled({
    required String classId,
    required String studentId,
    required String studentName,
  }) async {
    final acts = activitiesForClass(classId);
    bool changed = false;
    for (final act in acts) {
      final exists = _submissions.any(
        (s) => s.activityId == act.id && s.studentId == studentId,
      );
      if (!exists) {
        _submissions.add(Submission(
          id: _uuid.v4(),
          activityId: act.id,
          studentId: studentId,
          studentName: studentName,
          status: SubmissionStatus.pending,
        ));
        changed = true;
      }
    }
    if (changed) {
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> submitActivity({
    required String activityId,
    required String studentId,
    required String studentName,
    List<String>? fileNames,
    String? fileName,
    String? studentAnswerSheet,
  }) async {
    final idx = _submissions
        .indexWhere((s) => s.activityId == activityId && s.studentId == studentId);

    if (idx != -1) {
      _submissions[idx] = Submission(
        id: _submissions[idx].id,
        activityId: activityId,
        studentId: studentId,
        studentName: studentName,
        status: SubmissionStatus.submitted,
        submittedAt: DateTime.now(),
        fileNames: fileNames,
        fileName: fileName,
        studentAnswerSheet: studentAnswerSheet,
      );
    } else {
      _submissions.add(Submission(
        id: _uuid.v4(),
        activityId: activityId,
        studentId: studentId,
        studentName: studentName,
        status: SubmissionStatus.submitted,
        submittedAt: DateTime.now(),
        fileNames: fileNames,
        fileName: fileName,
        studentAnswerSheet: studentAnswerSheet,
      ));
    }

    await _saveData();
    notifyListeners();
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
  }) async {
    final idx = _submissions.indexWhere((s) => s.id == submissionId);
    if (idx != -1) {
      final s = _submissions[idx];
      _submissions[idx] = Submission(
        id: s.id,
        activityId: s.activityId,
        studentId: s.studentId,
        studentName: s.studentName,
        status: SubmissionStatus.graded,
        submittedAt: s.submittedAt,
        grade: grade,
        feedback: feedback,
        fileName: s.fileName,
      );
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> markMissing(String submissionId) async {
    final idx = _submissions.indexWhere((s) => s.id == submissionId);
    if (idx != -1) {
      final s = _submissions[idx];
      _submissions[idx] = Submission(
        id: s.id,
        activityId: s.activityId,
        studentId: s.studentId,
        studentName: s.studentName,
        status: SubmissionStatus.missing,
        submittedAt: s.submittedAt,
        grade: 0,
        feedback: s.feedback,
        fileName: s.fileName,
      );
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> deleteActivity(String activityId) async {
    _activities.removeWhere((a) => a.id == activityId);
    _submissions.removeWhere((s) => s.activityId == activityId);
    await _saveData();
    notifyListeners();
  }

  // ─── CSV Export ───────────────────────────────────────────────────────────────

  /// Builds a CSV gradebook and saves to the temp directory. Returns the file path.
  Future<String> exportGradebookCsv({
    required String classId,
    required List<User> students,
  }) async {
    final acts = activitiesForClass(classId);
    final buffer = StringBuffer();

    // Header
    buffer.write('Student Name');
    for (final a in acts) {
      buffer.write(',${a.title.replaceAll(',', ';')} (/${a.totalPoints.toInt()})');
    }
    buffer.write(',Total Earned,Total Possible,Percentage\n');

    // Rows
    for (final student in students) {
      final subs = submissionsForStudent(student.id);
      buffer.write(student.name.replaceAll(',', ' '));
      double earned = 0;
      double possible = 0;
      for (final a in acts) {
        Submission? sub;
        try {
          sub = subs.firstWhere((s) => s.activityId == a.id);
        } catch (_) {}
        final grade = sub?.grade;
        buffer.write(',${grade != null ? grade.toStringAsFixed(1) : "-"}');
        if (grade != null) earned += grade;
        possible += a.totalPoints;
      }
      final pct =
          possible > 0 ? ((earned / possible) * 100).toStringAsFixed(1) : '0.0';
      buffer.write(',$earned,$possible,$pct%\n');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/gradebook_${classId.substring(0, 8)}.csv');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  // ─── Demo Seed ────────────────────────────────────────────────────────────────

  Future<void> seedDemoActivities({
    required String classId,
    required String teacherId,
    required List<String> studentIds,
    required List<String> studentNames,
  }) async {
    if (_activities.isNotEmpty) return;
    final now = DateTime.now();

    final acts = [
      Activity(
        id: _uuid.v4(),
        title: 'Chapter 1 Reading Assignment',
        description:
            'Read Chapter 1 of the textbook and write a one-page summary.',
        classId: classId,
        teacherId: teacherId,
        type: ActivityType.assignment,
        deadline: now.add(const Duration(days: 3)),
        totalPoints: 20,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      Activity(
        id: _uuid.v4(),
        title: 'Quiz 1 – Scientific Method',
        description: '15-item multiple choice quiz about the scientific method.',
        classId: classId,
        teacherId: teacherId,
        type: ActivityType.quiz,
        deadline: now.subtract(const Duration(days: 1)),
        totalPoints: 30,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      Activity(
        id: _uuid.v4(),
        title: 'Group Science Project',
        description:
            'Build a prototype demonstrating a scientific concept of your choice.',
        classId: classId,
        teacherId: teacherId,
        type: ActivityType.project,
        deadline: now.add(const Duration(days: 14)),
        totalPoints: 100,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];

    for (final a in acts) {
      _activities.add(a);
      for (int i = 0; i < studentIds.length; i++) {
        _submissions.add(Submission(
          id: _uuid.v4(),
          activityId: a.id,
          studentId: studentIds[i],
          studentName: studentNames[i],
          status: SubmissionStatus.pending,
        ));
      }
    }

    // Mark first student's quiz as graded
    if (studentIds.isNotEmpty) {
      final quizActivity = acts[1];
      final subIdx = _submissions.indexWhere((s) =>
          s.activityId == quizActivity.id && s.studentId == studentIds[0]);
      if (subIdx != -1) {
        final s = _submissions[subIdx];
        _submissions[subIdx] = Submission(
          id: s.id,
          activityId: s.activityId,
          studentId: s.studentId,
          studentName: s.studentName,
          status: SubmissionStatus.graded,
          submittedAt: now.subtract(const Duration(hours: 2)),
          grade: 27,
          feedback: 'Excellent work! Keep it up.',
          fileName: 'quiz1_answers.pdf',
        );
      }
    }

    // Seed demo announcements
    if (_announcements.isEmpty) {
      _announcements.addAll([
        Announcement(
          id: _uuid.v4(),
          classId: classId,
          teacherName: 'Teacher',
          title: '📌 Welcome to EduSync!',
          message:
              'Welcome to our class management system. All activities, grades, and announcements will be posted here. Check in regularly!',
          createdAt: now.subtract(const Duration(days: 3)),
          isPinned: true,
        ),
        Announcement(
          id: _uuid.v4(),
          classId: classId,
          teacherName: 'Teacher',
          title: 'Quiz 1 Reminder',
          message:
              'Quiz 1 on the Scientific Method is due tomorrow. Review your notes carefully. Good luck!',
          createdAt: now.subtract(const Duration(days: 1)),
          isPinned: false,
        ),
      ]);
    }

    await _saveData();
    notifyListeners();
  }
}
