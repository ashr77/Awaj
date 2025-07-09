import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class PostScreen extends StatefulWidget {
  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final TextEditingController _postController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.User? _currentUser = auth.FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isLoading = false;
  bool _showMyFeed = false;
  bool _isAnonymous = false;

  Future<void> _createPost() async {
    if (_postController.text.isEmpty && _imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_imageFile != null) {
        final supabase = Supabase.instance.client;
        final file = File(_imageFile!.path);
        final filePath = 'posts/${_currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}';

        await supabase.storage
            .from('imageandfiles')
            .upload(filePath, file);

        imageUrl = supabase.storage
            .from('imageandfiles')
            .getPublicUrl(filePath);
      }

      await _firestore.collection('posts').add({
        'userId': _isAnonymous ? null : _currentUser!.uid,
        'userName': _isAnonymous
            ? 'Anonymous'
            : (_currentUser!.displayName ?? 'Anonymous'),
        'userImage': _isAnonymous ? null : _currentUser!.photoURL,
        'text': _postController.text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'downvotes': 0,
        'comments': 0,
        'isAnonymous': _isAnonymous,
      });

      _postController.clear();
      setState(() {
        _imageFile = null;
        _isAnonymous = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('Community Posts'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showCreatePostDialog(context),
            tooltip: 'Create new post',
          ),
          IconButton(
            icon: Icon(_showMyFeed ? Icons.public : Icons.person_pin),
            tooltip: _showMyFeed ? 'Show All Posts' : 'Show My Feed',
            onPressed: () {
              setState(() {
                _showMyFeed = !_showMyFeed;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        key: ValueKey(_showMyFeed),
        stream: _showMyFeed && user != null
            ? _firestore
            .collection('posts')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots()
            : _firestore
            .collection('posts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs;

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add, size: 64, color: Colors.blue),
                  SizedBox(height: 16),
                  Text(_showMyFeed
                      ? 'You have not posted anything yet.'
                      : 'No posts yet'),
                  if (!_showMyFeed) Text('Be the first to share something!'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>;
              return PostItem(
                postId: post.id,
                data: data,
                isOwner: (data['userId'] ?? '') == (user?.uid ?? ''),
                onEdit: () => _showEditPostDialog(context, post.id, data),
                onDelete: () => _deletePost(post.id),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Create Post'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _postController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'What do you want to share?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (_imageFile != null)
                      Image.file(File(_imageFile!.path), height: 150),
                    TextButton.icon(
                      icon: Icon(Icons.image),
                      label: Text('Add Image'),
                      onPressed: _pickImage,
                    ),
                    CheckboxListTile(
                      title: Text('Post Anonymously'),
                      value: _isAnonymous,
                      onChanged: (value) {
                        setDialogState(() {
                          _isAnonymous = value!;
                        });
                        setState(() {
                          _isAnonymous = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _createPost();
                  },
                  child: Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditPostDialog(BuildContext context, String postId, Map<String, dynamic> data) {
    final TextEditingController editController = TextEditingController(text: data['text'] ?? '');
    bool isAnonymous = data['isAnonymous'] ?? false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Post'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Edit your post',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    title: Text('Post Anonymously'),
                    value: isAnonymous,
                    onChanged: (value) {
                      setDialogState(() {
                        isAnonymous = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _firestore.collection('posts').doc(postId).update({
                      'text': editController.text,
                      'isAnonymous': isAnonymous,
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Post deleted')),
    );
  }
}

class PostItem extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PostItem({
    required this.postId,
    required this.data,
    this.isOwner = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  _PostItemState createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.User? _currentUser = auth.FirebaseAuth.instance.currentUser;
  final TextEditingController _commentController = TextEditingController();
  bool _showComments = false;

  Future<void> _vote(int value) async {
    if (_currentUser == null) return;

    final voteRef = _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('votes')
        .doc(_currentUser!.uid);

    final voteDoc = await voteRef.get();
    final currentVote = voteDoc.exists ? voteDoc.get('value') : 0;

    int upvoteChange = 0;
    int downvoteChange = 0;

    if (value == 1) {
      if (currentVote == 1) {
        upvoteChange = -1;
      } else {
        upvoteChange = 1;
        downvoteChange = currentVote == -1 ? -1 : 0;
      }
    } else {
      if (currentVote == -1) {
        downvoteChange = -1;
      } else {
        downvoteChange = 1;
        upvoteChange = currentVote == 1 ? -1 : 0;
      }
    }

    await voteRef.set({'value': value});
    await _firestore.collection('posts').doc(widget.postId).update({
      'upvotes': FieldValue.increment(upvoteChange),
      'downvotes': FieldValue.increment(downvoteChange),
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty || _currentUser == null) return;

    try {
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': _currentUser!.uid,
        'userName': _currentUser!.displayName ?? 'Anonymous',
        'userImage': _currentUser!.photoURL,
        'text': _commentController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('posts').doc(widget.postId).update({
        'comments': FieldValue.increment(1),
      });

      _commentController.clear();
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isOwner)
                ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onEdit?.call();
                  },
                ),
              if (widget.isOwner)
                ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Delete'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete?.call();
                  },
                ),
              ListTile(
                leading: Icon(Icons.flag),
                title: Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reported. Thank you!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAnonymous = widget.data['isAnonymous'] == true;
    return Card(
      margin: EdgeInsets.all(8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: !isAnonymous && widget.data['userImage'] != null
                      ? NetworkImage(widget.data['userImage'])
                      : null,
                  child: isAnonymous || widget.data['userImage'] == null
                      ? Icon(Icons.person)
                      : null,
                ),
                SizedBox(width: 10),
                Text(
                  widget.data['isAnonymous'] == true
                      ? 'Anonymous'
                      : 'User ID: ${widget.data['userId'] ?? 'N/A'}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                Spacer(),
                Text(
                  _formatTimestamp(widget.data['timestamp']),
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.more_vert),
                  onPressed: () => _showMoreOptions(context),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (widget.data['text'] != null && widget.data['text'].isNotEmpty)
              Text(widget.data['text']),
            SizedBox(height: 12),
            if (widget.data['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.data['imageUrl'],
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.thumb_up, color: Colors.blue),
                      onPressed: () => _vote(1),
                    ),
                    Text('${widget.data['upvotes'] ?? 0}'),
                    SizedBox(width: 16),
                    IconButton(
                      icon: Icon(Icons.thumb_down, color: Colors.red),
                      onPressed: () => _vote(-1),
                    ),
                    Text('${widget.data['downvotes'] ?? 0}'),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.comment),
                      onPressed: () => setState(() => _showComments = !_showComments),
                    ),
                    Text('${widget.data['comments'] ?? 0}'),
                  ],
                ),
              ],
            ),
            if (_showComments) ...[
              SizedBox(height: 16),
              _buildCommentInput(),
              SizedBox(height: 16),
              _buildCommentsList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.send),
          onPressed: _addComment,
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data!.docs;

        if (comments.isEmpty) {
          return Text('No comments yet');
        }

        return Column(
          children: comments.map((doc) {
            final comment = doc.data() as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: comment['userImage'] != null
                    ? NetworkImage(comment['userImage'])
                    : null,
                child: comment['userImage'] == null
                    ? Icon(Icons.person)
                    : null,
              ),
              title: Text(comment['userName'] ?? 'Anonymous'),
              subtitle: Text(comment['text']),
              trailing: Text(
                _formatTimestamp(comment['timestamp']),
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}
