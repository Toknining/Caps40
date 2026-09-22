import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text:
          "Hello, Student! 👋\n\n"
          "I'm AskUC Assistant. "
          "How can I help you today?",
      isUser: false,
      time: '',
    ),
  ];

  double _dragDistance = 0;

  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ================================================================
  // SEND MESSAGE
  // ================================================================

  void _sendMessage() {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(text: message, isUser: true, time: _currentTime()),
      );

      _messageController.clear();

      _isTyping = true;
    });

    unawaited(_recordChatbotQuery());

    _scrollToBottom();

    // --------------------------------------------------------------
    // TEMPORARY RESPONSE
    // --------------------------------------------------------------

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _isTyping = false;

        _messages.add(
          _ChatMessage(
            text: _getDemoResponse(message),
            isUser: false,
            time: _currentTime(),
          ),
        );
      });

      _scrollToBottom();
    });
  }

  Future<void> _recordChatbotQuery() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('chatbotQueries').add({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Failed to record chatbot query: $error');
    }
  }

  // ================================================================
  // DEMO AI RESPONSE
  // ================================================================

  String _getDemoResponse(String question) {
    final text = question.toLowerCase();

    if (text.contains('library')) {
      return 'The library is located near the '
          'Main Building. You can find it on '
          'the ground floor, facing the central '
          'courtyard.';
    }

    if (text.contains('hours') || text.contains('open')) {
      return 'The library is open from:\n\n'
          'Monday – Friday: 7:30 AM – 9:00 PM\n'
          'Saturday: 8:00 AM – 5:00 PM';
    }

    if (text.contains('office')) {
      return 'You can contact the appropriate '
          'university office for assistance. '
          'AskUC can also help you find the '
          'information you need.';
    }

    if (text.contains('announcement')) {
      return 'You can check the Notifications '
          'section to view the latest campus '
          'announcements.';
    }

    if (text.contains('faq')) {
      return 'AskUC can help answer common '
          'questions about campus services, '
          'locations, offices, and university '
          'information.';
    }

    return 'I can help you with campus '
        'information, locations, announcements, '
        'and frequently asked questions. '
        'What would you like to know?';
  }

  // ================================================================
  // QUICK QUESTION
  // ================================================================

  void _sendQuickQuestion(String question) {
    _messageController.text = question;

    _sendMessage();
  }

  // ================================================================
  // CURRENT TIME
  // ================================================================

  String _currentTime() {
    final now = DateTime.now();

    final hour = now.hour > 12
        ? now.hour - 12
        : now.hour == 0
        ? 12
        : now.hour;

    final minute = now.minute.toString().padLeft(2, '0');

    final period = now.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  // ================================================================
  // SCROLL
  // ================================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,

        duration: const Duration(milliseconds: 300),

        curve: Curves.easeOut,
      );
    });
  }

  // ================================================================
  // SWIPE DOWN
  // ================================================================

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0) {
      _dragDistance += details.delta.dy;
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragDistance > 120) {
      Navigator.pop(context);
    }

    _dragDistance = 0;
  }

  // ================================================================
  // EXIT CHAT
  // ================================================================

  void _exitChat() {
    Navigator.pop(context);
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,

          onVerticalDragEnd: _onVerticalDragEnd,

          child: Column(
            children: [
              // ====================================================
              // SWIPE INDICATOR
              // ====================================================
              _swipeIndicator(),

              // ====================================================
              // HEADER
              // ====================================================
              _chatHeader(),

              // ====================================================
              // MESSAGES
              // ====================================================
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,

                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),

                  itemCount: _messages.length + (_isTyping ? 1 : 0),

                  itemBuilder: (context, index) {
                    if (_isTyping && index == _messages.length) {
                      return _typingIndicator();
                    }

                    return _messageBubble(_messages[index]);
                  },
                ),
              ),

              // ====================================================
              // QUICK ACTIONS
              // ====================================================
              _quickActions(),

              // ====================================================
              // INPUT
              // ====================================================
              _messageInput(),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // SWIPE INDICATOR
  // ================================================================

  Widget _swipeIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 7),

      child: Column(
        children: [
          Container(
            width: 58,
            height: 5,

            decoration: BoxDecoration(
              color: const Color(0xFF9EA9B2),

              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 5),

          const Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF0866E8),
                size: 18,
              ),

              SizedBox(width: 4),

              Text(
                'Swipe down to exit',
                style: TextStyle(color: Color(0xFF66747E), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // HEADER
  // ================================================================

  Widget _chatHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),

      child: Row(
        children: [
          // --------------------------------------------------------
          // AI ICON
          // --------------------------------------------------------
          Container(
            width: 55,
            height: 55,

            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FC),

              borderRadius: BorderRadius.circular(17),
            ),

            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF0866E8),
              size: 29,
            ),
          ),

          const SizedBox(width: 13),

          // --------------------------------------------------------
          // TITLE
          // --------------------------------------------------------
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'AskUC Assistant',
                  style: TextStyle(
                    color: Color(0xFF20262D),
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  'Your smart campus assistant',
                  style: TextStyle(color: Color(0xFF8A969E), fontSize: 11),
                ),
              ],
            ),
          ),

          // --------------------------------------------------------
          // CLOSE
          // --------------------------------------------------------
          _headerButton(icon: Icons.close, onTap: _exitChat),
        ],
      ),
    );
  }

  // ================================================================
  // CLOSE BUTTON
  // ================================================================

  Widget _headerButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,

      shape: const CircleBorder(),

      child: InkWell(
        customBorder: const CircleBorder(),

        onTap: onTap,

        child: const SizedBox(
          width: 45,
          height: 45,

          child: Icon(Icons.close, color: Color(0xFF0866E8), size: 22),
        ),
      ),
    );
  }

  // ================================================================
  // MESSAGE BUBBLE
  // ================================================================

  Widget _messageBubble(_ChatMessage message) {
    if (message.isUser) {
      return _userMessage(message);
    }

    return _assistantMessage(message);
  }

  // ================================================================
  // ASSISTANT MESSAGE
  // ================================================================

  Widget _assistantMessage(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 38,
            height: 38,

            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FC),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF0866E8),
              size: 19,
            ),
          ),

          const SizedBox(width: 10),

          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(17),

                    border: Border.all(color: const Color(0xFFDDE7EC)),
                  ),

                  child: Text(
                    message.text,

                    style: const TextStyle(
                      color: Color(0xFF20262D),
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                Padding(
                  padding: const EdgeInsets.only(left: 3),

                  child: Text(
                    message.time,

                    style: const TextStyle(
                      color: Color(0xFF8A969E),
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // USER MESSAGE
  // ================================================================

  Widget _userMessage(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,

        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 300),

            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),

            decoration: const BoxDecoration(
              color: Color(0xFF0866E8),

              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
                bottomLeft: Radius.circular(17),
                bottomRight: Radius.circular(5),
              ),
            ),

            child: Text(
              message.text,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 5),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,

            children: [
              Text(
                message.time,

                style: const TextStyle(color: Color(0xFF8A969E), fontSize: 9),
              ),

              const SizedBox(width: 5),

              const Icon(Icons.done_all, color: Color(0xFF0866E8), size: 15),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // TYPING INDICATOR
  // ================================================================

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,

            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FC),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF0866E8),
              size: 19,
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(17),

              border: Border.all(color: const Color(0xFFDDE7EC)),
            ),

            child: const Text(
              'AskUC is typing...',
              style: TextStyle(color: Color(0xFF8A969E), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // QUICK ACTIONS
  // ================================================================

  Widget _quickActions() {
    return SizedBox(
      height: 48,

      child: ListView(
        scrollDirection: Axis.horizontal,

        padding: const EdgeInsets.symmetric(horizontal: 16),

        children: [
          _quickButton(
            icon: Icons.menu_book_outlined,

            label: 'Library Hours',

            onTap: () {
              _sendQuickQuestion('What are the library opening hours?');
            },
          ),

          const SizedBox(width: 8),

          _quickButton(
            icon: Icons.business_outlined,

            label: 'Contact Office',

            onTap: () {
              _sendQuickQuestion('How can I contact a university office?');
            },
          ),
        ],
      ),
    );
  }

  // ================================================================
  // QUICK BUTTON
  // ================================================================

  Widget _quickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,

      icon: Icon(icon, size: 18, color: const Color(0xFF0866E8)),

      label: Text(
        label,

        style: const TextStyle(
          color: Color(0xFF0866E8),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),

      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,

        side: const BorderSide(color: Color(0xFFD4E3F2)),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }

  // ================================================================
  // MESSAGE INPUT
  // ================================================================

  Widget _messageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),

      decoration: const BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,

        children: [
          Expanded(
            child: TextField(
              controller: _messageController,

              minLines: 1,
              maxLines: 4,

              textInputAction: TextInputAction.send,

              onSubmitted: (_) {
                _sendMessage();
              },

              style: const TextStyle(color: Color(0xFF20262D), fontSize: 12),

              decoration: InputDecoration(
                hintText: 'Type your question...',

                hintStyle: const TextStyle(
                  color: Color(0xFF9AA6AE),
                  fontSize: 12,
                ),

                filled: true,

                fillColor: Colors.white,

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),

                  borderSide: const BorderSide(color: Color(0xFFDDE7EC)),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),

                  borderSide: const BorderSide(color: Color(0xFF0866E8)),
                ),
              ),
            ),
          ),

          const SizedBox(width: 9),

          // --------------------------------------------------------
          // SEND
          // --------------------------------------------------------
          Material(
            color: const Color(0xFF0866E8),

            shape: const CircleBorder(),

            child: InkWell(
              customBorder: const CircleBorder(),

              onTap: _sendMessage,

              child: const SizedBox(
                width: 48,
                height: 48,

                child: Icon(Icons.send_outlined, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// CHAT MESSAGE MODEL
// ==================================================================

class _ChatMessage {
  final String text;
  final bool isUser;
  final String time;

  _ChatMessage({required this.text, required this.isUser, required this.time});
}
