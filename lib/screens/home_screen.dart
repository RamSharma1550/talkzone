import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'call_screen.dart';
import 'status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _currentUser = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _saveUserToFirebase();
  }

  Future<void> _saveUserToFirebase() async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .set({
      'uid': _currentUser.uid,
      'name': 'User_${_currentUser.uid.substring(0, 5)}',
      'phone': '',
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<Widget> get _screens => [
    const ChatsTab(),
    const CallsTab(),
    const StatusScreen(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00A884), Color(0xFF00D4A0)],
          ).createShader(bounds),
          child: const Text(
            'TalkZone',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onPressed: () {
              showMenu(
                context: context,
                position: const RelativeRect.fromLTRB(100, 80, 0, 0),
                color: const Color(0xFF1A1F2E),
                items: [
                  PopupMenuItem(
                    child: const Text('Settings',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {},
                  ),
                  PopupMenuItem(
                    child: const Text('Logout',
                        style: TextStyle(color: Colors.redAccent)),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                  ),
                ],
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _buildTab('Chats', 0),
              _buildTab('Calls', 1),
              _buildTab('Status', 2),
              _buildTab('Profile', 3),
            ],
          ),
        ),
      ),
      body: _screens[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF00A884),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => _showNewChatDialog(),
            )
          : null,
    );
  }

  Widget _buildTab(String title, int index) {
    bool isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive
                    ? const Color(0xFF00A884)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive
                  ? const Color(0xFF00A884)
                  : Colors.white38,
              fontSize: 13,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('New Chat',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator(
                      color: Color(0xFF00A884));
                }
                final users = snapshot.data!.docs.where((doc) =>
                    doc.id != _currentUser.uid).toList();
                if (users.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No users yet!\nAsk your friend to install TalkZone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user =
                        users[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF00A884).withOpacity(0.2),
                        child: Text(
                          (user['name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFF00A884)),
                        ),
                      ),
                      title: Text(user['name'] ?? 'Unknown',
                          style:
                              const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        'TalkZone User',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              userId: users[index].id,
                              userName: user['name'] ?? 'Unknown',
                            ),
                          ),
                        );
                      },
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

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00A884)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                const Text('No chats yet',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Tap + to start a new chat',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chat = snapshot.data!.docs[index].data()
                as Map<String, dynamic>;
            final otherUserId = (chat['participants'] as List)
                .firstWhere((id) => id != currentUser.uid);
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const SizedBox();
                final user = userSnapshot.data!.data()
                    as Map<String, dynamic>? ?? {};
                return _ChatTile(
                  name: user['name'] ?? 'Unknown',
                  lastMessage: chat['lastMessage'] ?? '',
                  time: chat['lastMessageTime'] != null
                      ? _formatTime(
                          (chat['lastMessageTime'] as Timestamp).toDate())
                      : '',
                  unread: chat['unread_${currentUser.uid}'] ?? 0,
                  userId: otherUserId,
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(time).inDays == 1) {
      return 'Yesterday';
    }
    return '${time.day}/${time.month}';
  }
}

class _ChatTile extends StatelessWidget {
  final String name, lastMessage, time;
  final int unread;
  final String userId;

  const _ChatTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor:
                const Color(0xFF00A884).withOpacity(0.15),
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF00A884),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          title: Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 15)),
          subtitle: Text(lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time,
                  style: TextStyle(
                      color: unread > 0
                          ? const Color(0xFF00A884)
                          : Colors.white24,
                      fontSize: 11)),
              const SizedBox(height: 4),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00A884),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ChatScreen(userId: userId, userName: name),
            ),
          ),
        ),
        Divider(
            color: Colors.white.withOpacity(0.04),
            height: 1,
            indent: 72),
      ],
    );
  }
}

class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('calls')
          .where('participants',
              arrayContains: FirebaseAuth.instance.currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call_outlined,
                    size: 80,
                    color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                const Text('No calls yet',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final call = snapshot.data!.docs[index].data()
                as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    const Color(0xFF00A884).withOpacity(0.15),
                child: Icon(
                  call['type'] == 'video'
                      ? Icons.videocam
                      : Icons.call,
                  color: const Color(0xFF00A884),
                ),
              ),
              title: Text(call['callerName'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                call['status'] ?? 'missed',
                style: TextStyle(
                  color: call['status'] == 'missed'
                      ? Colors.redAccent
                      : Colors.white38,
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                call['type'] == 'video'
                    ? Icons.videocam_outlined
                    : Icons.call_outlined,
                color: const Color(0xFF00A884),
              ),
            );
          },
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        final data =
            snapshot.data?.data() as Map<String, dynamic>? ?? {};
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundColor:
                    const Color(0xFF00A884).withOpacity(0.2),
                child: Text(
                  (data['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF00A884),
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data['name'] ?? 'TalkZone User',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const Text(
                'TalkZone User',
                style: TextStyle(
                    color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 32),
              _profileOption(
                  Icons.edit, 'Edit Profile', Colors.blue, () {}),
              _profileOption(
                  Icons.notifications_outlined,
                  'Notifications',
                  Colors.orange,
                  () {}),
              _profileOption(Icons.privacy_tip_outlined,
                  'Privacy', Colors.purple, () {}),
              _profileOption(
                  Icons.logout, 'Logout', Colors.red, () async {
                await FirebaseAuth.instance.signOut();
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _profileOption(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style:
                const TextStyle(color: Colors.white, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right,
            color: Colors.white24, size: 18),
        onTap: onTap,
      ),
    );
  }
}
