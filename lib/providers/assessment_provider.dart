import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/assessment.dart';
import '../models/assessment_submission.dart';
import '../models/learning_material.dart';

class AssessmentProvider extends ChangeNotifier {
  static const _materialsKey = 'edusync_learning_materials_v1';
  static const _draftsKey = 'edusync_assessment_drafts_v1';
  static const _submissionsKey = 'edusync_assessment_submissions_v1';
  final _uuid = const Uuid();

  List<LearningMaterial> _materials = [];
  List<Assessment> _drafts = [];
  final Map<String, List<AssessmentSubmission>> _submissions = {};
  bool _initialized = false;

  List<LearningMaterial> get materials => List.unmodifiable(_materials);
  List<Assessment> get drafts => List.unmodifiable(_drafts);

  Future<void> init() async {
    if (_initialized) return;
    await _loadFromPrefs();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Materials
      final materialsRaw = prefs.getString(_materialsKey);
      if (materialsRaw != null && materialsRaw.isNotEmpty) {
        final List list = jsonDecode(materialsRaw);
        _materials = list
            .map((e) => LearningMaterial.fromMap(e as Map<String, dynamic>))
            .toList();
      }

      // Load Drafts
      final draftsRaw = prefs.getString(_draftsKey);
      if (draftsRaw != null && draftsRaw.isNotEmpty) {
        final List list = jsonDecode(draftsRaw);
        _drafts = list
            .map((e) => Assessment.fromMap(e as Map<String, dynamic>))
            .toList();
      }

      // Load Submissions
      final subsRaw = prefs.getString(_submissionsKey);
      if (subsRaw != null && subsRaw.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(subsRaw);
        _submissions.clear();
        map.forEach((assessmentId, subList) {
          if (subList is List) {
            _submissions[assessmentId] = subList
                .map((e) => AssessmentSubmission.fromMap(e as Map<String, dynamic>))
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading assessment data: $e');
    }
  }

  Future<void> _saveMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_materials.map((m) => m.toMap()).toList());
    await prefs.setString(_materialsKey, jsonStr);
  }

  Future<void> _saveDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_drafts.map((d) => d.toMap()).toList());
    await prefs.setString(_draftsKey, jsonStr);
  }

  Future<void> _saveSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> map = {};
    _submissions.forEach((k, v) {
      map[k] = v.map((s) => s.toMap()).toList();
    });
    await prefs.setString(_submissionsKey, jsonEncode(map));
  }

  // --- Learning Materials Management ---

  Future<LearningMaterial> saveLearningMaterial({
    required String teacherId,
    required String title,
    required String content,
    String subject = 'General Education',
    String gradeLevel = 'High School',
    String? fileName,
    String fileType = 'pasted',
    String? summary,
    List<String>? keyConcepts,
    List<String>? learningObjectives,
    int recommendedQuestionCount = 10,
    String detectedDifficulty = 'Medium',
  }) async {
    final material = LearningMaterial(
      id: _uuid.v4(),
      teacherId: teacherId,
      title: title,
      content: content,
      subject: subject,
      gradeLevel: gradeLevel,
      fileName: fileName,
      fileType: fileType,
      summary: summary,
      keyConcepts: keyConcepts,
      learningObjectives: learningObjectives,
      recommendedQuestionCount: recommendedQuestionCount,
      detectedDifficulty: detectedDifficulty,
    );

    _materials.insert(0, material);
    await _saveMaterials();
    notifyListeners();
    return material;
  }

  Future<void> updateLearningMaterial(LearningMaterial updated) async {
    final idx = _materials.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      _materials[idx] = updated;
      await _saveMaterials();
      notifyListeners();
    }
  }

  Future<void> deleteLearningMaterial(String materialId) async {
    _materials.removeWhere((m) => m.id == materialId);
    await _saveMaterials();
    notifyListeners();
  }

  // --- Draft Assessments ---

  Future<void> saveDraft(Assessment assessment) async {
    final idx = _drafts.indexWhere((d) => d.id == assessment.id);
    if (idx != -1) {
      _drafts[idx] = assessment;
    } else {
      _drafts.insert(0, assessment);
    }
    await _saveDrafts();
    notifyListeners();
  }

  Future<void> deleteDraft(String assessmentId) async {
    _drafts.removeWhere((d) => d.id == assessmentId);
    await _saveDrafts();
    notifyListeners();
  }

  // --- Submissions & Analytics ---

  List<AssessmentSubmission> getSubmissionsForAssessment(String assessmentId) {
    return _submissions[assessmentId] ?? [];
  }

  AssessmentSubmission? getStudentSubmission(String assessmentId, String studentId) {
    final list = _submissions[assessmentId] ?? [];
    try {
      return list.firstWhere((s) => s.studentId == studentId);
    } catch (_) {
      return null;
    }
  }

  Future<void> recordSubmission(AssessmentSubmission submission) async {
    final list = _submissions.putIfAbsent(submission.assessmentId, () => []);
    list.removeWhere((s) => s.studentId == submission.studentId);
    list.add(submission);
    await _saveSubmissions();
    notifyListeners();
  }

  Future<void> updateSubmissionGrade({
    required String assessmentId,
    required String submissionId,
    required String questionId,
    required double newScore,
    String? feedback,
  }) async {
    final list = _submissions[assessmentId];
    if (list == null) return;
    final subIdx = list.indexWhere((s) => s.id == submissionId);
    if (subIdx == -1) return;

    final sub = list[subIdx];
    sub.questionScores[questionId] = newScore;
    if (feedback != null && feedback.isNotEmpty) {
      sub.feedback[questionId] = feedback;
    }

    // Recompute total score
    sub.totalScore = sub.questionScores.values.fold<double>(0.0, (sum, v) => sum + v);
    sub.isPassed = (sub.maxScore > 0) && ((sub.totalScore / sub.maxScore) * 100 >= 75.0);
    sub.isGraded = true;

    await _saveSubmissions();
    notifyListeners();
  }
}
