import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/main_app_screen.dart';

void main() {
  print('Hello, World!');
}


void main() async {  WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp();

// Initialize Supabase with your credentials
await Supabase.initialize(
url: 'https://vtgdgmpvgsdpmzczoakc.supabase.co',
anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0Z2RnbXB2Z3NkcG16Y3pvYWtjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA5Mzk1MzksImV4cCI6MjA2NjUxNTUzOX0.lyEROVVDt9TPbAB_ZuhKJ2SCqMN-5dsLUf7Fk-r4Ufk',
);

runApp( MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth System',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/signup': (context) => SignUpScreen(),
        '/signin': (context) => SignInScreen(),
        '/main': (context) => MainAppScreen(),
      },
    );
  }
}
