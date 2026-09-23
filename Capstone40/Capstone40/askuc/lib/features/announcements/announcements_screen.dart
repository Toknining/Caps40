import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AnnouncementStore {
  static final ValueNotifier<Set<String>> readIdsNotifier =
      ValueNotifier<Set<String>>(<String>{});
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  static String? _activeUserId;
  static String? _initializingUserId;
  static Future<void>? _initialization;

  static void _setReadIds(Iterable<dynamic> values) {
    final ids = values
        .map((value) => value.toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    readIdsNotifier.value = ids;
  }

  static Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await _profileSubscription?.cancel();
      _profileSubscription = null;
      _activeUserId = null;
      _initializingUserId = null;
      _initialization = null;
      _setReadIds(const <String>[]);
      return;
    }

    if (_activeUserId == user.uid) {
      return;
    }

    if (_initializingUserId == user.uid && _initialization != null) {
      await _initialization;
      return;
    }

    final initialization = _initializeForUser(user.uid);
    _initializingUserId = user.uid;
    _initialization = initialization;

    try {
      await initialization;
    } finally {
      if (_initializingUserId == user.uid) {
        _initializingUserId = null;
        _initialization = null;
      }
    }
  }

  static Future<void> _initializeForUser(String userId) async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _activeUserId = null;

    final profileRef = FirebaseFirestore.instance
        .collection('students')
        .doc(userId);
    final profileSnapshot = await profileRef.get();

    if (FirebaseAuth.instance.currentUser?.uid != userId) {
      return;
    }

    _setReadIds(
      profileSnapshot.data()?['readAnnouncementIds'] as List? ?? const [],
    );
    _activeUserId = userId;

    _profileSubscription = profileRef.snapshots().listen((snapshot) {
      if (_activeUserId != userId) {
        return;
      }

      _setReadIds(snapshot.data()?['readAnnouncementIds'] as List? ?? const []);
    });
  }

  static Future<Set<String>> getReadIds() async {
    await initialize();
    return readIdsNotifier.value;
  }

  static Future<void> markRead(String announcementId) async {
    final id = announcementId.trim();
    if (id.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _setReadIds(<String>{...readIdsNotifier.value, id});
      return;
    }

    await FirebaseFirestore.instance.collection('students').doc(user.uid).set({
      'readAnnouncementIds': FieldValue.arrayUnion([id]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _setReadIds(<String>{...readIdsNotifier.value, id});
  }

  static Future<void> markAllRead(List<String> ids) async {
    final validIds = ids.where((id) => id.trim().isNotEmpty).toSet();
    if (validIds.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _setReadIds(<String>{...readIdsNotifier.value, ...validIds});
      return;
    }

    await FirebaseFirestore.instance.collection('students').doc(user.uid).set({
      'readAnnouncementIds': FieldValue.arrayUnion(validIds.toList()),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _setReadIds(<String>{...readIdsNotifier.value, ...validIds});
  }

  static Future<void> clearReadIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .set({
            'readAnnouncementIds': const <String>[],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }

    _setReadIds(const <String>[]);
  }

  static Future<int> getUnreadCount(List<String> ids) async {
    final readIds = await getReadIds();
    return ids.where((id) => !readIds.contains(id)).length;
  }
}

class AnnouncementMapper {
  static Map<String, dynamic> fromMap(Map<String, dynamic> data) {
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return {
      'title': (data['title'] ?? 'Announcement').toString(),
      'message': (data['message'] ?? '').toString(),
      'time': _formatTime(createdAt),
      'icon': Icons.campaign,
      'unread': true,
    };
  }

  static String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return 'Today';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, this.onExit});

  final VoidCallback? onExit;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final List<Map<String, dynamic>> _notifications = [];
  Set<String> _readAnnouncementIds = <String>{};
  final Set<String> _expandedAnnouncementIds = <String>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> get _announcementsStream =>
      FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .snapshots();

  @override
  void initState() {
    super.initState();
    AnnouncementStore.initialize();
    _loadReadAnnouncementIds();
  }

  Future<void> _loadReadAnnouncementIds() async {
    final readIds = await AnnouncementStore.getReadIds();
    if (!mounted) {
      return;
    }

    setState(() {
      _readAnnouncementIds = readIds;
    });
  }

  List<Map<String, dynamic>> _mapSnapshotToNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((doc) {
      final item = AnnouncementMapper.fromMap(doc.data());
      item['id'] = doc.id;
      item['unread'] = !_readAnnouncementIds.contains(doc.id);
      return item;
    }).toList();
  }

  Future<void> _markAllAsRead() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .get();

    final unreadIds = snapshot.docs
        .map((doc) => doc.id)
        .where((id) => !_readAnnouncementIds.contains(id))
        .toList();

    if (unreadIds.isEmpty) {
      return;
    }

    await AnnouncementStore.markAllRead(unreadIds);

    if (!mounted) {
      return;
    }

    final updatedReadIds = Set<String>.from(_readAnnouncementIds)
      ..addAll(unreadIds);

    setState(() {
      _readAnnouncementIds = updatedReadIds;
      _notifications
        ..clear()
        ..addAll(
          snapshot.docs.map((doc) {
            final item = AnnouncementMapper.fromMap(doc.data());
            item['id'] = doc.id;
            item['unread'] = false;
            return item;
          }).toList(),
        );
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
          onPressed: widget.onExit ?? () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Color(0xFF20262D)),
          tooltip: 'Back',
        ),
        title: const Text(
          'Announcements',
          style: TextStyle(
            color: Color(0xFF20262D),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(top: 3, left: 8, right: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Mark all',
              style: TextStyle(
                color: Color(0xFF0866E8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                        Icons.campaign_rounded,
                        color: Color(0xFF0866E8),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Stay updated with campus announcements',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _announcementsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load announcements: ${snapshot.error}',
                        ),
                      );
                    }

                    final notifications = snapshot.data == null
                        ? <Map<String, dynamic>>[]
                        : _mapSnapshotToNotifications(snapshot.data!);

                    if (notifications.isEmpty) {
                      return _emptyAnnouncementsState();
                    }

                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];

                        return _notificationCard(
                          context,
                          id: notification['id']?.toString() ?? '$index',
                          title: notification['title'],
                          message: notification['message'],
                          time: notification['time'],
                          icon: notification['icon'],
                          unread: notification['unread'] ?? false,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // NOTIFICATION CARD
  // ================================================================

  Widget _emptyAnnouncementsState() {
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
                Icons.announcement_outlined,
                color: Color(0xFF0866E8),
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No announcements yet',
              style: TextStyle(
                color: Color(0xFF20262D),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'New campus updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A969E), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationCard(
    BuildContext context, {
    required String id,
    required String title,
    required String message,
    required String time,
    required IconData icon,
    required bool unread,
  }) {
    final isExpanded = _expandedAnnouncementIds.contains(id);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        if (unread) {
          await AnnouncementStore.markRead(id);
          if (!mounted) {
            return;
          }
          setState(() {
            _readAnnouncementIds.add(id);
          });
        }

        setState(() {
          if (isExpanded) {
            _expandedAnnouncementIds.clear();
          } else {
            _expandedAnnouncementIds
              ..clear()
              ..add(id);
          }
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unread ? const Color(0xFFDBEAFE) : const Color(0xFFE3EBF2),
            width: unread ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0866E8), size: 20),
            ),
            const SizedBox(width: 12),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0866E8),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: Text(
                      message,
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          time,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                    ],
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
