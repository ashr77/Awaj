import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_request_dialog.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat with Authorities')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .where('userType', whereIn: ['author', 'authority'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No authorities available'));
          }

          final authors = snapshot.data!.docs;

          return ListView.builder(
            itemCount: authors.length,
            itemBuilder: (context, index) {
              final author = authors[index];
              final authorData = author.data() as Map<String, dynamic>;
              final authorId = author.id;

              return _buildAuthorTile(authorId, authorData, context);
            },
          );
        },
      ),
    );
  }

  Widget _buildAuthorTile(String authorId, Map<String, dynamic> authorData, BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: authorData['imageUrl'] != null
            ? NetworkImage(authorData['imageUrl'])
            : null,
        child: authorData['imageUrl'] == null
            ? Icon(Icons.person)
            : null,
      ),
      title: Text(authorData['fullName'] ?? 'Authority'),
      subtitle: Text(authorData['userType'] == 'authority'
          ? 'Government Authority'
          : 'Verified Author'),
      trailing: Icon(Icons.chat),
      onTap: () => _showRequestDialog(context, authorId, authorData),
    );
  }

  void _showRequestDialog(BuildContext context, String authorId, Map<String, dynamic> authorData) {
    showDialog(
      context: context,
      builder: (context) => ChatRequestDialog(
        receiverId: authorId,
        receiverName: authorData['fullName'] ?? 'Authority',
      ),
    );
  }
}
