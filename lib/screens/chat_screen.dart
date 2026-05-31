import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const ChatScreen({super.key, required this.userId, required this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _currentUser = FirebaseAuth.instance.currentUser!;
  late String _chatId;

  @override
  void initState() {
    super.initState();
    final ids = [_currentUser.uid, widget.userId]..sort();
    _chatId = ids.join('_');
    _markAsRead();
  }

  void _markAsRead() {
    FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
      'unread_${_currentUser.uid}': 0,
    }).catchError((_) {});
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    final batch = FirebaseFirestore.instance.batch();
    final msgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'text': text,
      'senderId': _currentUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });

    batch.set(
      FirebaseFirestore.instance.collection('chats').doc(_chatId),
      {
        'participants': [_currentUser.uid, widget.userId],
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unread_${widget.userId}': FieldValue.increment(1),
        'unread_${_currentUser.uid}': 0,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00A884)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
              child: Text(
                widget.userName[0].toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF00A884), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const Text('online',
                    style: TextStyle(
                        color: Color(0xFF00A884), fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  userId: widget.userId,
                  userName: widget.userName,
                  isVideo: false,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  userId: widget.userId,
                  userName: widget.userName,
                  isVideo: true,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF00A884)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 60,
                            color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 12),
                        Text('Say hello to ${widget.userName}!',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 14)),
                      ],
                    ),
                  );
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final msg = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                    final isSent =
                        msg['senderId'] == _currentUser.uid;
                    final time = msg['timestamp'] != null
                        ? DateFormat('hh:mm a').format(
                            (msg['timestamp'] as Timestamp).toDate())
                        : '';
                    return _MessageBubble(
                      text: msg['text'] ?? '',
                      time: time,
                      isSent: isSent,
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.emoji_emotions_outlined,
                      color: Color(0xFF555555), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle:
                            TextStyle(color: Color(0xFF555555)),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file,
                        color: Color(0xFF555555), size: 22),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00A884), Color(0xFF00c49a)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A884).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text, time;
  final bool isSent;

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isSent,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          gradient: isSent
              ? const LinearGradient(
                  colors: [Color(0xFF00A884), Color(0xFF009a78)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSent ? null : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSent ? 16 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 16),
          ),
          border: isSent
              ? null
              : Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: isSent
              ? [
                  BoxShadow(
                    color: const Color(0xFF00A884).withOpacity(0.2),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(text,
                style: TextStyle(
                    color: isSent ? Colors.white : Colors.white70,
                    fontSize: 14,
                    height: 1.3)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time,
                    style: TextStyle(
                        color: isSent
                            ? Colors.white60
                            : Colors.white30,
                        fontSize: 10)),
                if (isSent) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.done_all,
                      size: 12, color: Colors.white60),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
