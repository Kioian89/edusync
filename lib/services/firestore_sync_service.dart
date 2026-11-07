import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_group.dart';
import '../models/activity.dart';
import '../models/submission.dart';
import '../models/announcement.dart';

/// Centralized service handling real-time synchronization between EduSync
/// and Cloud Firestore with offline cache support.
class FirestoreSyncService {
  static bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static FirebaseFirestore? get _db {
    if (!isAvailable) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('Firestore instance unavailable: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CLASSES
  // ---------------------------------------------------------------------------

  /// Stream of classes taught by a teacher.
  static Stream<List<ClassGroup>> streamClassesForTeacher(String teacherId) {
    final db = _db;
    if (db == null) return const Stream.empty();

    return db
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ClassGroup.fromMap(data);
      }).toList();
    });
  }

  /// Stream of classes a student is enrolled in.
  static Stream<List<ClassGroup>> streamClassesForStudent(String studentId) {
    final db = _db;
    if (db == null) return const Stream.empty();

    return db
        .collection('classes')
        .where('studentIds', arrayContains: studentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ClassGroup.fromMap(data);
      }).toList();
    });
  }

  /// Save or update a class group.
  static Future<void> saveClass(ClassGroup cls) async {
    final db = _db;
    if (db == null) return;

    try {
      await db.collection('classes').doc(cls.id).set(cls.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveClass error: $e');
    }
  }

  /// Fetch a single class by ID.
  static Future<ClassGroup?> getClassById(String classId) async {
    final db = _db;
    if (db == null) return null;

    try {
      final doc = await db.collection('classes').doc(classId).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return ClassGroup.fromMap(data);
    } catch (e) {
      debugPrint('Firestore getClassById error: $e');
      return null;
    }
  }

  /// Add a student to a class roster atomically.
  static Future<void> addStudentToClass({
    required String classId,
    required String studentId,
  }) async {
    final db = _db;
    if (db == null) return;

    try {
      final batch = db.batch();
      final classRef = db.collection('classes').doc(classId);
      final userRef = db.collection('users').doc(studentId);

      batch.update(classRef, {
        'studentIds': FieldValue.arrayUnion([studentId]),
      });
      batch.update(userRef, {
        'classId': classId,
        'enrolledClassIds': FieldValue.arrayUnion([classId]),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Firestore addStudentToClass error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIVITIES
  // ---------------------------------------------------------------------------

  /// Stream activities for a list of class IDs.
  static Stream<List<Activity>> streamActivitiesForClasses(List<String> classIds) {
    final db = _db;
    if (db == null || classIds.isEmpty) return const Stream.empty();

    // Firestore whereIn supports up to 30 items
    final safeClassIds = classIds.take(30).toList();

    return db
        .collection('activities')
        .where('classId', whereIn: safeClassIds)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Activity.fromMap(data);
      }).toList();
    });
  }

  /// Create or update an activity.
  static Future<void> saveActivity(Activity activity) async {
    final db = _db;
    if (db == null) return;

    try {
      await db.collection('activities').doc(activity.id).set(
            activity.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Firestore saveActivity error: $e');
    }
  }

  /// Delete an activity and its associated submissions.
  static Future<void> deleteActivity(String activityId) async {
    final db = _db;
    if (db == null) return;

    try {
      await db.collection('activities').doc(activityId).delete();

      // Clean up submissions for this activity
      final subSnap = await db
          .collection('submissions')
          .where('activityId', isEqualTo: activityId)
          .get();

      final batch = db.batch();
      for (final doc in subSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore deleteActivity error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SUBMISSIONS
  // ---------------------------------------------------------------------------

  /// Stream submissions for a student.
  static Stream<List<Submission>> streamSubmissionsForStudent(String studentId) {
    final db = _db;
    if (db == null) return const Stream.empty();

    return db
        .collection('submissions')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Submission.fromMap(data);
      }).toList();
    });
  }

  /// Stream submissions for a specific activity (for teachers).
  static Stream<List<Submission>> streamSubmissionsForActivity(String activityId) {
    final db = _db;
    if (db == null) return const Stream.empty();

    return db
        .collection('submissions')
        .where('activityId', isEqualTo: activityId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Submission.fromMap(data);
      }).toList();
    });
  }

  /// Stream all submissions across activities taught by a teacher.
  static Stream<List<Submission>> streamSubmissionsForActivities(List<String> activityIds) {
    final db = _db;
    if (db == null || activityIds.isEmpty) return const Stream.empty();

    final safeIds = activityIds.take(30).toList();

    return db
        .collection('submissions')
        .where('activityId', whereIn: safeIds)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Submission.fromMap(data);
      }).toList();
    });
  }

  /// Save or update a student submission (grades, status, answers).
  static Future<void> saveSubmission(Submission submission) async {
    final db = _db;
    if (db == null) return;

    try {
      // Use deterministic ID: {activityId}_{studentId}
      final docId = '${submission.activityId}_${submission.studentId}';
      await db.collection('submissions').doc(docId).set(
            submission.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Firestore saveSubmission error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ANNOUNCEMENTS
  // ---------------------------------------------------------------------------

  /// Stream announcements for a list of class IDs.
  static Stream<List<Announcement>> streamAnnouncementsForClasses(List<String> classIds) {
    final db = _db;
    if (db == null || classIds.isEmpty) return const Stream.empty();

    final safeIds = classIds.take(30).toList();

    return db
        .collection('announcements')
        .where('classId', whereIn: safeIds)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Announcement.fromMap(data);
      }).toList();
    });
  }

  /// Save an announcement.
  static Future<void> saveAnnouncement(Announcement announcement) async {
    final db = _db;
    if (db == null) return;

    try {
      await db.collection('announcements').doc(announcement.id).set(
            announcement.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Firestore saveAnnouncement error: $e');
    }
  }

  /// Delete an announcement.
  static Future<void> deleteAnnouncement(String announcementId) async {
    final db = _db;
    if (db == null) return;

    try {
      await db.collection('announcements').doc(announcementId).delete();
    } catch (e) {
      debugPrint('Firestore deleteAnnouncement error: $e');
    }
  }
}

