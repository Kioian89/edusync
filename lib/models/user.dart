import 'package:flutter/material.dart';

enum UserRole { teacher, student }

class User {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String? classId; // for students

  User({
    required this.id,
    required this.name,
    required this.email,
    this.password = '',
    required this.role,
    this.classId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role.name,
        'classId': classId,
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        password: map['password'] ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => UserRole.student,
        ),
        classId: map['classId'],
      );

  String get roleLabel => role == UserRole.teacher ? 'Teacher' : 'Student';

  Color get roleColor =>
      role == UserRole.teacher ? Colors.indigo : Colors.teal;
}

