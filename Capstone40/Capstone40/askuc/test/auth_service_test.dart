import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:askuc/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    test('buildStudentProfile returns the expected Firestore document', () {
      final profile = AuthService.buildStudentProfile(
        firstName: 'Jane',
        lastName: 'Doe',
        studentId: '20240123',
        email: 'jane.doe@school.edu',
      );

      expect(profile['firstName'], 'Jane');
      expect(profile['lastName'], 'Doe');
      expect(profile['studentId'], '20240123');
      expect(profile['email'], 'jane.doe@school.edu');
      expect(profile['role'], 'student');
      expect(profile['createdAt'], isA<DateTime>());
      expect(profile['updatedAt'], isA<DateTime>());
    });

    test('student profile keeps a valid email and student ID', () {
      final profile = AuthService.buildStudentProfile(
        firstName: 'Jane',
        lastName: 'Doe',
        studentId: '20240123',
        email: 'jane.doe@school.edu',
      );

      expect(profile['email'], 'jane.doe@school.edu');
      expect(profile['studentId'], '20240123');
    });

    test('remember me persists and clears correctly', () async {
      SharedPreferences.setMockInitialValues({});

      await AuthService.setRememberMe(true);
      expect(await AuthService.shouldAutoLogin(), isTrue);

      await AuthService.setRememberMe(false);
      expect(await AuthService.shouldAutoLogin(), isFalse);
    });
  });
}
