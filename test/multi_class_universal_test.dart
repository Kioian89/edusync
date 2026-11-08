import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edusync/models/user.dart';
import 'package:edusync/models/activity.dart';
import 'package:edusync/providers/auth_provider.dart';
import 'package:edusync/providers/activity_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Universal Multi-Class Student Logic Tests', () {
    test('Student can register without selecting a class and enroll later', () async {
      final auth = AuthProvider();
      await auth.init();

      // Register universal student with no initial class
      final err = await auth.register(
        name: 'Maria Santos',
        email: 'maria.universal@edusync.com',
        password: 'password123',
        role: UserRole.student,
        classId: null,
      );

      expect(err, isNull);
      
      // Sign in as the newly registered student
      await auth.login('maria.universal@edusync.com', 'password123');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser?.role, equals(UserRole.student));
      expect(auth.currentUser?.classId, isNull);
      expect(auth.currentUser?.enrolledClassIds, isEmpty);
      expect(auth.studentClasses, isEmpty);
    });

    test('Student can enroll in multiple classes and query activities across classes', () async {
      final auth = AuthProvider();
      await auth.init();
      auth.seedDemoAccountsForTesting();

      // Sign in as teacher to create two distinct subjects
      await auth.login('teacher@edusync.com', 'teacher123');
      final classMath = await auth.createClass(
        subject: 'Geometry 9',
        section: 'Section Ruby',
      );
      final classScience = await auth.createClass(
        subject: 'Biology 9',
        section: 'Section Ruby',
      );
      expect(classMath, isNotNull);
      expect(classScience, isNotNull);

      // Register new student
      final regErr = await auth.register(
        name: 'Alex Rivera',
        email: 'alex.rivera@edusync.com',
        password: 'password123',
        role: UserRole.student,
        classId: null,
      );
      expect(regErr, isNull);

      // Sign in as the student
      await auth.login('alex.rivera@edusync.com', 'password123');
      expect(auth.isLoggedIn, isTrue);
      final student = auth.currentUser!;
      expect(student.role, equals(UserRole.student));
      expect(student.enrolledClassIds, isEmpty);

      // Student joins Math class
      final err1 = await auth.joinClassByStudent(
        classId: classMath!.id,
        studentId: student.id,
      );
      expect(err1, isNull);

      // Student joins Science class
      final err2 = await auth.joinClassByStudent(
        classId: classScience!.id,
        studentId: student.id,
      );
      expect(err2, isNull);

      // Verify student is enrolled in both
      expect(auth.currentUser?.enrolledClassIds, containsAll([classMath.id, classScience.id]));
      expect(auth.studentClasses.map((c) => c.id), containsAll([classMath.id, classScience.id]));

      // Test ActivityProvider multi-class querying
      final actProvider = ActivityProvider();
      await actProvider.init();

      // Create an activity for Math
      await actProvider.createActivity(
        title: 'Geometric Proofs',
        description: 'Triangle congruence proofs',
        type: ActivityType.assignment,
        deadline: DateTime.now().add(const Duration(days: 3)),
        totalPoints: 50,
        classId: classMath.id,
        teacherId: 'teacher-1',
        studentIds: [student.id],
      );

      // Create an activity for Science
      await actProvider.createActivity(
        title: 'Cell Division Lab',
        description: 'Mitosis vs Meiosis diagram',
        type: ActivityType.project,
        deadline: DateTime.now().add(const Duration(days: 5)),
        totalPoints: 100,
        classId: classScience.id,
        teacherId: 'teacher-1',
        studentIds: [student.id],
      );

      // Query single class
      final mathOnly = actProvider.activitiesForClass(classMath.id);
      expect(mathOnly.any((a) => a.title == 'Geometric Proofs'), isTrue);
      expect(mathOnly.any((a) => a.title == 'Cell Division Lab'), isFalse);

      // Query across all enrolled classes
      final allEnrolledActs = actProvider.activitiesForClasses([classMath.id, classScience.id]);
      expect(allEnrolledActs.any((a) => a.title == 'Geometric Proofs'), isTrue);
      expect(allEnrolledActs.any((a) => a.title == 'Cell Division Lab'), isTrue);

      // Test Announcements multi-class querying
      await actProvider.createAnnouncement(
        classId: classMath.id,
        teacherName: 'Teacher Maria',
        title: 'Math Quiz Friday',
        message: 'Review chapter 4.',
        isPinned: false,
      );
      await actProvider.createAnnouncement(
        classId: classScience.id,
        teacherName: 'Teacher Maria',
        title: 'Bring Lab Materials',
        message: 'Bring microscope slides tomorrow.',
        isPinned: true,
      );

      final allAnnouncements = actProvider.announcementsForClasses([classMath.id, classScience.id]);
      expect(allAnnouncements.length, equals(2));
      // Pinned announcement should appear first
      expect(allAnnouncements.first.isPinned, isTrue);
      expect(allAnnouncements.first.title, equals('Bring Lab Materials'));
    });
  });
}
