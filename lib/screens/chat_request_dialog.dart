import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatRequestDialog extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatRequestDialog({
    required this.receiverId,
    required this.receiverName,
  });

  @override
  _ChatRequestDialogState createState() => _ChatRequestDialogState();
}

class _ChatRequestDialogState extends State<ChatRequestDialog> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isSending = false;

  Future<void> _sendRequest() async {
    if (_messageController.text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _firestore.collection('chat_requests').add({
        'senderId': _currentUser!.uid,
        'receiverId': widget.receiverId,
        'message': _messageController.text,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${widget.receiverName}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Request Chat with ${widget.receiverName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Explain why you need help:'),
          SizedBox(height: 10),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'I need help with...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendRequest,
          child: _isSending
              ? CircularProgressIndicator(color: Colors.white)
              : Text('Send Request'),
        ),
      ],
    );
  }
}
