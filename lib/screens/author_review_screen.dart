import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AuthorReviewScreen extends StatefulWidget {
  @override
  _AuthorReviewScreenState createState() => _AuthorReviewScreenState();
}

class _AuthorReviewScreenState extends State<AuthorReviewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _feedbackController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _updateReportStatus(
      String reportId, String status, String feedback, String userId) async {
    setState(() => _isLoading = true);

    try {
      // Update report status
      await _firestore.collection('reports').doc(reportId).update({
        'status': status,
        'feedback': feedback,
        'reviewedBy': _currentUser?.email,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Send feedback to user
      await _firestore.collection('users').doc(userId).collection('feedbacks').add({
        'reportId': reportId,
        'status': status,
        'feedback': feedback,
        'reviewedBy': _currentUser?.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report $status successfully'),
          backgroundColor: status == 'accepted' ? Colors.green : Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Author Review')),
        body: Center(
          child: Text('Please sign in to access this feature',
              style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Review'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh reports',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('reports')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Error loading reports',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 72, color: Colors.green),
                  SizedBox(height: 20),
                  Text(
                    'No pending reports',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text('All reports have been reviewed'),
                ],
              ),
            );
          }

          final reports = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final data = report.data() as Map<String, dynamic>;
              final reportId = report.id;

              return _buildReportCard(data, reportId);
            },
          );
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> data, String reportId) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data['reportName'] ?? 'Untitled Report',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text('PENDING', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.orange,
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildDetailRow('Location', '${data['city'] ?? 'N/A'}, ${data['office'] ?? 'N/A'}'),
            _buildDetailRow('Submitted by', data['userEmail'] ?? 'Unknown user'),
            _buildDetailRow('Date', _formatTimestamp(data['createdAt'])),
            SizedBox(height: 12),
            Text('Description:', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text(
              data['brief'] ?? 'No description provided',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 12),
            if (data['imageUrl'] != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  data['imageUrl'],
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.check, size: 20),
                    label: Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _showFeedbackDialog(
                        reportId, 'accepted', data['userId']),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.close, size: 20),
                    label: Text('Decline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _showFeedbackDialog(
                        reportId, 'declined', data['userId']),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
    }
    return 'Unknown date';
  }

  void _showFeedbackDialog(
      String reportId, String status, String userId) {
    _feedbackController.clear();
    final title = status == 'accepted' ? 'Accept Report' : 'Decline Report';
    final color = status == 'accepted' ? Colors.green : Colors.red;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: TextStyle(color: color)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add feedback for the user:'),
              SizedBox(height: 12),
              TextField(
                controller: _feedbackController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Feedback',
                  hintText: 'Optional feedback...',
                ),
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              onPressed: () {
                Navigator.pop(context);
                _updateReportStatus(
                  reportId,
                  status,
                  _feedbackController.text,
                  userId,
                );
              },
              child: Text(status == 'accepted' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );
  }
}
