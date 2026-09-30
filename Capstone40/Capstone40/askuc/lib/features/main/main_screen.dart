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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;

  late AnimationController _chatbotController;
  late Animation<double> _chatbotAnimation;

  late AnimationController _chatWindowController;
  late Animation<double> _chatWindowScale;
  late Animation<double> _chatWindowFade;
  bool _isChatOpen = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      const HomeScreen(),
      const MapScreen(),
      AnnouncementsScreen(onExit: () => _changeTab(0)),
      const SettingsScreen(),
    ];

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

    // ============================================================
    // CHAT WINDOW POP-UP ANIMATION
    // ============================================================

    _chatWindowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _chatWindowScale = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(
        parent: _chatWindowController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _chatWindowFade = CurvedAnimation(
      parent: _chatWindowController,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _chatbotController.dispose();
    _chatWindowController.dispose();
    super.dispose();
  }

  // ================================================================
  // OPEN / CLOSE CHATBOT
  // ================================================================

  void _openChatbot() {
    setState(() {
      _isChatOpen = true;
    });
    _chatWindowController.forward();
  }

  void _closeChatbot() {
    if (!_isChatOpen) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isChatOpen = false;
    });
    _chatWindowController.reverse();
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
    return PopScope(
      canPop: !_isChatOpen,

      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeChatbot();
        }
      },

      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),

        // ============================================================
        // CURRENT SCREEN + FLOATING CHAT WINDOW
        // ============================================================
        body: Stack(
          fit: StackFit.expand,

          children: [
            IndexedStack(index: _currentIndex, children: _screens),

            Positioned.fill(child: _chatBarrier()),

            // The chatbot button is hidden while the chat is open, so the
            // window drops down into its spot above the bottom navigation.
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.paddingOf(context).top + 12,
              bottom: 12,

              child: _chatWindow(),
            ),
          ],
        ),

        // ============================================================
        // FLOATING CHATBOT
        // ============================================================
        floatingActionButton: _isChatOpen ? null : _chatbotButton(),

        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        // ============================================================
        // CUSTOM ASKUC BOTTOM NAVIGATION
        // ============================================================
        bottomNavigationBar: Stack(
          children: [
            _AskUCBottomNavigation(
              selectedIndex: _currentIndex,

              onItemSelected: _changeTab,
            ),

            Positioned.fill(child: _chatBarrier()),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // CHATBOT BUTTON
  // ================================================================

  Widget _chatbotButton() {
    return AnimatedBuilder(
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
    );
  }

  // ================================================================
  // CHAT WINDOW
  // ================================================================

  // Dims the app behind the chat window; tapping it closes the chat.
  Widget _chatBarrier() {
    return AnimatedBuilder(
      animation: _chatWindowController,

      builder: (context, _) {
        if (_chatWindowController.isDismissed) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,

          onTap: _closeChatbot,

          child: ColoredBox(
            color: Colors.black.withValues(
              alpha: 0.25 * _chatWindowFade.value,
            ),
          ),
        );
      },
    );
  }

  // Grows out of the chatbot button. It stays mounted (just hidden) after
  // closing so the conversation is still there when it is opened again.
  Widget _chatWindow() {
    return Align(
      alignment: Alignment.bottomRight,

      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),

        child: AnimatedBuilder(
          animation: _chatWindowController,

          builder: (context, child) {
            return Visibility(
              visible: !_chatWindowController.isDismissed,
              maintainState: true,
              child: child!,
            );
          },

          child: FadeTransition(
            opacity: _chatWindowFade,

            child: ScaleTransition(
              scale: _chatWindowScale,

              alignment: Alignment.bottomRight,

              child: SizedBox.expand(
                child: ChatScreen.floating(onClose: _closeChatbot),
              ),
            ),
          ),
        ),
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
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8EC), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              context,
              index: 0,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
            ),
            _navItem(
              context,
              index: 1,
              icon: Icons.map_outlined,
              selectedIcon: Icons.map,
              label: 'Map',
            ),
            _navItem(
              context,
              index: 2,
              icon: Icons.notifications_outlined,
              selectedIcon: Icons.notifications,
              label: 'Notifications',
            ),
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
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF3FC) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFD7E8FF) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? const Color(0xFF0866E8)
                      : const Color(0xFF8A969E),
                  size: 21,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0866E8)
                        : const Color(0xFF8A969E),
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.1,
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
