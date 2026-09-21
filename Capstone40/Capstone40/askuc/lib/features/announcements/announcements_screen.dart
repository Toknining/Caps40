import 'package:flutter/material.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Welcome to AskUC',
      'message': 'Your smart campus assistant is ready to help you.',
      'time': 'Today',
      'icon': Icons.campaign,
      'unread': true,
    },
    {
      'title': 'Campus Information',
      'message': 'Check AskUC for campus locations and university information.',
      'time': 'Yesterday',
      'icon': Icons.info,
      'unread': false,
    },
  ];

  void _markAllAsRead() {
    setState(() {
      for (final notification in _notifications) {
        notification['unread'] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ======================================================
            // HEADER
            // ======================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: const [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            color: Color(0xFF20262D),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        SizedBox(height: 3),

                        Text(
                          'Stay updated with campus announcements',
                          style: TextStyle(
                            color: Color(0xFF8A969E),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ------------------------------------------------
                  // MARK ALL
                  // ------------------------------------------------
                  TextButton(
                    onPressed: _markAllAsRead,

                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(top: 3, left: 8, right: 0),

                      minimumSize: Size.zero,

                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),

                    child: const Text(
                      'Mark all',
                      style: TextStyle(
                        color: Color(0xFF0866E8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ======================================================
            // DIVIDER
            // ======================================================
            const Divider(height: 1, color: Color(0xFFE5EBEF)),

            const SizedBox(height: 17),

            // ======================================================
            // NOTIFICATION LIST
            // ======================================================
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),

                itemCount: _notifications.length,

                separatorBuilder: (context, index) {
                  return const SizedBox(height: 10);
                },

                itemBuilder: (context, index) {
                  final notification = _notifications[index];

                  return _notificationCard(
                    context,
                    title: notification['title'],
                    message: notification['message'],
                    time: notification['time'],
                    icon: notification['icon'],
                    unread: notification['unread'],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // NOTIFICATION CARD
  // ================================================================

  Widget _notificationCard(
    BuildContext context, {
    required String title,
    required String message,
    required String time,
    required IconData icon,
    required bool unread,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),

      onTap: () {
        // Later we can open the full announcement here.
      },

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(13),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(15),

          border: Border.all(color: const Color(0xFFDDE7EC), width: 1),
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ------------------------------------------------------
            // ICON
            // ------------------------------------------------------
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

            // ------------------------------------------------------
            // CONTENT
            // ------------------------------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,

                          style: const TextStyle(
                            color: Color(0xFF20262D),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // --------------------------------------------
                      // UNREAD DOT
                      // --------------------------------------------
                      if (unread)
                        Container(
                          width: 7,
                          height: 7,

                          decoration: const BoxDecoration(
                            color: Color(0xFF0866E8),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    message,

                    maxLines: 2,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      color: Color(0xFF8A969E),
                      fontSize: 9,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    time,

                    style: const TextStyle(
                      color: Color(0xFF9AA5AC),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
