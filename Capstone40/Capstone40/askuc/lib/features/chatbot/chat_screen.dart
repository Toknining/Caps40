import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key}) : onClose = null;

  // Shows the chat as a floating window instead of a full page. Closing it
  // calls [onClose] instead of popping the route.
  const ChatScreen.floating({super.key, required VoidCallback this.onClose});

  final VoidCallback? onClose;

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
  Future<List<String>>? _blockedWordsFuture;
  DateTime? _blockedWordsCachedAt;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ================================================================
  // SEND MESSAGE
  // ================================================================

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isTyping) {
      return;
    }

    setState(() => _isTyping = true);

    try {
      final blockedWord = await _findBlockedWord(message);
      if (!mounted) {
        return;
      }

      if (blockedWord != null) {
        setState(() {
          _isTyping = false;
          _messageController.clear();
          _messages.add(
            _ChatMessage(
              text:
                  'I can’t help with a message containing a blocked word or phrase. '
                  'Please rephrase your question.',
              isUser: false,
              time: _currentTime(),
            ),
          );
        });
        _scrollToBottom();
        return;
      }
    } catch (error) {
      debugPrint('Failed to check blocked words: $error');
      if (!mounted) {
        return;
      }

      setState(() => _isTyping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to check the word filter. Your message was not sent.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(text: message, isUser: true, time: _currentTime()),
      );

      _messageController.clear();
    });

    unawaited(_recordChatbotQuery(message));

    _scrollToBottom();

    // --------------------------------------------------------------
    // TEMPORARY RESPONSE
    // --------------------------------------------------------------

    Future.delayed(const Duration(milliseconds: 900), () async {
      final knowledgeBaseAnswer = await _findKnowledgeBaseAnswer(message);
      if (!mounted) {
        return;
      }

      setState(() {
        _isTyping = false;

        _messages.add(
          _ChatMessage(
            text:
                '${knowledgeBaseAnswer ?? _getDemoResponse(message)}\n\n'
                'Recommendation: '
                '${_recommendationForIntent(_recognizeIntent(message), _recognizeLanguage(message))}',
            isUser: false,
            time: _currentTime(),
          ),
        );
      });

      _scrollToBottom();
    });
  }

  Future<List<String>> _loadBlockedWords() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('blockedWords')
        .get();
    return snapshot.docs
        .map((document) => document.data()['word'])
        .whereType<String>()
        .map((word) => word.trim().toLowerCase())
        .where((word) => word.isNotEmpty)
        .toList();
  }

  Future<String?> _findBlockedWord(String message) async {
    try {
      final cacheIsStale =
          _blockedWordsCachedAt == null ||
          DateTime.now().difference(_blockedWordsCachedAt!) >
              const Duration(seconds: 30);
      if (_blockedWordsFuture == null || cacheIsStale) {
        _blockedWordsFuture = _loadBlockedWords();
        _blockedWordsCachedAt = DateTime.now();
      }
      final words = await _blockedWordsFuture!;
      final messageTokens = _textTokens(message);

      for (final word in words) {
        final wordTokens = _textTokens(word);
        if (_containsTokenSequence(messageTokens, wordTokens)) {
          return word;
        }
      }
      return null;
    } catch (_) {
      _blockedWordsFuture = null;
      _blockedWordsCachedAt = null;
      rethrow;
    }
  }

  List<String> _textTokens(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^\w\u00c0-\u024f]+'))
      .where((token) => token.isNotEmpty)
      .toList();

  bool _containsTokenSequence(List<String> text, List<String> phrase) {
    if (phrase.isEmpty || phrase.length > text.length) {
      return false;
    }

    for (var start = 0; start <= text.length - phrase.length; start++) {
      var matches = true;
      for (var offset = 0; offset < phrase.length; offset++) {
        if (text[start + offset] != phrase[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }
    return false;
  }

  Future<void> _recordChatbotQuery(String question) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('chatbotQueries').add({
        'userId': user.uid,
        'intent': _recognizeIntent(question),
        'recommendationRule': _recognizeIntent(question),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Failed to record chatbot query: $error');
    }
  }

  Future<String?> _findKnowledgeBaseAnswer(String question) async {
    final questionTerms = _knowledgeBaseTerms(question);
    if (questionTerms.isEmpty) {
      return null;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('faqs')
          .get();
      String? bestAnswer;
      var bestScore = 0.0;

      for (final document in snapshot.docs) {
        final data = document.data();
        final faqQuestion = data['question'];
        final faqAnswer = data['answer'];
        if (faqQuestion is! String ||
            faqAnswer is! String ||
            faqAnswer.trim().isEmpty) {
          continue;
        }

        final faqTerms = _knowledgeBaseTerms(faqQuestion);
        if (faqTerms.isEmpty) {
          continue;
        }

        final matchingTerms = questionTerms.intersection(faqTerms).length;
        final score = matchingTerms / questionTerms.length;
        if (score >= 0.5 && score > bestScore) {
          bestScore = score;
          bestAnswer = faqAnswer.trim();
        }
      }

      return bestAnswer;
    } catch (error) {
      debugPrint('Failed to search chatbot knowledge base: $error');
      return null;
    }
  }

  Set<String> _knowledgeBaseTerms(String text) {
    const stopWords = {
      'a',
      'an',
      'and',
      'are',
      'can',
      'do',
      'does',
      'for',
      'how',
      'i',
      'is',
      'it',
      'me',
      'of',
      'on',
      'please',
      'the',
      'to',
      'what',
      'where',
      'which',
      'who',
      'why',
      'you',
      'ako',
      'ang',
      'ba',
      'kanus',
      'kinsa',
      'mga',
      'mo',
      'ng',
      'nga',
      'ngano',
      'nimo',
      'nasa',
      'nasaan',
      'ano',
      'anong',
      'asa',
      'pila',
      'po',
      'para',
      'sa',
      'saan',
      'siya',
      'unsa',
      'ug',
    };

    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((term) => term.length > 2 && !stopWords.contains(term))
        .toSet();
  }

  String _recognizeIntent(String question) {
    final text = question.toLowerCase();

    if (_containsAny(text, ['library', 'librarya', 'aklatan'])) {
      return 'library_location';
    }

    if (_containsAny(text, [
      'hours',
      'open',
      'oras',
      'orasa',
      'bukas ba',
      'abri',
      'abli',
    ])) {
      return 'opening_hours';
    }

    if (_containsAny(text, ['office', 'opisina', 'tanggapan'])) {
      return 'office_contact';
    }

    if (_containsAny(text, ['announcement', 'anunsyo', 'pahibalo', 'balita'])) {
      return 'announcements';
    }

    if (_containsAny(text, [
      'faq',
      'pangutana',
      'kasagarang pangutana',
      'frequently asked',
      'tanong',
      'katanungan',
    ])) {
      return 'faq';
    }

    return 'general';
  }

  bool _containsAny(String text, List<String> terms) =>
      terms.any((term) => text.contains(term));

  String _recognizeLanguage(String question) {
    final tokens = _textTokens(question).toSet();
    const cebuanoCues = {
      'asa',
      'unsa',
      'abri',
      'abli',
      'pahibalo',
      'kasagarang',
      'kanus',
      'kinsa',
      'pila',
      'ngano',
      'librarya',
    };
    const tagalogCues = {
      'saan',
      'nasaan',
      'aklatan',
      'oras',
      'anong',
      'ano',
      'tanggapan',
      'anunsyo',
      'bakit',
      'paano',
      'magkano',
    };
    final cebuanoScore = tokens.intersection(cebuanoCues).length;
    final tagalogScore = tokens.intersection(tagalogCues).length;

    if (cebuanoScore > tagalogScore && cebuanoScore > 0) {
      return 'Cebuano';
    }
    if (tagalogScore > 0) {
      return 'Tagalog';
    }
    return 'English';
  }

  String _recommendationForIntent(String intent, String language) {
    if (language == 'Cebuano') {
      switch (intent) {
        case 'library_location':
          return 'Ablihi ang Campus Map aron pangitaon ang Library ug makita ang agianan.';
        case 'opening_hours':
          return 'Tan-awa ang Announcements para sa mga kausaban sa oras.';
        case 'office_contact':
          return 'Tan-awa ang campus FAQs alang sa impormasyon sa opisina.';
        case 'announcements':
          return 'Ablihi ang Announcements aron mabasa ang pinakabag-ong mga pahibalo.';
        default:
          return 'Pangutana bahin sa Library, opisina, oras, o mga pahibalo sa campus.';
      }
    }
    if (language == 'Tagalog') {
      switch (intent) {
        case 'library_location':
          return 'Buksan ang Campus Map para mahanap ang Library at makita ang ruta.';
        case 'opening_hours':
          return 'Tingnan ang Announcements para sa mga pagbabago sa oras.';
        case 'office_contact':
          return 'Tingnan ang campus FAQs para sa impormasyon ng opisina.';
        case 'announcements':
          return 'Buksan ang Announcements para mabasa ang pinakabagong mga anunsyo.';
        default:
          return 'Magtanong tungkol sa Library, opisina, oras, o mga anunsyo sa campus.';
      }
    }

    switch (intent) {
      case 'library_location':
        return 'Open the Campus Map to locate the Library and plan your route.';
      case 'opening_hours':
        return 'Check Announcements for schedule changes before you visit.';
      case 'office_contact':
        return 'Browse the campus FAQs for office contact information.';
      case 'announcements':
        return 'Open Announcements to read the latest campus updates.';
      case 'faq':
        return 'Try asking about a campus location, office, or opening hours.';
      default:
        return 'Try asking about the Library, office contacts, opening hours, or announcements.';
    }
  }

  // ================================================================
  // DEMO AI RESPONSE
  // ================================================================

  String _getDemoResponse(String question) {
    final intent = _recognizeIntent(question);
    final language = _recognizeLanguage(question);

    if (language == 'Cebuano') {
      switch (intent) {
        case 'library_location':
          return 'Ang Library duol sa Main Building, sa ground floor atbang sa central courtyard.';
        case 'opening_hours':
          return 'Abli ang Library:\n\n'
              'Lunes–Biyernes: 7:30 AM–9:00 PM\n'
              'Sabado: 8:00 AM–5:00 PM';
        case 'office_contact':
          return 'Kontaka ang angay nga opisina sa unibersidad alang sa tabang ug impormasyon.';
        case 'announcements':
          return 'Ablihi ang Announcements aron makita ang pinakabag-ong mga pahibalo sa campus.';
        default:
          return 'Makatabang ang AskUC sa impormasyon sa campus, mga lokasyon, pahibalo, ug kasagarang pangutana. Unsa pa imong gustong mahibal-an?';
      }
    }

    if (language == 'Tagalog') {
      switch (intent) {
        case 'library_location':
          return 'Malapit ang Library sa Main Building, sa ground floor, katapat ng central courtyard.';
        case 'opening_hours':
          return 'Bukas ang Library:\n\n'
              'Lunes–Biyernes: 7:30 AM–9:00 PM\n'
              'Sabado: 8:00 AM–5:00 PM';
        case 'office_contact':
          return 'Makipag-ugnayan sa naaangkop na tanggapan ng unibersidad para sa tulong at impormasyon.';
        case 'announcements':
          return 'Buksan ang Announcements para makita ang pinakabagong mga anunsyo sa campus.';
        default:
          return 'Makakatulong ang AskUC sa impormasyon tungkol sa campus, mga lokasyon, anunsyo, at mga karaniwang tanong. Ano pa ang gusto mong malaman?';
      }
    }

    if (intent == 'library_location') {
      return 'The library is located near the '
          'Main Building. You can find it on '
          'the ground floor, facing the central '
          'courtyard.';
    }

    if (intent == 'opening_hours') {
      return 'The library is open from:\n\n'
          'Monday – Friday: 7:30 AM – 9:00 PM\n'
          'Saturday: 8:00 AM – 5:00 PM';
    }

    if (intent == 'office_contact') {
      return 'You can contact the appropriate '
          'university office for assistance. '
          'AskUC can also help you find the '
          'information you need.';
    }

    if (intent == 'announcements') {
      return 'You can check the Notifications '
          'section to view the latest campus '
          'announcements.';
    }

    if (intent == 'faq') {
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
    if (_isTyping) {
      return;
    }

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
      _exitChat();
    }

    _dragDistance = 0;
  }

  // ================================================================
  // EXIT CHAT
  // ================================================================

  bool get _isFloating => widget.onClose != null;

  void _exitChat() {
    if (_isFloating) {
      widget.onClose!();
      return;
    }

    Navigator.pop(context);
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final chat = GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,

      onVerticalDragEnd: _onVerticalDragEnd,

      child: Column(
        children: [
          // ====================================================
          // SWIPE INDICATOR
          // ====================================================
          if (!_isFloating) _swipeIndicator(),

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
    );

    if (_isFloating) {
      return Material(
        color: const Color(0xFFF8FAFC),

        elevation: 16,

        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.4),

        borderRadius: BorderRadius.circular(24),

        clipBehavior: Clip.antiAlias,

        child: chat,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(child: chat),
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

              enabled: !_isTyping,

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

              onTap: _isTyping ? null : _sendMessage,

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
