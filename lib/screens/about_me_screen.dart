import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AboutMeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildPlaceholder('Please sign in');

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData == null) return _buildPlaceholder('User data not found');

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                flexibleSpace: FlexibleSpaceBar(
                  background: userData['imageUrl'] != null
                      ? Image.network(
                    userData['imageUrl'],
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.person, size: 100, color: Colors.grey),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Profile Information'),
                      _buildInfoCard(
                        children: [
                          _buildInfoRow('Full Name', userData['fullName']),
                          _buildInfoRow('Email', userData['email']),
                          _buildInfoRow('NID', userData['nid']),
                          _buildInfoRow('Phone', userData['phone']),
                          _buildUserTypeBadge(userData['userType']),
                        ],
                      ),
                      SizedBox(height: 20),
                      _buildSectionHeader('Account Details'),
                      _buildInfoCard(
                        children: [
                          _buildInfoRow('Account Created', _formatTimestamp(userData['createdAt'])),
                          _buildInfoRow('User ID', user.uid),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder(String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey[800],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'Not provided',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeBadge(String? userType) {
    final isAuthority = userType == 'authority';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Text(
            'User Type: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isAuthority ? Colors.blue[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAuthority ? Colors.blue : Colors.green,
                width: 1,
              ),
            ),
            child: Text(
              userType?.toUpperCase() ?? 'USER',
              style: TextStyle(
                color: isAuthority ? Colors.blue[800] : Colors.green[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown';
  }
}
