import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatConversationScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverImage;

  const ChatConversationScreen({
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
  });

  @override
  _ChatConversationScreenState createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _conversationId;
  late String _currentUserId;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _conversationId = _generateConversationId(_currentUserId, widget.receiverId);
    _loadMessages();
    _markMessagesAsSeen();
  }

  String _generateConversationId(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  void _loadMessages() {
    _firestore
        .collection('conversations')
        .doc(_conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> loadedMessages = [];
        WriteBatch batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          var data = doc.data();
          data['id'] = doc.id; // Keep the document ID for updates
          loadedMessages.add(data);

          // If the message is for this user and status is 'sent', mark as 'delivered'
          if (data['senderId'] != _currentUserId && data['status'] == 'sent') {
            batch.update(
              _firestore
                  .collection('conversations')
                  .doc(_conversationId)
                  .collection('messages')
                  .doc(doc.id),
              {'status': 'delivered'},
            );
          }
        }
        if (snapshot.docs.any((doc) =>
        doc.data()['senderId'] != _currentUserId && doc.data()['status'] == 'sent')) {
          await batch.commit();
        }
        setState(() {
          _messages = loadedMessages;
        });
      }
    });
  }

  // Mark all delivered messages as seen when opening the chat
  Future<void> _markMessagesAsSeen() async {
    final query = await _firestore
        .collection('conversations')
        .doc(_conversationId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.receiverId)
        .where('status', isEqualTo: 'delivered')
        .get();

    WriteBatch batch = _firestore.batch();
    for (var doc in query.docs) {
      batch.update(doc.reference, {'status': 'seen'});
    }
    if (query.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      'senderId': _currentUserId,
      'text': _messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent', // 1 tick
    };

    try {
      // Add to messages subcollection
      await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add(message);

      // Update conversation last message
      await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .set({
        'lastMessage': _messageController.text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'members': [_currentUserId, widget.receiverId],
      }, SetOptions(merge: true));

      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  void didUpdateWidget(ChatConversationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _markMessagesAsSeen();
  }

  @override
  Widget build(BuildContext context) {
    // Mark messages as seen every time the widget is built (i.e., when chat is open)
    WidgetsBinding.instance.addPostFrameCallback((_) => _markMessagesAsSeen());
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.receiverImage),
            ),
            SizedBox(width: 12),
            Text(widget.receiverName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['senderId'] == _currentUserId;
                return _buildMessageBubble(message, isMe);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: isMe ? Radius.circular(16) : Radius.circular(0),
            bottomRight: isMe ? Radius.circular(0) : Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message['text']),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(message['timestamp']),
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (isMe) ...[
                  SizedBox(width: 6),
                  _buildTickIcon(message['status']),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTickIcon(String? status) {
    // 1 tick: sent, 2 ticks: delivered, 3 ticks: seen
    if (status == 'seen') {
      // Three ticks: custom icon (here, using three blue check icons)
      return Row(
        children: [
          Icon(Icons.done, size: 16, color: Colors.blue),
          Icon(Icons.done, size: 16, color: Colors.blue),
          Icon(Icons.done, size: 16, color: Colors.blue),
        ],
      );
    } else if (status == 'delivered') {
      // Two ticks: two blue check icons
      return Row(
        children: [
          Icon(Icons.done, size: 16, color: Colors.blue),
          Icon(Icons.done, size: 16, color: Colors.blue),
        ],
      );
    } else {
      // One tick: one grey check icon
      return Icon(Icons.done, size: 16, color: Colors.grey);
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Colors.blue),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}
