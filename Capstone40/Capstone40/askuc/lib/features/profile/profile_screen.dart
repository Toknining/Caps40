import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'profile_image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, String>> _loadProfileForUser(User? user) async {
    if (user == null) {
      return await AuthService.getCurrentStudentProfile();
    }

    return await AuthService.getCurrentStudentProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF20262D)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF20262D),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;

          return FutureBuilder<Map<String, String>>(
            future: _loadProfileForUser(user),
            builder: (context, snapshot) {
              final profile = snapshot.data ?? {
                'firstName': 'Student',
                'lastName': 'User',
                'studentId': 'N/A',
                'email': 'Loading...',
              };

              final fullName = '${profile['firstName'] ?? 'Student'} ${profile['lastName'] ?? 'User'}'.trim();
              final photoUrl = profile['photoUrl'] ?? '';

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
                child: Column(
                  children: [
                    // =====================================================
                    // PROFILE HEADER
                    // =====================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFDDE7EC)),
                      ),
                      child: Column(
                        children: [
                          ProfileImagePicker(
                            photoUrl: photoUrl,
                            onUpdated: () {
                              setState(() {});
                            },
                          ),

                          const SizedBox(height: 12),

                          Text(
                            fullName.isNotEmpty ? fullName : 'Student User',
                            style: const TextStyle(
                              color: Color(0xFF20262D),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Student ID: ${profile['studentId'] ?? 'N/A'}',
                            style: const TextStyle(color: Color(0xFF8A969E), fontSize: 10),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // =====================================================
                    // INFORMATION
                    // =====================================================
                    _profileItem(
                      icon: Icons.person_outline,
                      title: 'Student Name',
                      value: fullName.isNotEmpty ? fullName : 'Student User',
                    ),

                    const SizedBox(height: 10),

                    _profileItem(
                      icon: Icons.badge_outlined,
                      title: 'Student ID',
                      value: profile['studentId'] ?? 'N/A',
                    ),

                    const SizedBox(height: 10),

                    _profileItem(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      value: profile['email'] ?? 'Not available',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _profileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE7EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF0866E8), size: 20),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Color(0xFF8A969E), fontSize: 9),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF20262D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
