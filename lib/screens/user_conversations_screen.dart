import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_conversation_screen.dart';
import 'chat_screen.dart';

class UserConversationsScreen extends StatefulWidget {
  @override
  _UserConversationsScreenState createState() => _UserConversationsScreenState();
}

class _UserConversationsScreenState extends State<UserConversationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Your Chats')),
        body: Center(child: Text('Please sign in to view conversations')),
      );
    }

    final uid = _currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text('Your Conversations')),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.person_add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen()),
        ),
        tooltip: 'Chat with new authority',
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('conversations')
            .where('participant1', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot1) {
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('conversations')
                .where('participant2', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot2) {
              if (snapshot1.connectionState == ConnectionState.waiting ||
                  snapshot2.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot1.hasError || snapshot2.hasError) {
                return Center(
                  child: Text('Error loading conversations'),
                );
              }

              final docs1 = snapshot1.data?.docs ?? [];
              final docs2 = snapshot2.data?.docs ?? [];

              // Combine and remove duplicates (if any)
              final allDocs = {...docs1, ...docs2}.toList();

              if (allDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No conversations yet'),
                      Text('Start a chat with an authority', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: allDocs.length,
                itemBuilder: (context, index) {
                  final conversation = allDocs[index];
                  final data = conversation.data() as Map<String, dynamic>;
                  final otherUserId = data['participant1'] == uid
                      ? data['participant2']
                      : data['participant1'];

                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(otherUserId).get(),
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

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userData?['imageUrl'] != null
                              ? NetworkImage(userData!['imageUrl'])
                              : null,
                          child: userData?['imageUrl'] == null ? Icon(Icons.person) : null,
                        ),
                        title: Text(userData?['fullName'] ?? 'Unknown User'),
                        subtitle: Text('Last message: ${data['lastMessage'] ?? ''}'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(
                                receiverId: otherUserId,
                                receiverName: userData?['fullName'] ?? 'User',
                                receiverImage: userData?['imageUrl'] ?? '',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
