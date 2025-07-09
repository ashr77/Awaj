import 'package:flutter/material.dart';
import 'report_screen.dart';
import 'chat_screen.dart';
import 'post_screen.dart';
import 'about_me_screen.dart';
import 'others_screen.dart'; // <-- Import the new page
import 'user_conversations_screen.dart';

class MainAppScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Main Menu')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => SubmitReportScreen())),
              child: Text('Report Problem'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => UserConversationsScreen())),
              child: Text('Chat'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => PostScreen())),
              child: Text('Post'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => AboutMeScreen())),
              child: Text('About Me'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => OthersScreen())),
              child: Text('Others'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
