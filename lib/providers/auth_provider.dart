import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/user.dart';
import '../models/class_group.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_sync_service.dart';

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

  List<ClassGroup> get teacherClasses => _classes
      .where((c) => c.teacherId == _currentUser?.id)
      .toList();

  List<User> studentsInClass(String classId) {
    final cls = _classes.firstWhere((c) => c.id == classId,
        orElse: () => ClassGroup(
            id: '', name: '', subject: '', section: '', teacherId: '', studentIds: []));
    return _users.where((u) => cls.studentIds.contains(u.id)).toList();
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
            (c) => c.id == classId && c.studentIds.contains(_currentUser!.id));
      } catch (_) {}
    }
    try {
      return _classes
          .firstWhere((c) => c.studentIds.contains(_currentUser!.id));
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
          role: UserRole.teacher),
      User(
          id: studentId1,
          name: 'Juan dela Cruz',
          email: 'juan@edusync.com',
          password: 'student123',
          role: UserRole.student,
          classId: classId),
      User(
          id: studentId2,
          name: 'Maria Reyes',
          email: 'maria@edusync.com',
          password: 'student123',
          role: UserRole.student,
          classId: classId),
      User(
          id: studentId3,
          name: 'Pedro Garcia',
          email: 'pedro@edusync.com',
          password: 'student123',
          role: UserRole.student,
          classId: classId),
    ];

    _classes = [
      ClassGroup(
          id: classId,
          name: 'Grade 10 - Science',
          subject: 'Science',
          section: 'Section A',
          teacherId: teacherId,
          studentIds: [studentId1, studentId2, studentId3]),
    ];
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('users');
    final classesJson = prefs.getString('classes');
    final currentUserId = prefs.getString('currentUserId');

    if (usersJson != null) {
      final list = jsonDecode(usersJson) as List;
      _users = list.map((m) => User.fromMap(Map<String, dynamic>.from(m))).toList();
    }
    if (classesJson != null) {
      final list = jsonDecode(classesJson) as List;
      _classes = list.map((m) => ClassGroup.fromMap(Map<String, dynamic>.from(m))).toList();
    }
    if (currentUserId != null) {
      try {
        _currentUser = _users.firstWhere((u) => u.id == currentUserId);
        startListeningToClasses();
      } catch (_) {}
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users', jsonEncode(_users.map((u) => u.toMap()).toList()));
    await prefs.setString('classes', jsonEncode(_classes.map((c) => c.toMap()).toList()));
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
          User? matchedUser;

          try {
            matchedUser = _users.firstWhere(
              (u) =>
                  u.id == fbUser.uid ||
                  u.email.toLowerCase() == cleanEmail.toLowerCase(),
            );
          } catch (_) {
            matchedUser = null;
          }

          if (matchedUser == null) {
            // Check Firestore for remote profile
            final profile =
                await FirebaseAuthService.getUserProfile(fbUser.uid);
            if (profile != null) {
              matchedUser = User(
                id: fbUser.uid,
                name: profile['name'] ?? fbUser.displayName ?? 'EduSync User',
                email: fbUser.email ?? cleanEmail,
                role: UserRole.values.firstWhere(
                  (r) => r.name == profile['role'],
                  orElse: () => UserRole.student,
                ),
                classId: profile['classId'],
                enrolledClassIds: profile['enrolledClassIds'] != null
                    ? List<String>.from(profile['enrolledClassIds'])
                    : (profile['classId'] != null ? [profile['classId']] : []),
              );
            } else {
              matchedUser = User(
                id: fbUser.uid,
                name: fbUser.displayName ??
                    (cleanEmail.split('@').first),
                email: fbUser.email ?? cleanEmail,
                role: UserRole.student,
              );
            }
            _users.add(matchedUser);
            await _saveData();
          }

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
          final demoUser = _users.firstWhere((u) =>
              u.email.toLowerCase() == cleanEmail.toLowerCase() &&
              u.password == cleanPass);
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
      final user = _users.firstWhere((u) =>
          u.email.toLowerCase() == cleanEmail.toLowerCase() &&
          u.password == cleanPass);
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

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? classId,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = name.trim();

    final exists =
        _users.any((u) => u.email.toLowerCase() == cleanEmail.toLowerCase());
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
        );
      }
    }

    await _saveData();
    notifyListeners();
    return null;
  }

  Future<ClassGroup?> createClass({
    required String subject,
    required String section,
  }) async {
    if (_currentUser == null) return null;
    final cls = ClassGroup(
      id: _uuid.v4(),
      name: '$subject - $section',
      subject: subject,
      section: section,
      teacherId: _currentUser!.id,
      studentIds: [],
    );
    _classes.add(cls);
    await _saveData();
    if (FirestoreSyncService.isAvailable) {
      await FirestoreSyncService.saveClass(cls);
    }
    notifyListeners();
    return cls;
  }

  /// Update/Edit an existing class group
  Future<ClassGroup?> updateClass({
    required String classId,
    required String subject,
    required String section,
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
    );

    _classes[idx] = updated;
    await _saveData();
    if (FirestoreSyncService.isAvailable) {
      await FirestoreSyncService.saveClass(updated);
    }
    notifyListeners();
    return updated;
  }

  /// Delete a class group
  Future<bool> deleteClass(String classId) async {
    final idx = _classes.indexWhere((c) => c.id == classId);
    if (idx == -1) return false;

    _classes.removeAt(idx);
    await _saveData();
    if (FirestoreSyncService.isAvailable) {
      await FirestoreSyncService.deleteClass(classId);
    }
    notifyListeners();
    return true;
  }

  /// Look up class by ID locally or from Firestore
  Future<ClassGroup?> fetchClassById(String classId) async {
    final localIdx = _classes.indexWhere((c) => c.id == classId);
    if (localIdx != -1) return _classes[localIdx];

    if (FirestoreSyncService.isAvailable) {
      final remote = await FirestoreSyncService.getClassById(classId);
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
    if (classIdx == -1) {
      // Try to fetch remote class if not loaded yet
      if (FirestoreSyncService.isAvailable) {
        final remote = await FirestoreSyncService.getClassById(classId);
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
          enrolledClassIds: List<String>.from(profile['enrolledClassIds'] ?? [classId]),
        );
        _users.add(student);
        studentIdx = _users.length - 1;
      }
    }

    if (student == null) {
      return 'Student account not found.';
    }

    if (student.role != UserRole.student) {
      return 'User is not a student.';
    }

    final cls = _classes[classIdx];
    if (cls.studentIds.contains(studentId)) {
      return 'You are already enrolled in ${cls.displayName}.';
    }

    _classes[classIdx] = ClassGroup(
      id: cls.id,
      name: cls.name,
      subject: cls.subject,
      section: cls.section,
      teacherId: cls.teacherId,
      studentIds: [...cls.studentIds, studentId],
    );

    // Update student's primary classId and list of all enrolled classes
    final updatedEnrolled = {...student.enrolledClassIds, classId}.toList();
    final updatedStudent = User(
      id: student.id,
      name: student.name,
      email: student.email,
      password: student.password,
      role: student.role,
      classId: classId,
      enrolledClassIds: updatedEnrolled,
    );
    _users[studentIdx] = updatedStudent;

    if (_currentUser != null && _currentUser!.id == studentId) {
      _currentUser = updatedStudent;
    }

    await _saveData();
    if (FirestoreSyncService.isAvailable) {
      await FirestoreSyncService.addStudentToClass(
        classId: classId,
        studentId: studentId,
      );
    }
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

  /// Register or update a class discovered via QR code or remote stream.
  void registerLocalClass(ClassGroup cls) {
    final idx = _classes.indexWhere((c) => c.id == cls.id);
    if (idx != -1) {
      _classes[idx] = cls;
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

    _classesSubscription = stream.listen((remoteClasses) {
      if (remoteClasses.isNotEmpty) {
        bool changed = false;
        for (final remote in remoteClasses) {
          final idx = _classes.indexWhere((c) => c.id == remote.id);
          if (idx != -1) {
            _classes[idx] = remote;
            changed = true;
          } else {
            _classes.add(remote);
            changed = true;
          }
        }
        if (changed) {
          _saveData();
          notifyListeners();
        }
      }
    }, onError: (e) {
      debugPrint('Firestore classes stream error: $e');
    });
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

