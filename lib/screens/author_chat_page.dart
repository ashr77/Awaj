import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_conversation_screen.dart';
import'author_conversations_screen.dart';

class AuthorChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Chat Requests')),
        body: Center(child: Text('Please sign in to view requests')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.chat),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AuthorConversationsScreen()),
            ),
            tooltip: 'View conversations',
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_requests')
            .where('receiverId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No pending requests'),
                ],
              ),
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final requestData = request.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(requestData['senderId']).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: CircleAvatar(child: CircularProgressIndicator()),
                      title: Text('Loading...'),
                    );
                  }

                  if (!userSnapshot.hasData) {
                    return ListTile(
                      leading: CircleAvatar(child: Icon(Icons.error)),
                      title: Text('User not found'),
                    );
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

                  return _buildRequestCard(
                    request.id,
                    requestData,
                    userData ?? {},
                    context,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(
      String requestId,
      Map<String, dynamic> requestData,
      Map<String, dynamic> userData,
      BuildContext context,
      ) {
    return Card(
      margin: EdgeInsets.all(8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userData['imageUrl'] != null
              ? NetworkImage(userData['imageUrl'])
              : null,
          child: userData['imageUrl'] == null ? Icon(Icons.person) : null,
        ),
        title: Text(userData['fullName'] ?? 'Unknown User'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(requestData['message']),
            SizedBox(height: 4),
            Text(
              'Requested: ${_formatTimestamp(requestData['timestamp'])}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.check, color: Colors.green),
              onPressed: () => _acceptRequest(context, requestId, requestData, userData),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: () => _rejectRequest(requestId),
            ),
          ],
        ),
      ),
    );
  }

  void _acceptRequest(BuildContext context, String requestId, Map<String, dynamic> requestData, Map<String, dynamic> userData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Update request status
      await FirebaseFirestore.instance.collection('chat_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Create conversation
      final conversationId = _generateConversationId(
        requestData['senderId'],
        currentUser.uid,
      );

      await FirebaseFirestore.instance.collection('conversations').doc(conversationId).set({
        'participant1': requestData['senderId'],
        'participant2': currentUser.uid,
        'lastMessage': 'Chat started',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            receiverId: requestData['senderId'],
            receiverName: userData['fullName'] ?? 'User',
            receiverImage: userData['imageUrl'] ?? '',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request: $e')),
      );
    }
  }

  void _rejectRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('chat_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Reject error: $e');
    }
  }

  String _generateConversationId(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown time';
  }
}
