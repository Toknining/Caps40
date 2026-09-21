import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String studentsCollection = 'students';
  static const String rememberMeKey = 'remember_me';

  static String normalizeLoginIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }
    return trimmed.replaceAll(RegExp(r'\s+'), '');
  }

  static Future<UserCredential> loginStudent({
    required String email,
    required String password,
  }) async {
    final normalizedIdentifier = normalizeLoginIdentifier(email);
    final trimmedEmail = normalizedIdentifier.contains('@')
        ? normalizedIdentifier.toLowerCase()
        : normalizedIdentifier;

    if (trimmedEmail.contains('@')) {
      return FirebaseAuth.instance.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
    }

    final students = await FirebaseFirestore.instance
        .collection(studentsCollection)
        .where('studentId', isEqualTo: trimmedEmail)
        .limit(1)
        .get();

    if (students.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No student account found for this ID.',
      );
    }

    final profile = students.docs.first.data();
    final profileEmail = (profile['email'] ?? '').toString().trim().toLowerCase();

    if (profileEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'student-email-missing',
        message: 'This student profile does not have an email address.',
      );
    }

    final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: profileEmail,
      password: password,
    );

    return userCredential;
  }

  static Map<String, dynamic> buildStudentProfile({
    required String firstName,
    required String lastName,
    required String studentId,
    required String email,
  }) {
    final now = DateTime.now();

    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'studentId': studentId.trim(),
      'email': email.trim().toLowerCase(),
      'role': 'student',
      'createdAt': now,
      'updatedAt': now,
    };
  }

  static Future<void> resetPasswordForEmail(String email) async {
    final trimmedEmail = email.trim().toLowerCase();
    await FirebaseAuth.instance.sendPasswordResetEmail(email: trimmedEmail);
  }

  static Future<UserCredential> registerStudent({
    required String firstName,
    required String lastName,
    required String studentId,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: trimmedEmail,
          password: password,
        );

    final uid = userCredential.user?.uid;
    if (uid == null) {
      throw Exception('User account was created without a UID.');
    }

    final studentData = buildStudentProfile(
      firstName: firstName,
      lastName: lastName,
      studentId: studentId,
      email: trimmedEmail,
    );

    await FirebaseFirestore.instance
        .collection(studentsCollection)
        .doc(uid)
        .set(studentData, SetOptions(merge: true));

    await setRememberMe(true);

    return userCredential;
  }

  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(rememberMeKey, value);

    if (!value && Firebase.apps.isNotEmpty) {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        await auth.signOut();
      }
    }
  }

  static Future<bool> shouldAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(rememberMeKey) ?? false;
  }

  static Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(rememberMeKey, false);
  }
}
