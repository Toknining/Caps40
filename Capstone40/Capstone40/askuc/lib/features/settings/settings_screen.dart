import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../profile/profile_screen.dart';
import '../auth/change_password_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ================================================================
  // LOGOUT DIALOG
  // ================================================================

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.logout_outlined,
                    color: Color(0xFFE53935),
                    size: 25,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Log Out',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF20262D),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Are you sure you want to log out of your AskUC account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8A969E),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF34454F),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFDDE7EC)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);

                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.login,
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0866E8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ====================================================
              // HEADER
              // ====================================================
              const Text(
                'Settings',
                style: TextStyle(
                  color: Color(0xFF20262D),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Manage your AskUC account and preferences',
                style: TextStyle(color: Color(0xFF8A969E), fontSize: 10),
              ),

              const SizedBox(height: 20),

              // ====================================================
              // STUDENT ACCOUNT
              // ====================================================
              _accountCard(),

              const SizedBox(height: 20),

              // ====================================================
              // ACCOUNT
              // ====================================================
              const Text(
                'Account',
                style: TextStyle(
                  color: Color(0xFF20262D),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              // ====================================================
              // PROFILE
              // ====================================================
              _settingsCard(
                icon: Icons.person_outline,
                title: 'Profile',
                subtitle: 'View and update your profile',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // ====================================================
              // PASSWORD
              // ====================================================
              _settingsCard(
                icon: Icons.lock_outline,
                title: 'Password',
                subtitle: 'Change your account password',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ====================================================
              // PREFERENCES
              // ====================================================
              const Text(
                'Preferences',
                style: TextStyle(
                  color: Color(0xFF20262D),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              // ====================================================
              // NOTIFICATIONS
              // ====================================================
              _settingsCard(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.announcements);
                },
              ),

              const SizedBox(height: 10),

              // ====================================================
              // ABOUT
              // ====================================================
              _settingsCard(
                icon: Icons.info_outline,
                title: 'About AskUC',
                subtitle: 'Learn more about the application',
                onTap: () {
                  _showAboutDialog(context);
                },
              ),

              const SizedBox(height: 24),

              // ====================================================
              // LOG OUT
              // ====================================================
              _logoutCard(context),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // STUDENT ACCOUNT CARD
  // ================================================================

  Widget _accountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFDDE7EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FC),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF0866E8), size: 27),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Name',
                  style: TextStyle(
                    color: Color(0xFF20262D),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Student ID: 12345',
                  style: TextStyle(color: Color(0xFF8A969E), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // SETTINGS CARD
  // ================================================================

  Widget _settingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                    style: const TextStyle(
                      color: Color(0xFF20262D),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8A969E),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Color(0xFF8A969E), size: 20),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // LOGOUT CARD
  // ================================================================

  Widget _logoutCard(BuildContext context) {
    return InkWell(
      onTap: () {
        _showLogoutDialog(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE7EC)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_outlined,
                color: Color(0xFFE53935),
                size: 19,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log Out',
                    style: TextStyle(
                      color: Color(0xFF20262D),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: 2),

                  Text(
                    'Sign out of your AskUC account',
                    style: TextStyle(color: Color(0xFF8A969E), fontSize: 9),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Color(0xFF8A969E), size: 19),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // ABOUT DIALOG
  // ================================================================

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'About AskUC',
            style: TextStyle(
              color: Color(0xFF20262D),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            'AskUC is a smart campus assistant designed '
            'to help students access university information, '
            'announcements, and campus navigation.',
            style: TextStyle(
              color: Color(0xFF8A969E),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF0866E8), fontSize: 11),
              ),
            ),
          ],
        );
      },
    );
  }
}
