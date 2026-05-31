import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final _picker = ImagePicker();

  Future<void> _addStatus() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('status/${_currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('status').add({
        'userId': _currentUser.uid,
        'imageUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
        'viewers': [],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status uploaded! ✓'),
            backgroundColor: Color(0xFF00A884),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D12),
      body: Column(
        children: [
          // My Status Hero Card
          _MyStatusCard(onTap: _addStatus),

          // Recent Updates
          _sectionLabel('Recent Updates'),

          // Horizontal Story Cards
          SizedBox(
            height: 148,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('status')
                  .where('expiresAt', isGreaterThan: Timestamp.now())
                  .where('userId', isNotEqualTo: _currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF00A884)),
                  );
                }

                final Map<String, List<QueryDocumentSnapshot>> grouped = {};
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final uid = data['userId'] as String;
                  grouped.putIfAbsent(uid, () => []).add(doc);
                }

                final unseenUids = grouped.keys.where((uid) {
                  return grouped[uid]!.any((s) {
                    final data = s.data() as Map<String, dynamic>;
                    final viewers = List<String>.from(data['viewers'] ?? []);
                    return !viewers.contains(_currentUser.uid);
                  });
                }).toList();

                if (unseenUids.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 32,
                            color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 8),
                        const Text('No new updates',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: unseenUids.length,
                  itemBuilder: (context, index) {
                    final uid = unseenUids[index];
                    return _StoryCard(
                      userId: uid,
                      statuses: grouped[uid]!,
                      currentUserId: _currentUser.uid,
                    );
                  },
                );
              },
            ),
          ),

          // Viewed Section
          _sectionLabel('Viewed'),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('status')
                  .where('expiresAt', isGreaterThan: Timestamp.now())
                  .where('userId', isNotEqualTo: _currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final Map<String, List<QueryDocumentSnapshot>> grouped = {};
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final uid = data['userId'] as String;
                  grouped.putIfAbsent(uid, () => []).add(doc);
                }

                final seenUids = grouped.keys.where((uid) {
                  return grouped[uid]!.every((s) {
                    final data = s.data() as Map<String, dynamic>;
                    final viewers =
                        List<String>.from(data['viewers'] ?? []);
                    return viewers.contains(_currentUser.uid);
                  });
                }).toList();

                if (seenUids.isEmpty) {
                  return const Center(
                    child: Text('No viewed statuses',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 12)),
                  );
                }

                return ListView.builder(
                  itemCount: seenUids.length,
                  itemBuilder: (context, index) {
                    final uid = seenUids[index];
                    final data = grouped[uid]!.last.data()
                        as Map<String, dynamic>;
                    final time = data['timestamp'] != null
                        ? _formatTime(
                            (data['timestamp'] as Timestamp).toDate())
                        : '';
                    return _ViewedTile(
                      userId: uid,
                      time: time,
                      count: grouped[uid]!.length,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A884),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        onPressed: _addStatus,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: Colors.white.withOpacity(0.05))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 10,
                  letterSpacing: 1.5),
            ),
          ),
          Expanded(
              child: Divider(color: Colors.white.withOpacity(0.05))),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }
}

class _MyStatusCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MyStatusCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A2A20), Color(0xFF091A14)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00A884).withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00A884).withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00A884).withOpacity(0.12),
                    border: Border.all(
                        color: const Color(0xFF00A884).withOpacity(0.3),
                        width: 2),
                  ),
                  child: const Icon(Icons.person,
                      color: Colors.white38, size: 28),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00A884), Color(0xFF00ffcc)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00A884).withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Status',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text('✦ Tap to share your moment',
                      style: TextStyle(
                          color: Color(0xFF00A884), fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.camera_alt_outlined,
                color: Color(0xFF00A884), size: 22),
          ],
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final String userId;
  final List<QueryDocumentSnapshot> statuses;
  final String currentUserId;

  const _StoryCard({
    required this.userId,
    required this.statuses,
    required this.currentUserId,
  });

  final List<List<Color>> _gradients = const [
    [Color(0xFF0A2A20), Color(0xFF1A4A30)],
    [Color(0xFF1A1A3A), Color(0xFF2A1A4A)],
    [Color(0xFF2A1A0A), Color(0xFF4A2A1A)],
    [Color(0xFF0A1A2A), Color(0xFF1A2A4A)],
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(width: 100);
        final user =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = user['name'] ?? 'User';
        final data = statuses.last.data() as Map<String, dynamic>;
        final time = data['timestamp'] != null
            ? _formatTime(
                (data['timestamp'] as Timestamp).toDate())
            : '';
        final gradIndex = name.codeUnitAt(0) % _gradients.length;

        return GestureDetector(
          onTap: () => _viewStatus(context, name),
          child: Container(
            width: 100,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: _gradients[gradIndex],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: Colors.white.withOpacity(0.06)),
            ),
            child: Stack(
              children: [
                // Avatar top left
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00A884), Color(0xFF00D4A0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00A884).withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ),
                // Pulsing dot
                Positioned(
                  top: 8,
                  right: 8,
                  child: _PulsingDot(),
                ),
                // Bottom info
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        Text(time,
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewStatus(BuildContext context, String name) async {
    for (var status in statuses) {
      await FirebaseFirestore.instance
          .collection('status')
          .doc(status.id)
          .update({
        'viewers': FieldValue.arrayUnion([currentUserId]),
      });
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF00A884).withOpacity(_anim.value),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00A884).withOpacity(0.6),
              blurRadius: 6 * _anim.value,
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewedTile extends StatelessWidget {
  final String userId;
  final String time;
  final int count;

  const _ViewedTile({
    required this.userId,
    required this.time,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final user =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = user['name'] ?? 'User';
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Center(
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        Text(
                          '$time • $count update${count > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Color(0xFF444444),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.remove_red_eye_outlined,
                      color: Color(0xFF333333), size: 16),
                ],
              ),
            ),
            Divider(
                color: Colors.white.withOpacity(0.03),
                height: 1,
                indent: 72),
          ],
        );
      },
    );
  }
}
