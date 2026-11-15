import 'package:flutter/material.dart';

enum UserRole { teacher, student }

class User {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String? classId; // primary or active class
  final List<String>
  enrolledClassIds; // all enrolled classes for universal student logic
  final String? photoUrl; // profile photo URL (network URL or base64 data URI)
  final String? studentId;
  final DateTime? birthday;
  final String? course;
  final String? yearLevel;
  final String? section;
  final String? employeeId;
  final String? department;
  final List<String> coursesTaught;
  final bool profileComplete;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.password = '',
    required this.role,
    this.classId,
    List<String>? enrolledClassIds,
    this.photoUrl,
    this.studentId,
    this.birthday,
    this.course,
    this.yearLevel,
    this.section,
    this.employeeId,
    this.department,
    List<String>? coursesTaught,
    this.profileComplete = false,
  }) : enrolledClassIds =
           enrolledClassIds ?? (classId != null ? [classId] : []),
       coursesTaught = coursesTaught ?? [];

  int? get age {
    final date = birthday;
    if (date == null) return null;
    final now = DateTime.now();
    var years = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      years--;
    }
    return years;
  }

  bool get hasCompleteProfile {
    if (!profileComplete) return false;
    if (role == UserRole.student) {
      return _hasText(studentId) &&
          birthday != null &&
          _hasText(course) &&
          _hasText(yearLevel) &&
          _hasText(section);
    }
    return _hasText(employeeId) &&
        _hasText(department) &&
        coursesTaught.isNotEmpty;
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'password': password,
    'role': role.name,
    'classId': classId,
    'enrolledClassIds': enrolledClassIds,
    'photoUrl': photoUrl,
    'studentId': studentId,
    'birthday': birthday?.toIso8601String(),
    'course': course,
    'yearLevel': yearLevel,
    'section': section,
    'employeeId': employeeId,
    'department': department,
    'coursesTaught': coursesTaught,
    'profileComplete': profileComplete,
  };

  factory User.fromMap(Map<String, dynamic> map) {
    final primaryClassId = map['classId'] as String?;
    final list = map['enrolledClassIds'];
    final enrolled = list != null
        ? List<String>.from(list)
        : (primaryClassId != null ? [primaryClassId] : <String>[]);
    final birthdayValue = map['birthday'];
    final birthday = birthdayValue == null
        ? null
        : DateTime.tryParse(birthdayValue.toString());
    final courses = map['coursesTaught'];

    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.student,
      ),
      classId: primaryClassId,
      enrolledClassIds: enrolled,
      photoUrl: map['photoUrl'] as String?,
      studentId: map['studentId']?.toString(),
      birthday: birthday,
      course: map['course']?.toString(),
      yearLevel: map['yearLevel']?.toString(),
      section: map['section']?.toString(),
      employeeId: map['employeeId']?.toString(),
      department: map['department']?.toString(),
      coursesTaught: courses is List
          ? courses.map((course) => course.toString()).toList()
          : const [],
      profileComplete: map['profileComplete'] == true,
    );
  }

  /// Returns a copy of this [User] with the given fields replaced.
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    String? classId,
    List<String>? enrolledClassIds,
    String? photoUrl,
    String? studentId,
    DateTime? birthday,
    String? course,
    String? yearLevel,
    String? section,
    String? employeeId,
    String? department,
    List<String>? coursesTaught,
    bool? profileComplete,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      classId: classId ?? this.classId,
      enrolledClassIds:
          enrolledClassIds ?? List<String>.from(this.enrolledClassIds),
      photoUrl: photoUrl ?? this.photoUrl,
      studentId: studentId ?? this.studentId,
      birthday: birthday ?? this.birthday,
      course: course ?? this.course,
      yearLevel: yearLevel ?? this.yearLevel,
      section: section ?? this.section,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      coursesTaught: coursesTaught ?? List<String>.from(this.coursesTaught),
      profileComplete: profileComplete ?? this.profileComplete,
    );
  }

  String get roleLabel => role == UserRole.teacher ? 'Teacher' : 'Student';

  Color get roleColor => role == UserRole.teacher ? Colors.indigo : Colors.teal;
}
