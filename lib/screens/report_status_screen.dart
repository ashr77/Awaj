import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportStatusScreen extends StatefulWidget {
  @override
  _ReportStatusScreenState createState() => _ReportStatusScreenState();
}

class _ReportStatusScreenState extends State<ReportStatusScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _reportsStream;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  bool _isIndexBuilding = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _loadReports() {
    setState(() {
      _reportsStream = _firestore
          .collection('reports')
          .where('userId', isEqualTo: _user!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
        if (error.toString().contains('index is building')) {
          setState(() => _isIndexBuilding = true);
        }
        throw error;
      });
    });
  }

  Future<void> _refreshReports() async {
    await _refreshKey.currentState?.show();
    setState(() => _isIndexBuilding = false);
    _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Report Status')),
        body: Center(child: Text('Please sign in to view your reports')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Status'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshReports,
            tooltip: 'Refresh reports',
          ),
        ],
      ),
      body: _isIndexBuilding
          ? _buildIndexBuildingView()
          : RefreshIndicator(
        key: _refreshKey,
        onRefresh: () async => _loadReports(),
        child: StreamBuilder<QuerySnapshot>(
          stream: _reportsStream,
          builder: (context, snapshot) {
            // Handle connection errors
            if (snapshot.hasError) {
              final error = snapshot.error.toString();

              // Special handling for index building
              if (error.contains('index is building')) {
                return _buildIndexBuildingView();
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 48),
                    SizedBox(height: 16),
                    Text('Error loading reports'),
                    SizedBox(height: 8),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            }

            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            // Empty state
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list, size: 72, color: Colors.blue),
                    SizedBox(height: 20),
                    Text('No reports found'),
                    SizedBox(height: 10),
                    Text('Submit a report to see status here'),
                  ],
                ),
              );
            }

            // Data loaded successfully
            final reports = snapshot.data!.docs;
            return ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final data = reports[index].data() as Map<String, dynamic>;
                final status = data['status'] ?? 'unknown';

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: _buildStatusIcon(status),
                    title: Text(data['reportName'] ?? 'Untitled Report'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${status.toUpperCase()}'),
                        if (data['feedback'] != null && data['feedback'].isNotEmpty)
                          Text('Feedback: ${data['feedback']}'),
                      ],
                    ),
                    trailing: Text(
                      data['createdAt'] != null && data['createdAt'] is Timestamp
                          ? _formatDate(data['createdAt'] as Timestamp)
                          : '',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () => _showReportDetails(context, data),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildIndexBuildingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Database is setting up...'),
          SizedBox(height: 10),
          Text('This may take 2-5 minutes'),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshReports,
            child: Text('Check Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icon(Icons.check_circle, color: Colors.green, size: 36);
      case 'declined':
        return Icon(Icons.cancel, color: Colors.red, size: 36);
      case 'pending':
        return Icon(Icons.access_time, color: Colors.orange, size: 36);
      default:
        return Icon(Icons.help, color: Colors.grey, size: 36);
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM dd, yyyy').format(date);
  }

  void _showReportDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report: ${data['reportName'] ?? 'N/A'}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('City: ${data['city'] ?? 'N/A'}'),
              Text('Office: ${data['office'] ?? 'N/A'}'),
              SizedBox(height: 12),
              Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(data['brief'] ?? 'No description'),
              SizedBox(height: 12),
              if (data['imageUrl'] != null)
                Image.network(data['imageUrl'], height: 200),
              SizedBox(height: 16),
              Text('Status: ${data['status']?.toUpperCase() ?? 'UNKNOWN'}',
                  style: TextStyle(
                      color: _getStatusColor(data['status']),
                      fontWeight: FontWeight.bold
                  )),
              if (data['feedback'] != null && data['feedback'].isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 12),
                    Text('Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(data['feedback']),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          )
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'declined': return Colors.red;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
