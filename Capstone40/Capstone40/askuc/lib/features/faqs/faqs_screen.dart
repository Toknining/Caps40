import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// The FAQs admins add in the admin panel's Chatbot Knowledge Base, listed
/// as questions. Tapping a question shows or hides its answer.
class FaqsScreen extends StatefulWidget {
  const FaqsScreen({super.key});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  final Set<String> _openFaqIds = <String>{};

  // Kept in a field so opening an answer doesn't restart the stream. Newest
  // first, the same order as the admin panel.
  final Stream<QuerySnapshot<Map<String, dynamic>>> _faqsStream =
      FirebaseFirestore.instance
          .collection('faqs')
          .orderBy('createdAt', descending: true)
          .snapshots();

  void _toggleFaq(String id) {
    setState(() {
      if (!_openFaqIds.remove(id)) {
        _openFaqIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF20262D)),
          tooltip: 'Back',
        ),
        title: const Text(
          'FAQs',
          style: TextStyle(
            color: Color(0xFF20262D),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _introCard(),
              const SizedBox(height: 18),
              Expanded(child: _faqList()),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // INTRO
  // ================================================================

  Widget _introCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EBF2), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.help_rounded,
              color: Color(0xFF0866E8),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Answers to common campus questions. '
              'Tap a question to see its answer.',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // FAQ LIST
  // ================================================================

  Widget _faqList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _faqsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load the FAQs.\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data?.docs;
        if (docs == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final faqs = [
          for (final doc in docs)
            if ((doc.data()['question'] ?? '').toString().trim().isNotEmpty)
              doc,
        ];

        if (faqs.isEmpty) {
          return _emptyFaqsState();
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: faqs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final faq = faqs[index];
            final data = faq.data();

            return _faqCard(
              id: faq.id,
              question: data['question'].toString().trim(),
              answer: (data['answer'] ?? '').toString().trim(),
            );
          },
        );
      },
    );
  }

  Widget _emptyFaqsState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3EBF2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFF0866E8),
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No FAQs yet',
              style: TextStyle(
                color: Color(0xFF20262D),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Common campus questions will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A969E), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // FAQ CARD
  // ================================================================

  Widget _faqCard({
    required String id,
    required String question,
    required String answer,
  }) {
    final isOpen = _openFaqIds.contains(id);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOpen ? const Color(0xFFDBEAFE) : const Color(0xFFE3EBF2),
          width: isOpen ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _toggleFaq(id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFF0866E8),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question,
                        style: const TextStyle(
                          color: Color(0xFF20262D),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  sizeCurve: Curves.easeInOut,
                  crossFadeState: isOpen
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, color: Color(0xFFE3EBF2)),
                        const SizedBox(height: 12),
                        Text(
                          answer.isEmpty
                              ? 'No answer has been added yet.'
                              : answer,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
