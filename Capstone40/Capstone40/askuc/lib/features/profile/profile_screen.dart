import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

      body: SingleChildScrollView(
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
                  Container(
                    width: 75,
                    height: 75,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF3FC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF0866E8),
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Student Name',
                    style: TextStyle(
                      color: Color(0xFF20262D),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Student ID: 12345',
                    style: TextStyle(color: Color(0xFF8A969E), fontSize: 10),
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
              value: 'Student Name',
            ),

            const SizedBox(height: 10),

            _profileItem(
              icon: Icons.badge_outlined,
              title: 'Student ID',
              value: '12345',
            ),

            const SizedBox(height: 10),

            _profileItem(
              icon: Icons.email_outlined,
              title: 'Email',
              value: 'student@example.com',
            ),
          ],
        ),
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
