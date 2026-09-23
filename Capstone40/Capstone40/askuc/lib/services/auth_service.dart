import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static const String studentsCollection = 'students';

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

    await FirebaseAuth.instance.setPersistence(
      Persistence.NONE,
    );

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
    String? photoUrl,
  }) {
    final now = DateTime.now();

    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'studentId': studentId.trim(),
      'email': email.trim().toLowerCase(),
      'photoUrl': (photoUrl ?? '').trim(),
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

    await FirebaseAuth.instance.setPersistence(Persistence.NONE);

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

    return userCredential;
  }

  static Future<Map<String, String>> getCurrentStudentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'firstName': 'Student',
        'lastName': 'User',
        'studentId': 'N/A',
        'email': 'Not signed in',
        'photoUrl': '',
      };
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(studentsCollection)
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};
      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName = (data['lastName'] ?? '').toString().trim();
      final studentId = (data['studentId'] ?? '').toString().trim();
      final email = (data['email'] ?? user.email ?? '').toString().trim();
      final photoUrl = (data['photoUrl'] ?? '').toString().trim();

      if (doc.exists) {
        return {
          'firstName': firstName.isNotEmpty ? firstName : 'Student',
          'lastName': lastName.isNotEmpty ? lastName : 'User',
          'studentId': studentId.isNotEmpty ? studentId : 'N/A',
          'email': email.isNotEmpty ? email : 'Not available',
          'photoUrl': photoUrl,
        };
      }

      final byEmailQuery = await FirebaseFirestore.instance
          .collection(studentsCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (byEmailQuery.docs.isNotEmpty) {
        final record = byEmailQuery.docs.first.data();
        final matchedFirstName = (record['firstName'] ?? '').toString().trim();
        final matchedLastName = (record['lastName'] ?? '').toString().trim();
        final matchedStudentId = (record['studentId'] ?? '').toString().trim();
        final matchedEmail = (record['email'] ?? email).toString().trim();
        final matchedPhotoUrl = (record['photoUrl'] ?? '').toString().trim();

        return {
          'firstName': matchedFirstName.isNotEmpty ? matchedFirstName : 'Student',
          'lastName': matchedLastName.isNotEmpty ? matchedLastName : 'User',
          'studentId': matchedStudentId.isNotEmpty ? matchedStudentId : 'N/A',
          'email': matchedEmail.isNotEmpty ? matchedEmail : 'Not available',
          'photoUrl': matchedPhotoUrl,
        };
      }

      return {
        'firstName': firstName.isNotEmpty ? firstName : 'Student',
        'lastName': lastName.isNotEmpty ? lastName : 'User',
        'studentId': studentId.isNotEmpty ? studentId : 'N/A',
        'email': email.isNotEmpty ? email : 'Not available',
        'photoUrl': photoUrl,
      };
    } catch (_) {
      return {
        'firstName': 'Student',
        'lastName': 'User',
        'studentId': 'N/A',
        'email': 'Not available',
        'photoUrl': '',
      };
    }
  }

  static Future<void> updateStudentPhotoUrl(String photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'A student must be signed in to update the profile image.',
      );
    }

    await FirebaseFirestore.instance
        .collection(studentsCollection)
        .doc(user.uid)
        .set(
          {
            'photoUrl': photoUrl.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }
}
