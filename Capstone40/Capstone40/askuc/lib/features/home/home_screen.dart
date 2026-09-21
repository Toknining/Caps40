import 'package:flutter/material.dart';

import '../../app/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ============================================================
      // APP BAR
      // ============================================================
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),

        elevation: 0,

        titleSpacing: 16,

        title: const Text(
          'AskUC',

          style: TextStyle(
            color: Color(0xFF20262D),

            fontSize: 20,

            fontWeight: FontWeight.w600,
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,

              color: Color(0xFF20262D),
            ),

            onPressed: () {
              // Notifications are now
              // handled by the bottom
              // navigation.
            },
          ),

          const SizedBox(width: 8),
        ],
      ),

      // ============================================================
      // HOME CONTENT
      // ============================================================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 100),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                'Hello, Student 👋',

                style: TextStyle(
                  color: Color(0xFF20262D),

                  fontSize: 20,

                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 3),

              const Text(
                'Welcome back to AskUC',

                style: TextStyle(color: Color(0xFF8A969E), fontSize: 10),
              ),

              const SizedBox(height: 18),

              // ====================================================
              // ASKUC CARD
              // ====================================================
              _needHelpCard(context),

              const SizedBox(height: 22),

              // ====================================================
              // QUICK ACTIONS
              // ====================================================
              const Text(
                'Quick Actions',

                style: TextStyle(
                  color: Color(0xFF20262D),

                  fontSize: 15,

                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _quickActionCard(
                      context,

                      icon: Icons.chat_bubble,

                      title: 'AI Assistant',

                      subtitle: 'Ask a question',

                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.chat);
                      },
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _quickActionCard(
                      context,

                      icon: Icons.map,

                      title: 'Campus Map',

                      subtitle: 'Find a location',

                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.map);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _quickActionCard(
                      context,

                      icon: Icons.help,

                      title: 'FAQs',

                      subtitle: 'Common questions',

                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.chat);
                      },
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _quickActionCard(
                      context,

                      icon: Icons.campaign,

                      title: 'Announcements',

                      subtitle: 'Latest updates',

                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.announcements);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ====================================================
              // ANNOUNCEMENTS
              // ====================================================
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Latest Announcement',

                      style: TextStyle(
                        color: Color(0xFF20262D),

                        fontSize: 15,

                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      // The notification page
                      // is now a bottom tab.
                    },

                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,

                      minimumSize: Size.zero,

                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),

                    child: const Text(
                      'See All',

                      style: TextStyle(
                        color: Color(0xFF0866E8),

                        fontSize: 10,

                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              _latestAnnouncement(),
            ],
          ),
        ),
      ),

      // ============================================================
      // FLOATING CHATBOT
      // ============================================================
      floatingActionButton: const _FloatingChatbot(),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ================================================================
  // NEED HELP CARD
  // ================================================================

  Widget _needHelpCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.chat);
      },

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: const Color(0xFF0866E8),

          borderRadius: BorderRadius.circular(18),
        ),

        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,

              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),

                borderRadius: BorderRadius.circular(13),
              ),

              child: const Icon(
                Icons.auto_awesome,

                color: Colors.white,

                size: 25,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Need Help?',

                    style: TextStyle(
                      color: Colors.white,

                      fontSize: 13,

                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: 3),

                  Text(
                    'Ask AskUC about campus information.',

                    style: TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(9),
              ),

              child: const Text(
                'Ask',

                style: TextStyle(
                  color: Color(0xFF0866E8),

                  fontSize: 10,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // QUICK ACTION
  // ================================================================

  Widget _quickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(14),

      child: Container(
        height: 111,

        padding: const EdgeInsets.all(13),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(14),

          border: Border.all(color: const Color(0xFFDDE7EC)),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Container(
              width: 39,
              height: 39,

              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FC),

                borderRadius: BorderRadius.circular(10),
              ),

              child: Icon(icon, color: const Color(0xFF0866E8), size: 20),
            ),

            const Spacer(),

            Text(
              title,

              style: const TextStyle(
                color: Color(0xFF20262D),

                fontSize: 11,

                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              subtitle,

              style: const TextStyle(color: Color(0xFF8A969E), fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // ANNOUNCEMENT
  // ================================================================

  Widget _latestAnnouncement() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(15),

        border: Border.all(color: const Color(0xFFDDE7EC)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 40,
            height: 40,

            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FC),

              borderRadius: BorderRadius.circular(11),
            ),

            child: const Icon(
              Icons.campaign,

              color: Color(0xFF0866E8),

              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Welcome to AskUC',

                  style: TextStyle(
                    color: Color(0xFF20262D),

                    fontSize: 12,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Your smart campus assistant is ready to help you with university information and navigation.',

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: Color(0xFF8A969E),

                    fontSize: 9,

                    height: 1.4,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Today',

                  style: TextStyle(color: Color(0xFF9AA5AC), fontSize: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// FLOATING CHATBOT
// ==================================================================

class _FloatingChatbot extends StatefulWidget {
  const _FloatingChatbot();

  @override
  State<_FloatingChatbot> createState() => _FloatingChatbotState();
}

class _FloatingChatbotState extends State<_FloatingChatbot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: 0,
      end: -7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,

      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),

          child: child,
        );
      },

      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.chat);
        },

        child: Container(
          width: 62,
          height: 62,

          decoration: BoxDecoration(
            color: const Color(0xFF0866E8),

            shape: BoxShape.circle,

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),

                blurRadius: 12,

                offset: const Offset(0, 5),
              ),
            ],
          ),

          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 29),
        ),
      ),
    );
  }
}
