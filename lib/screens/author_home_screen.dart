import 'package:flutter/material.dart';
import 'author_chat_page.dart';
import 'author_conversations_screen.dart';
import 'author_review_screen.dart'; // Import your report review screen

class AuthorHomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Define vibrant gradient colors
    final List<Color> requestGradient = [Color(0xFF00b4db), Color(0xFF0083b0)];
    final List<Color> convoGradient = [Color(0xFFf7971e), Color(0xFFffd200)];
    final List<Color> reportGradient = [Color(0xFF8E2DE2), Color(0xFF4A00E0)]; // Purple gradient

    return Scaffold(
      appBar: AppBar(
        title: Text('Author Home'),
        backgroundColor: Color(0xFF00b4db),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGradientButton(
                  context: context,
                  icon: Icons.mark_email_unread,
                  label: 'View Chat Requests',
                  gradientColors: requestGradient,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AuthorChatPage()),
                  ),
                ),
                SizedBox(height: 24),
                _buildGradientButton(
                  context: context,
                  icon: Icons.forum,
                  label: 'View Conversations',
                  gradientColors: convoGradient,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AuthorConversationsScreen()),
                  ),
                ),
                SizedBox(height: 24),
                _buildGradientButton(
                  context: context,
                  icon: Icons.report,
                  label: 'Report Requests',
                  gradientColors: reportGradient,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AuthorReviewScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
