import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/user.dart';
import '../models/class_group.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/supabase_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  List<User> _users = [];
  List<ClassGroup> _classes = [];
  final _uuid = const Uuid();
  StreamSubscription? _classesSubscription;

  User? get currentUser => _currentUser;
  List<User> get users => _users;
  List<ClassGroup> get classes => _classes;
  bool get isLoggedIn => _currentUser != null;
  bool get isTeacher => _currentUser?.role == UserRole.teacher;

  List<ClassGroup> get teacherClasses =>
      _classes.where((c) => c.teacherId == _currentUser?.id).toList();

  final Set<String> _pendingStudentFetches = {};

  List<User> studentsInClass(String classId) {
    final cls = _classes.firstWhere(
      (c) => c.id == classId,
      orElse: () => ClassGroup(
        id: '',
        name: '',
        subject: '',
        section: '',
        teacherId: '',
        studentIds: [],
      ),
    );

    // Proactively fetch student details from Firestore if missing locally
    _fetchMissingStudentProfiles(cls.studentIds);

    return cls.studentIds.map((sid) {
      final match = _users.where((u) => u.id == sid).firstOrNull;
      if (match != null) return match;
      return User(
        id: sid,
        name:
            'Student (${sid.length > 6 ? sid.substring(sid.length - 4) : sid})',
        email: '',
        role: UserRole.student,
        classId: classId,
      );
    }).toList();
  }

  void _fetchMissingStudentProfiles(List<String> studentIds) {
    if (!FirebaseAuthService.isFirebaseAvailable) return;
    final missing = studentIds
        .where(
          (id) =>
              !_users.any((u) => u.id == id) &&
              !_pendingStudentFetches.contains(id),
        )
        .toList();
    if (missing.isEmpty) return;

    _pendingStudentFetches.addAll(missing);
    Future.microtask(() async {
      bool changed = false;
      for (final id in missing) {
        try {
          final profile = await FirebaseAuthService.getUserProfile(id);
          if (profile != null) {
            final u = User(
              id: id,
              name:
                  profile['name'] ??
                  'Student (${id.length > 4 ? id.substring(id.length - 4) : id})',
              email: profile['email'] ?? '',
              role: UserRole.student,
              classId: profile['classId'],
              enrolledClassIds: List<String>.from(
                profile['enrolledClassIds'] ?? [],
              ),
              photoUrl: profile['photoUrl'],
            );
            final idx = _users.indexWhere((existing) => existing.id == id);
            if (idx != -1) {
              _users[idx] = u;
            } else {
              _users.add(u);
            }
            changed = true;
          }
        } catch (e) {
          debugPrint('Error fetching student profile $id: $e');
        }
      }
      if (changed) {
        _saveData();
        notifyListeners();
      }
    });
  }

  List<ClassGroup> get studentClasses {
    if (_currentUser == null) return [];
    return _classes
        .where((c) => c.studentIds.contains(_currentUser!.id))
        .toList();
  }

  ClassGroup? studentClass([String? classId]) {
    if (_currentUser == null) return null;
    if (classId != null && classId.isNotEmpty) {
      try {
        return _classes.firstWhere(
          (c) => c.id == classId && c.studentIds.contains(_currentUser!.id),
        );
      } catch (_) {}
    }
    try {
      return _classes.firstWhere(
        (c) => c.studentIds.contains(_currentUser!.id),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    await _loadData();
  }

  /// Exposed strictly for automated test suites
  void seedDemoAccountsForTesting() {
    final teacherId = _uuid.v4();
    final studentId1 = _uuid.v4();
    final studentId2 = _uuid.v4();
    final studentId3 = _uuid.v4();
    final classId = _uuid.v4();

    _users = [
      User(
        id: teacherId,
        name: 'Ms. Santos',
        email: 'teacher@edusync.com',
        password: 'teacher123',
        role: UserRole.teacher,
      ),
      User(
        id: studentId1,
        name: 'Juan dela Cruz',
        email: 'juan@edusync.com',
        password: 'student123',
        role: UserRole.student,
        classId: classId,
      ),
      User(
        id: studentId2,
        name: 'Maria Reyes',
        email: 'maria@edusync.com',
        password: 'student123',
        role: UserRole.student,
        classId: classId,
      ),
      User(
        id: studentId3,
        name: 'Pedro Garcia',
        email: 'pedro@edusync.com',
        password: 'student123',
        role: UserRole.student,
        classId: classId,
      ),
    ];

    _classes = [
      ClassGroup(
        id: classId,
        name: 'Grade 10 - Science',
        subject: 'Science',
        section: 'Section A',
        teacherId: teacherId,
        studentIds: [studentId1, studentId2, studentId3],
      ),
    ];
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('users');
    final classesJson = prefs.getString('classes');
    final currentUserId = prefs.getString('currentUserId');

    if (usersJson != null) {
      final list = jsonDecode(usersJson) as List;
      _users = list
          .map((m) => User.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    if (classesJson != null) {
      final list = jsonDecode(classesJson) as List;
      _classes = list
          .map((m) => ClassGroup.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    if (currentUserId != null) {
      try {
        _currentUser = _users.firstWhere((u) => u.id == currentUserId);
        // Restore locally cached profile photo if the stored user has no photoUrl
        final localPhoto = prefs.getString('photo_$currentUserId');
        if (localPhoto != null && _currentUser!.photoUrl == null) {
          _currentUser = _currentUser!.copyWith(photoUrl: localPhoto);
        }
        startListeningToClasses();
      } catch (_) {}
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'users',
      jsonEncode(_users.map((u) => u.toMap()).toList()),
    );
    await prefs.setString(
      'classes',
      jsonEncode(_classes.map((c) => c.toMap()).toList()),
    );
  }

  Future<String?> login(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPass = password;

    // 1. Try Firebase Authentication first if available
    if (FirebaseAuthService.isFirebaseAvailable) {
      try {
        final cred = await FirebaseAuthService.signInWithEmail(
          email: cleanEmail,
          password: cleanPass,
        );

        if (cred?.user != null) {
          final fbUser = cred!.user!;
          User? matchedUser = _users
              .where((u) => u.id == fbUser.uid)
              .firstOrNull;
          matchedUser ??= _users
              .where((u) => u.email.toLowerCase() == cleanEmail.toLowerCase())
              .firstOrNull;

          final profile = await FirebaseAuthService.getUserProfile(fbUser.uid);
          if (profile != null) {
            matchedUser = User.fromMap({
              ...?matchedUser?.toMap(),
              ...profile,
              'id': fbUser.uid,
              'name': profile['name'] ?? fbUser.displayName ?? 'EduSync User',
              'email': fbUser.email ?? cleanEmail,
            });
          } else {
            matchedUser ??= User(
              id: fbUser.uid,
              name: fbUser.displayName ?? cleanEmail.split('@').first,
              email: fbUser.email ?? cleanEmail,
              role: UserRole.student,
            );
          }

          final existingUserIndex = _users.indexWhere(
            (user) => user.id == fbUser.uid,
          );
          if (existingUserIndex == -1) {
            _users.add(matchedUser);
          } else {
            _users[existingUserIndex] = matchedUser;
          }
          await _saveData();

          _currentUser = matchedUser;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('currentUserId', matchedUser.id);
          startListeningToClasses();
          notifyListeners();
          return null;
        }
      } on fb.FirebaseAuthException catch (e) {
        // Fallback for pre-seeded offline demo accounts (teacher@edusync.com, etc.)
        try {
          final demoUser = _users.firstWhere(
            (u) =>
                u.email.toLowerCase() == cleanEmail.toLowerCase() &&
                u.password == cleanPass,
          );
          _currentUser = demoUser;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('currentUserId', demoUser.id);
          startListeningToClasses();
          notifyListeners();
          return null;
        } catch (_) {
          return FirebaseAuthService.getFriendlyErrorMessage(e);
        }
      } catch (e) {
        debugPrint('Firebase login unexpected error: $e');
      }
    }

    // 2. Local fallback if Firebase is not active or offline
    try {
      final user = _users.firstWhere(
        (u) =>
            u.email.toLowerCase() == cleanEmail.toLowerCase() &&
            u.password == cleanPass,
      );
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', user.id);
      startListeningToClasses();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Invalid email or password.';
    }
  }

  Future<String?> completeCurrentUserProfile({
    String? studentId,
    DateTime? birthday,
    String? course,
    String? yearLevel,
    String? section,
    String? employeeId,
    String? department,
    List<String>? coursesTaught,
  }) async {
    final user = _currentUser;
    if (user == null) return 'Sign in before completing your profile.';

    final updatedUser = user.copyWith(
      studentId: studentId?.trim(),
      birthday: birthday,
      course: course?.trim(),
      yearLevel: yearLevel?.trim(),
      section: section?.trim(),
      employeeId: employeeId?.trim(),
      department: department?.trim(),
      coursesTaught: coursesTaught,
      profileComplete: true,
    );
    if (!updatedUser.hasCompleteProfile) {
      return 'Please complete all required profile fields.';
    }

    try {
      await FirebaseAuthService.saveOnboardingProfile(
        uid: user.id,
        details: {
          if (updatedUser.studentId != null) 'studentId': updatedUser.studentId,
          if (updatedUser.birthday != null)
            'birthday': updatedUser.birthday!.toIso8601String(),
          if (updatedUser.course != null) 'course': updatedUser.course,
          if (updatedUser.yearLevel != null) 'yearLevel': updatedUser.yearLevel,
          if (updatedUser.section != null) 'section': updatedUser.section,
          if (updatedUser.employeeId != null)
            'employeeId': updatedUser.employeeId,
          if (updatedUser.department != null)
            'department': updatedUser.department,
          if (updatedUser.coursesTaught.isNotEmpty)
            'coursesTaught': updatedUser.coursesTaught,
        },
      );
    } catch (error) {
      debugPrint('Profile onboarding save failed: $error');
      return 'Could not save your profile. Check your connection and try again.';
    }

    _currentUser = updatedUser;
    final index = _users.indexWhere((candidate) => candidate.id == user.id);
    if (index == -1) {
      _users.add(updatedUser);
    } else {
      _users[index] = updatedUser;
    }
    await _saveData();
    await SupabaseStorageService.syncUserClaims(userId: user.id);
    notifyListeners();
    return null;
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? classId,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = name.trim();

    final exists = _users.any(
      (u) => u.email.toLowerCase() == cleanEmail.toLowerCase(),
    );
    if (exists) return 'An account with this email already exists.';

    String userId = _uuid.v4();

    // 1. Register with Firebase Authentication if available
    if (FirebaseAuthService.isFirebaseAvailable) {
      try {
        final cred = await FirebaseAuthService.registerWithEmail(
          email: cleanEmail,
          password: password,
          displayName: cleanName,
        );

        if (cred?.user != null) {
          userId = cred!.user!.uid;
          await FirebaseAuthService.saveUserProfile(
            uid: userId,
            name: cleanName,
            email: cleanEmail,
            role: role.name,
            classId: classId,
            enrolledClassIds: classId != null ? [classId] : [],
          );
        }
      } on fb.FirebaseAuthException catch (e) {
        return FirebaseAuthService.getFriendlyErrorMessage(e);
      } catch (e) {
        debugPrint('Firebase registration error: $e');
        return 'Account was created, but its profile could not be saved: $e';
      }
    }

    final newUser = User(
      id: userId,
      name: cleanName,
      email: cleanEmail,
      password: password,
      role: role,
      classId: classId,
    );
    _users.add(newUser);

    if (role == UserRole.student && classId != null) {
      final classIdx = _classes.indexWhere((c) => c.id == classId);
      if (classIdx != -1) {
        final cls = _classes[classIdx];
        _classes[classIdx] = ClassGroup(
          id: cls.id,
          name: cls.name,
          subject: cls.subject,
          section: cls.section,
          teacherId: cls.teacherId,
          studentIds: [...cls.studentIds, newUser.id],
          maxStudents: cls.maxStudents,
        );
      }
    }

    await _saveData();
    await SupabaseStorageService.syncUserClaims(
      userId: userId,
      classId: classId,
    );
    notifyListeners();
    return null;
  }

  Future<ClassGroup?> createClass({
    required String subject,
    required String section,
    int maxStudents = 30,
  }) async {
    if (_currentUser == null) return null;
    final cls = ClassGroup(
      id: _uuid.v4(),
      name: '$subject - $section',
      subject: subject,
      section: section,
      teacherId: _currentUser!.id,
      studentIds: [],
      maxStudents: maxStudents,
    );
    _classes.add(cls);
    await _saveData();
    if (FirestoreSyncService.isAvailable) {
      await FirestoreSyncService.saveClass(cls);
    }
    await SupabaseStorageService.syncUserClaims(
      userId: _currentUser!.id,
      classId: cls.id,
    );
    notifyListeners();
    return cls;
  }

  /// Update/Edit an existing class group
  Future<ClassGroup?> updateClass({
    required String classId,
    required String subject,
    required String section,
    int? maxStudents,
  }) async {
    final idx = _classes.indexWhere((c) => c.id == classId);
    if (idx == -1) return null;

    final existing = _classes[idx];
    final updated = ClassGroup(
      id: existing.id,
      name: '$subject - $section',
      subject: subject,
      section: section,
      teacherId: existing.teacherId,
      studentIds: existing.studentIds,
      maxStudents: maxStudents ?? existing.maxStudents,
    );

    _classes[idx] = updated;
    await _saveData();
    if (FirestoreSyncService.isAvailable) {
      await FirestoreSyncService.saveClass(updated);
    }
    await SupabaseStorageService.syncUserClaims(
      userId: existing.teacherId,
      classId: updated.id,
    );
    notifyListeners();
    return updated;
  }

  /// Delete a class group
  Future<bool> deleteClass(String classId) async {
    final idx = _classes.indexWhere((c) => c.id == classId);
    if (idx == -1) return false;

    final existing = _classes[idx];
    final affectedUserIds = [existing.teacherId, ...existing.studentIds];

    _classes.removeAt(idx);
    await _saveData();
    if (FirestoreSyncService.isAvailable) {
      await FirestoreSyncService.deleteClass(classId);
    }
    await SupabaseStorageService.syncUserClaims(
      userIds: affectedUserIds,
    );
    notifyListeners();
    return true;
  }

  /// Look up class by ID locally or from Firestore
  Future<ClassGroup?> fetchClassById(String classId) async {
    final localIdx = _classes.indexWhere((c) => c.id == classId);
    if (localIdx != -1) return _classes[localIdx];

    if (FirestoreSyncService.isAvailable) {
      ClassGroup? remote;
      try {
        remote = await FirestoreSyncService.getClassById(classId);
      } catch (error) {
        debugPrint('Could not fetch class $classId: $error');
        return null;
      }
      if (remote != null) {
        _classes.add(remote);
        await _saveData();
        notifyListeners();
        return remote;
      }
    }
    return null;
  }

  /// Add student to a class by their student ID.
  /// Returns null on success, or an error message if student not found or already enrolled.
  Future<String?> addStudentToClass({
    required String classId,
    required String studentId,
  }) async {
    var classIdx = _classes.indexWhere((c) => c.id == classId);
    final isSelfStudentEnrollment =
        _currentUser?.id == studentId && _currentUser?.role == UserRole.student;

    if (isSelfStudentEnrollment && FirestoreSyncService.isAvailable) {
      ClassGroup? remote;
      try {
        remote = await FirestoreSyncService.getClassById(classId);
      } catch (error) {
        return 'Could not verify the class section. Please try again. $error';
      }
      if (remote == null) {
        return 'Class not found. Please check the QR code or Join Code.';
      }
      if (classIdx == -1) {
        _classes.add(remote);
        classIdx = _classes.length - 1;
      } else {
        _classes[classIdx] = remote;
      }
    } else if (classIdx == -1) {
      // Try to fetch remote class if not loaded yet
      if (FirestoreSyncService.isAvailable) {
        ClassGroup? remote;
        try {
          remote = await FirestoreSyncService.getClassById(classId);
        } catch (error) {
          return 'Could not load the class. Please try again. $error';
        }
        if (remote != null) {
          _classes.add(remote);
          classIdx = _classes.indexWhere((c) => c.id == classId);
        }
      }
    }

    if (classIdx == -1) {
      return 'Class not found. Please check the QR code or Join Code.';
    }

    var studentIdx = _users.indexWhere((u) => u.id == studentId);
    User? student;

    if (studentIdx != -1) {
      student = _users[studentIdx];
    } else if (_currentUser != null && _currentUser!.id == studentId) {
      student = _currentUser!;
      _users.add(student);
      studentIdx = _users.length - 1;
    } else if (FirebaseAuthService.isFirebaseAvailable) {
      // Universal cross-device lookup: fetch remote student profile if not local
      final profile = await FirebaseAuthService.getUserProfile(studentId);
      if (profile != null) {
        student = User(
          id: studentId,
          name: profile['name'] ?? 'Student',
          email: profile['email'] ?? '',
          role: UserRole.student,
          classId: classId,
          enrolledClassIds: List<String>.from(
            profile['enrolledClassIds'] ?? [classId],
          ),
        );
        _users.add(student);
        studentIdx = _users.length - 1;
      }
    }

    if (student == null) {
      student = User(
        id: studentId,
        name:
            'Student (${studentId.length > 4 ? studentId.substring(studentId.length - 4) : studentId})',
        email: '$studentId@edusync.internal',
        role: UserRole.student,
        classId: classId,
      );
      _users.add(student);
      studentIdx = _users.length - 1;
    }

    if (student.role != UserRole.student) {
      return 'User is not a student.';
    }

    final cls = _classes[classIdx];
    if (cls.studentIds.contains(studentId)) {
      return 'You are already enrolled in ${cls.displayName}.';
    }
    if (cls.studentIds.length >= cls.maxStudents) {
      return '${cls.displayName} is full (${cls.maxStudents} students maximum).';
    }
    if (isSelfStudentEnrollment) {
      final assignedSection = _normalizeSection(_currentUser!.section);
      final classSection = _normalizeSection(cls.section);
      if (assignedSection.isEmpty) {
        return 'Complete your profile and enter your school-assigned section before joining a class.';
      }
      if (classSection.isEmpty || assignedSection != classSection) {
        return 'This class is for section "${cls.section}". Your profile section is "${_currentUser!.section ?? 'not set'}". Ask your teacher if this is incorrect.';
      }
    }

    _classes[classIdx] = ClassGroup(
      id: cls.id,
      name: cls.name,
      subject: cls.subject,
      section: cls.section,
      teacherId: cls.teacherId,
      studentIds: [...cls.studentIds, studentId],
      maxStudents: cls.maxStudents,
    );

    // Update student's primary classId and list of all enrolled classes
    final updatedEnrolled = {...student.enrolledClassIds, classId}.toList();
    final updatedStudent = student.copyWith(
      classId: classId,
      enrolledClassIds: updatedEnrolled,
    );
    _users[studentIdx] = updatedStudent;

    if (_currentUser != null && _currentUser!.id == studentId) {
      _currentUser = updatedStudent;
    }

    await _saveData();
    if (FirestoreSyncService.isAvailable) {
      try {
        await FirestoreSyncService.addStudentToClass(
          classId: classId,
          studentId: studentId,
        );
      } catch (error) {
        _classes[classIdx] = cls;
        _users[studentIdx] = student;
        if (_currentUser?.id == studentId) _currentUser = student;
        await _saveData();
        return 'Could not join ${cls.displayName}: $error';
      }
    }
    await SupabaseStorageService.syncUserClaims(
      userId: studentId,
      classId: classId,
    );
    notifyListeners();
    return null;
  }

  /// Allow a student to join a class using a scanned class ID
  Future<String?> joinClassByStudent({
    required String classId,
    required String studentId,
  }) async {
    return addStudentToClass(classId: classId, studentId: studentId);
  }

  /// Remove a student from a teacher-owned class and its roster.
  Future<String?> removeStudentFromClass({
    required String classId,
    required String studentId,
  }) async {
    final classIdx = _classes.indexWhere((cls) => cls.id == classId);
    if (classIdx == -1) return 'Class not found.';

    final cls = _classes[classIdx];
    if (_currentUser?.role != UserRole.teacher ||
        _currentUser?.id != cls.teacherId) {
      return 'Only this class teacher can remove a student.';
    }
    if (!cls.studentIds.contains(studentId)) {
      return 'This student is not enrolled in the class.';
    }

    final updated = ClassGroup(
      id: cls.id,
      name: cls.name,
      subject: cls.subject,
      section: cls.section,
      teacherId: cls.teacherId,
      studentIds: cls.studentIds.where((id) => id != studentId).toList(),
      maxStudents: cls.maxStudents,
    );
    _classes[classIdx] = updated;
    await _saveData();

    if (FirestoreSyncService.isAvailable) {
      try {
        await FirestoreSyncService.removeStudentFromClass(
          classId: classId,
          studentId: studentId,
        );
      } catch (error) {
        _classes[classIdx] = cls;
        await _saveData();
        return 'Could not remove the student. $error';
      }
    }
    await SupabaseStorageService.syncUserClaims(
      userId: studentId,
      classId: classId,
    );
    notifyListeners();
    return null;
  }

  static String _normalizeSection(String? section) =>
      section?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ?? '';

  /// Register or update a class discovered via QR code or remote stream.
  void registerLocalClass(ClassGroup cls) {
    final idx = _classes.indexWhere((c) => c.id == cls.id);
    if (idx != -1) {
      final existing = _classes[idx];
      final mergedStudentIds = {
        ...existing.studentIds,
        ...cls.studentIds,
      }.toList();
      _classes[idx] = ClassGroup(
        id: cls.id,
        name: cls.name.isNotEmpty ? cls.name : existing.name,
        subject: cls.subject.isNotEmpty ? cls.subject : existing.subject,
        section: cls.section.isNotEmpty ? cls.section : existing.section,
        teacherId: cls.teacherId.isNotEmpty
            ? cls.teacherId
            : existing.teacherId,
        studentIds: mergedStudentIds,
        maxStudents: existing.maxStudents,
      );
    } else {
      _classes.add(cls);
    }
    _saveData();
    notifyListeners();
  }

  /// Register or update a student profile discovered via QR code or remote lookup.
  void registerLocalStudent(User student) {
    final idx = _users.indexWhere((u) => u.id == student.id);
    if (idx != -1) {
      _users[idx] = student;
    } else {
      _users.add(student);
    }
    _saveData();
    notifyListeners();
  }

  /// Start real-time Firestore synchronization for classes.
  void startListeningToClasses() {
    _classesSubscription?.cancel();
    if (_currentUser == null || !FirestoreSyncService.isAvailable) return;

    final stream = _currentUser!.role == UserRole.teacher
        ? FirestoreSyncService.streamClassesForTeacher(_currentUser!.id)
        : FirestoreSyncService.streamClassesForStudent(_currentUser!.id);

    _classesSubscription = stream.listen(
      (remoteClasses) {
        if (remoteClasses.isNotEmpty) {
          bool changed = false;
          final List<String> allRemoteStudentIds = [];
          for (final remote in remoteClasses) {
            allRemoteStudentIds.addAll(remote.studentIds);
            final idx = _classes.indexWhere((c) => c.id == remote.id);
            if (idx != -1) {
              _classes[idx] = remote;
              changed = true;
            } else {
              _classes.add(remote);
              changed = true;
            }
          }
          if (allRemoteStudentIds.isNotEmpty) {
            _fetchMissingStudentProfiles(allRemoteStudentIds);
          }
          if (changed) {
            _saveData();
            notifyListeners();
          }
        }
      },
      onError: (e) {
        debugPrint('Firestore classes stream error: $e');
      },
    );
  }

  /// Send password reset link to user's email via Firebase Auth.
  Future<String?> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return 'Please provide an email address.';

    if (FirebaseAuthService.isFirebaseAvailable) {
      try {
        await FirebaseAuthService.sendPasswordReset(cleanEmail);
        return null;
      } on fb.FirebaseAuthException catch (e) {
        return FirebaseAuthService.getFriendlyErrorMessage(e);
      } catch (e) {
        return 'Failed to send password reset: $e';
      }
    }
    return 'Firebase Authentication is not available.';
  }

  /// Update the current user's profile photo.
  /// Uploads to Firebase Storage when available; falls back to local base64 storage.
  /// Returns null on success, or an error message string on failure.
  Future<String?> updateProfilePhoto(XFile imageFile) async {
    if (_currentUser == null) return 'Not logged in.';
    try {
      final bytes = await imageFile.readAsBytes();
      final prefs = await SharedPreferences.getInstance();

      String photoUrl;

      // Try Firebase Storage upload first
      if (FirebaseAuthService.isFirebaseAvailable) {
        try {
          final ref = firebase_storage.FirebaseStorage.instance.ref().child(
            'profile_photos/${_currentUser!.id}.jpg',
          );
          final task = await ref.putData(
            bytes,
            firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
          );
          photoUrl = await task.ref.getDownloadURL();
        } catch (e) {
          debugPrint('Firebase Storage upload failed, using local base64: $e');
          photoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      } else {
        photoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      // Always cache locally as base64 for offline access
      final localBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await prefs.setString('photo_${_currentUser!.id}', localBase64);

      final updatedUser = _currentUser!.copyWith(photoUrl: photoUrl);
      final idx = _users.indexWhere((u) => u.id == _currentUser!.id);
      if (idx != -1) _users[idx] = updatedUser;
      _currentUser = updatedUser;

      await _saveData();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to update photo: $e';
    }
  }

  Future<void> logout() async {
    _classesSubscription?.cancel();
    if (FirebaseAuthService.isFirebaseAvailable) {
      try {
        await FirebaseAuthService.signOut();
      } catch (e) {
        debugPrint('Firebase signOut warning: $e');
      }
    }
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUserId');
    notifyListeners();
  }

  @override
  void dispose() {
    _classesSubscription?.cancel();
    super.dispose();
  }
}
