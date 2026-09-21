import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../announcements/announcements_screen.dart';
import '../chatbot/chat_screen.dart';
import '../home/home_screen.dart';
import '../navigation/map_screen.dart';
import '../settings/settings_screen.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  late AnimationController _chatbotController;
  late Animation<double> _chatbotAnimation;

  final List<Widget> _screens = const [
    HomeScreen(),
    MapScreen(),
    AnnouncementsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // ============================================================
    // CHATBOT FLOATING ANIMATION
    // ============================================================

    _chatbotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _chatbotAnimation = Tween<double>(begin: 0, end: -7).animate(
      CurvedAnimation(parent: _chatbotController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _chatbotController.dispose();
    super.dispose();
  }

  // ================================================================
  // OPEN CHATBOT
  // ================================================================

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  }

  // ================================================================
  // CHANGE TAB
  // ================================================================

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ============================================================
      // CURRENT SCREEN
      // ============================================================
      body: IndexedStack(index: _currentIndex, children: _screens),

      // ============================================================
      // FLOATING CHATBOT
      // ============================================================
      floatingActionButton: AnimatedBuilder(
        animation: _chatbotAnimation,

        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _chatbotAnimation.value),
            child: child,
          );
        },

        child: GestureDetector(
          onTap: _openChatbot,

          child: Container(
            width: 62,
            height: 62,

            decoration: BoxDecoration(
              color: const Color(0xFF0866E8),

              shape: BoxShape.circle,

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),

                  blurRadius: 12,

                  offset: const Offset(0, 5),
                ),
              ],
            ),

            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 29,
            ),
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // ============================================================
      // CUSTOM ASKUC BOTTOM NAVIGATION
      // ============================================================
      bottomNavigationBar: _AskUCBottomNavigation(
        selectedIndex: _currentIndex,

        onItemSelected: _changeTab,
      ),
    );
  }
}

// ==================================================================
// ASKUC BOTTOM NAVIGATION
// ==================================================================

class _AskUCBottomNavigation extends StatelessWidget {
  final int selectedIndex;

  final ValueChanged<int> onItemSelected;

  const _AskUCBottomNavigation({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,

        border: Border(top: BorderSide(color: Color(0xFFE2E8EC), width: 1)),

        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),

      child: SafeArea(
        top: false,

        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,

            children: [
              // ======================================================
              // HOME
              // ======================================================
              _navItem(
                context,
                index: 0,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Home',
              ),

              // ======================================================
              // MAP
              // ======================================================
              _navItem(
                context,
                index: 1,
                icon: Icons.map_outlined,
                selectedIcon: Icons.map,
                label: 'Map',
              ),

              // ======================================================
              // NOTIFICATIONS
              // ======================================================
              _navItem(
                context,
                index: 2,
                icon: Icons.notifications_outlined,
                selectedIcon: Icons.notifications,
                label: 'Notifications',
              ),

              // ======================================================
              // SETTINGS
              // ======================================================
              _navItem(
                context,
                index: 3,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // NAVIGATION ITEM
  // ================================================================

  Widget _navItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        onItemSelected(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF3FC) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? const Color(0xFF0866E8)
                      : const Color(0xFF8A969E),
                  size: 22,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0866E8)
                        : const Color(0xFF8A969E),
                    fontSize: 8,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            if (index == 2)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  return ValueListenableBuilder<Set<String>>(
                    valueListenable: AnnouncementStore.readIdsNotifier,
                    builder: (context, readIds, _) {
                      final unreadCount = docs
                          .map((doc) => doc.id)
                          .where((id) => !readIds.contains(id))
                          .length;

                      if (unreadCount == 0) {
                        return const SizedBox.shrink();
                      }

                      return Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
