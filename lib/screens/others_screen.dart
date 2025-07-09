import 'package:flutter/material.dart';
import 'report_status_screen.dart'; // <-- Import the new status page

class OthersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Others')),
      body: Center(
        child: ElevatedButton.icon(
          icon: Icon(Icons.assignment_turned_in),
          label: Text('Report Status'),
          style: ElevatedButton.styleFrom(
            minimumSize: Size(200, 48),
            textStyle: TextStyle(fontSize: 18),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReportStatusScreen()),
            );
          },
        ),
      ),
    );
  }
}
