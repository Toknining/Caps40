import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// AI Response Generation for the AskUC chatbot.
///
/// Answers with Gemini through Firebase AI Logic (the free Gemini Developer
/// API). The API key stays in the Firebase project, not in the app.
///
/// Every answer is grounded on AskUC's own data: the FAQs admins manage, the
/// latest announcements, and the places on the campus map. Gemini is told to
/// answer only from that, and to say when it does not know instead of
/// guessing.
class AskUCAssistant {
  /// The Gemini model used. Change this if Google retires it.
  static const model = 'gemini-3.1-flash-lite';

  /// How long the FAQs and announcements are reused before being read again,
  /// so admin changes reach an open chat without a read on every message.
  static const _contextTtl = Duration(minutes: 5);

  /// Messages remembered for follow-up questions (a question and its answer
  /// count as two).
  static const _maxHistory = 12;

  /// The places don't change while the app runs, so they load once.
  static final Future<String> _places = _loadPlaces();

  final _history = <Content>[];
  String? _context;
  DateTime? _contextLoadedAt;

  /// The answer to [question], or null when Gemini can't be reached (no
  /// internet, AI Logic not enabled in the Firebase console, or the free
  /// quota is used up), so the chat can fall back to its rule-based answers.
  Future<String?> reply(String question) async {
    try {
      final gemini = FirebaseAI.googleAI().generativeModel(
        model: model,
        systemInstruction: Content.system(await _instructions()),
        generationConfig: GenerationConfig(
          temperature: 0.3,
          // Room for a full list of enrollment steps in Cebuano or Tagalog,
          // which take more tokens than English. Short answers use far less.
          maxOutputTokens: 1000,
        ),
      );
      final chat = gemini.startChat(history: _history.toList());
      final response = await chat.sendMessage(Content.text(question));
      final answer = _plainText(response.text ?? '');
      if (answer.isEmpty) {
        return null;
      }

      _history
        ..clear()
        ..addAll(chat.history);
      if (_history.length > _maxHistory) {
        _history.removeRange(0, _history.length - _maxHistory);
      }
      return answer;
    } catch (error) {
      debugPrint('AskUC AI unavailable: $error');
      return null;
    }
  }

  Future<String> _instructions() async {
    final loadedAt = _contextLoadedAt;
    if (_context == null ||
        loadedAt == null ||
        DateTime.now().difference(loadedAt) > _contextTtl) {
      final parts = await Future.wait([_loadFaqs(), _loadAnnouncements()]);
      _context = parts.join('\n\n');
      _contextLoadedAt = DateTime.now();
    }

    return '''
You are AskUC Assistant, the campus helper inside the AskUC app for UC students.

Rules:
- Only answer questions about the university and campus life: locations, offices, facilities, announcements, school services and procedures. For anything else (homework, coding, general trivia), politely say in one sentence that you only help with campus questions.
- Use only the AskUC information below. If the answer is not there, say you don't have that information yet and suggest asking the right office or checking Announcements. Never make up office hours, fees, phone numbers, names, dates or room locations.
- For "where is" questions, give the building and floor from the campus places list, then tell the student to open the Map tab and pick it as the destination to see the route. Only places in that list are on the map.
- Reply in the language the student uses: English, Tagalog, or Cebuano (Bisaya). Mixed languages are fine.
- Keep replies short for a phone screen: 1 to 4 sentences, or a short list using "•". Plain text only: no Markdown, asterisks or headings.

$_context

${await _places}''';
  }

  static Future<String> _loadFaqs() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('faqs').get();
      final faqs = [
        for (final doc in snapshot.docs)
          if (doc.data() case {
            'question': final String question,
            'answer': final String answer,
          } when answer.trim().isNotEmpty)
            'Q: ${question.trim()}\nA: ${answer.trim()}',
      ];
      return 'FAQS (written by the AskUC admins; prefer these answers):\n'
          '${faqs.isEmpty ? 'None yet.' : faqs.join('\n\n')}';
    } catch (error) {
      debugPrint('AskUC AI could not load FAQs: $error');
      return 'FAQS: unavailable right now.';
    }
  }

  static Future<String> _loadAnnouncements() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      final announcements = [
        for (final doc in snapshot.docs) _describeAnnouncement(doc.data()),
      ];
      return 'LATEST ANNOUNCEMENTS (newest first):\n'
          '${announcements.isEmpty ? 'None yet.' : announcements.join('\n')}';
    } catch (error) {
      debugPrint('AskUC AI could not load announcements: $error');
      return 'LATEST ANNOUNCEMENTS: unavailable right now.';
    }
  }

  static Future<String> _loadPlaces() async {
    try {
      final graph =
          jsonDecode(await rootBundle.loadString('assets/campus_graph.json'))
              as Map<String, dynamic>;
      final places = [
        // Corridor points aren't places a student would ask about.
        for (final node in (graph['nodes'] as List).cast<Map<String, dynamic>>())
          if (node['kind'] != 'hall') _describePlace(node),
      ];
      return 'CAMPUS PLACES ON THE MAP:\n${places.join('\n')}';
    } catch (error) {
      debugPrint('AskUC AI could not load campus places: $error');
      return 'CAMPUS PLACES ON THE MAP: unavailable right now.';
    }
  }

  static String _describeAnnouncement(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final date = createdAt is Timestamp
        ? createdAt.toDate().toIso8601String().substring(0, 10)
        : 'undated';
    return '- ${data['title'] ?? 'Announcement'} ($date): '
        '${data['message'] ?? ''}';
  }

  static String _describePlace(Map<String, dynamic> node) {
    final aliases = (node['aliases'] as List?)?.join(', ') ?? '';
    final alsoCalled = aliases.isEmpty ? '' : '; also called $aliases';
    return '- ${node['name']}: ${node['building']}, floor ${node['floor']} '
        '(${node['kind']}$alsoCalled)';
  }

  /// Chat bubbles show plain text, so drop any Markdown Gemini adds anyway.
  static String _plainText(String text) => text
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[*-]\s+', multiLine: true), '• ')
      .trim();
}
