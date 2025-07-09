import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _nidController = TextEditingController();
  final _phoneController = TextEditingController();

  XFile? _imageFile;
  bool _isLoading = false;
  String? _nidError;

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _nidError = null;
      });

      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final nid = _nidController.text.trim();

      try {
        // Check NID uniqueness
        final nidDoc = await _firestore.collection('nids').doc(nid).get();
        if (nidDoc.exists) {
          setState(() => _nidError = 'NID already registered');
          setState(() => _isLoading = false);
          return;
        }

        // Create Firebase user
        UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Upload image to Supabase if exists
        String? imageUrl;
        if (_imageFile != null) {
          try {
            final supabase = Supabase.instance.client;
            final file = File(_imageFile!.path);
            final filePath =
                '${userCredential.user!.uid}/${DateTime.now().millisecondsSinceEpoch}';

            // Upload the file directly
            await supabase.storage
                .from('imageandfiles')
                .upload(filePath, file);

            imageUrl = supabase.storage
                .from('imageandfiles')
                .getPublicUrl(filePath);
          } catch (e) {
            debugPrint('Image upload error: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image upload failed: ${e.toString()}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        // Batch write for atomic operations
        WriteBatch batch = _firestore.batch();

        // Save user data
        final userRef = _firestore.collection('users')
            .doc(userCredential.user!.uid);
        batch.set(userRef, {
          'fullName': _fullNameController.text.trim(),
          'email': email,
          'nid': nid,
          'phone': _phoneController.text.trim(),
          'userType': 'user',
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Reserve NID
        final nidRef = _firestore.collection('nids').doc(nid);
        batch.set(nidRef, {
          'userId': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();

        // Show success and redirect to sign in
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/signin');
      } catch (e) {
        String message = 'Sign-up failed';
        if (e is FirebaseAuthException) {
          message = e.message ?? 'Authentication error';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _nidController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Image Section
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: _imageFile == null
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : ClipOval(
                        child: Image.file(
                          File(_imageFile!.path),
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _pickImage,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Add Profile Photo',
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 24),

              // Form Fields
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                value!.contains('@') ? null : 'Invalid email',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nidController,
                decoration: InputDecoration(
                  labelText: 'NID',
                  prefixIcon: const Icon(Icons.badge),
                  errorText: _nidError,
                ),
                validator: (value) =>
                value!.length < 5 ? 'Invalid NID' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) =>
                value!.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) =>
                value != _passwordController.text ? 'Passwords don\'t match' : null,
              ),
              const SizedBox(height: 32),

              // Sign Up Button
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : const Text(
                  'SIGN UP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
