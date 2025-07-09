import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_conversation_screen.dart';

class AuthorConversationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Your Chats')),
        body: Center(child: Text('Please sign in to view conversations')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Your Conversations')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('participant2', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot1) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .where('participant1', isEqualTo: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot2) {
              // Handle loading state
              if (snapshot1.connectionState == ConnectionState.waiting ||
                  snapshot2.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              // Handle errors
              if (snapshot1.hasError || snapshot2.hasError) {
                return Center(
                  child: Text('Error loading conversations'),
                );
              }

              // Combine results
              final docs1 = snapshot1.data?.docs ?? [];
              final docs2 = snapshot2.data?.docs ?? [];
              final allConversations = [...docs1, ...docs2];

              if (allConversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No conversations yet'),
                      Text('Accept chat requests to start conversations',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: allConversations.length,
                itemBuilder: (context, index) {
                  final conversation = allConversations[index];
                  final data = conversation.data() as Map<String, dynamic>;
                  final otherUserId = data['participant1'] == currentUser.uid
                      ? data['participant2']
                      : data['participant1'];

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
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
