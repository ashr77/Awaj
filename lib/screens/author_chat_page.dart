import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_conversation_screen.dart';
import 'author_conversations_screen.dart';

class AuthorChatPage extends StatefulWidget {
  @override
  State<AuthorChatPage> createState() => _AuthorChatPageState();
}

class _AuthorChatPageState extends State<AuthorChatPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Chat Requests')),
        body: Center(child: Text('Please sign in to view requests')),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text('Chat Requests', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.background,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.forum, color: theme.colorScheme.primary),
            tooltip: 'View conversations',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AuthorConversationsScreen()),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: StreamBuilder<QuerySnapshot>(
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
                      Text('No pending requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }

              final requests = snapshot.data!.docs;

              return ListView.builder(
                padding: EdgeInsets.only(top: 12, bottom: 24),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final requestData = request.data() as Map<String, dynamic>;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(requestData['senderId']).get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return _AnimatedRequestCard(
                          child: ListTile(
                            leading: CircleAvatar(child: CircularProgressIndicator()),
                            title: Text('Loading...'),
                          ),
                        );
                      }

                      if (!userSnapshot.hasData) {
                        return _AnimatedRequestCard(
                          child: ListTile(
                            leading: CircleAvatar(child: Icon(Icons.error)),
                            title: Text('User not found'),
                          ),
                        );
                      }

                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

                      return _AnimatedRequestCard(
                        child: _buildRequestCard(
                          request.id,
                          requestData,
                          userData ?? {},
                          context,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
      String requestId,
      Map<String, dynamic> requestData,
      Map<String, dynamic> userData,
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 6,
      margin: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: userData['imageUrl'] != null
                  ? NetworkImage(userData['imageUrl'])
                  : null,
              child: userData['imageUrl'] == null ? Icon(Icons.person, size: 28) : null,
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData['fullName'] ?? 'Unknown User',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  SizedBox(height: 2),
                  Text(
                    requestData['message'],
                    style: TextStyle(fontSize: 15, color: theme.textTheme.bodyLarge?.color),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Requested: ${_formatTimestamp(requestData['timestamp'])}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _AnimatedActionIcon(
                  icon: Icons.check,
                  color: Colors.green,
                  tooltip: 'Accept',
                  onTap: () => _acceptRequest(context, requestId, requestData, userData),
                ),
                SizedBox(height: 8),
                _AnimatedActionIcon(
                  icon: Icons.close,
                  color: Colors.red,
                  tooltip: 'Reject',
                  onTap: () => _rejectRequest(requestId),
                ),
              ],
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
      await FirebaseFirestore.instance.collection('chat_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

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

class _AnimatedRequestCard extends StatefulWidget {
  final Widget child;
  const _AnimatedRequestCard({required this.child, Key? key}) : super(key: key);

  @override
  State<_AnimatedRequestCard> createState() => __AnimatedRequestCardState();
}

class __AnimatedRequestCardState extends State<_AnimatedRequestCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(milliseconds: 500), vsync: this);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _AnimatedActionIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _AnimatedActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_AnimatedActionIcon> createState() => __AnimatedActionIconState();
}

class __AnimatedActionIconState extends State<_AnimatedActionIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(milliseconds: 90), lowerBound: 0.0, upperBound: 0.1, vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateAndAct() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _animateAndAct,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(widget.icon, color: widget.color, size: 26),
          ),
        ),
      ),
    );
  }
}
