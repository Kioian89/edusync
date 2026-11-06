import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/class_group.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  List<User> _users = [];
  List<ClassGroup> _classes = [];
  final _uuid = const Uuid();

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

  ClassGroup? studentClass() {
    if (_currentUser == null) return null;
    try {
      return _classes
          .firstWhere((c) => c.studentIds.contains(_currentUser!.id));
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    await _loadData();
    if (_users.isEmpty) {
      _seedDemoData();
      await _saveData();
    }
  }

  void _seedDemoData() {
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
      } catch (_) {}
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users', jsonEncode(_users.map((u) => u.toMap()).toList()));
    await prefs.setString('classes', jsonEncode(_classes.map((c) => c.toMap()).toList()));
  }

  Future<String?> login(String email, String password) async {
    try {
      final user = _users.firstWhere(
          (u) => u.email.toLowerCase() == email.toLowerCase() && u.password == password);
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', user.id);
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
    final exists = _users.any((u) => u.email.toLowerCase() == email.toLowerCase());
    if (exists) return 'An account with this email already exists.';

    final newUser = User(
      id: _uuid.v4(),
      name: name,
      email: email,
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

  Future<void> createClass({
    required String subject,
    required String section,
  }) async {
    if (_currentUser == null) return;
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
    notifyListeners();
  }

  /// Add student to a class by their student ID.
  /// Returns null on success, or an error message if student not found or already enrolled.
  Future<String?> addStudentToClass({
    required String classId,
    required String studentId,
  }) async {
    final classIdx = _classes.indexWhere((c) => c.id == classId);
    if (classIdx == -1) return 'Class not found.';

    final studentIdx = _users.indexWhere((u) => u.id == studentId);
    if (studentIdx == -1) return 'Student not found.';

    final student = _users[studentIdx];
    if (student.role != UserRole.student) {
      return 'Scanned user is not a student.';
    }

    final cls = _classes[classIdx];
    if (cls.studentIds.contains(studentId)) {
      return '${student.name} is already enrolled in this class.';
    }

    _classes[classIdx] = ClassGroup(
      id: cls.id,
      name: cls.name,
      subject: cls.subject,
      section: cls.section,
      teacherId: cls.teacherId,
      studentIds: [...cls.studentIds, studentId],
    );

    // Update student's classId
    _users[studentIdx] = User(
      id: student.id,
      name: student.name,
      email: student.email,
      password: student.password,
      role: student.role,
      classId: classId,
    );

    await _saveData();
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

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUserId');
    notifyListeners();
  }
}

