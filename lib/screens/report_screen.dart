import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubmitReportScreen extends StatefulWidget {
  @override
  _SubmitReportScreenState createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportNameController = TextEditingController();
  final _briefController = TextEditingController();
  String? _selectedCity;
  String? _selectedOffice;
  XFile? _imageFile;
  bool _isLoading = false;

  final List<String> _cities = ['City A', 'City B', 'City C'];
  final Map<String, List<String>> _offices = {
    'City A': ['Office A1', 'Office A2', 'Office A3'],
    'City B': ['Office B1', 'Office B2', 'Office B3'],
    'City C': ['Office C1', 'Office C2', 'Office C3'],
  };

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Upload image to Supabase if exists
        String? imageUrl;
        if (_imageFile != null) {
          final supabase = Supabase.instance.client;
          final file = File(_imageFile!.path);
          final filePath = 'reports/${user.uid}/${DateTime.now().millisecondsSinceEpoch}';

          await supabase.storage
              .from('imageandfiles')
              .upload(filePath, file);

          imageUrl = supabase.storage
              .from('imageandfiles')
              .getPublicUrl(filePath);
        }

        // Save report to Firestore
        await FirebaseFirestore.instance.collection('reports').add({
          'userId': user.uid,
          'userEmail': user.email,
          'reportName': _reportNameController.text,
          'city': _selectedCity,
          'office': _selectedOffice,
          'brief': _briefController.text,
          'imageUrl': imageUrl,
          'status': 'pending', // pending, accepted, declined
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report submitted successfully!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Submit Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _reportNameController,
                decoration: InputDecoration(labelText: 'Report Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: InputDecoration(labelText: 'City'),
                items: _cities.map((city) {
                  return DropdownMenuItem(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value;
                    _selectedOffice = null;
                  });
                },
                validator: (value) => value == null ? 'Select a city' : null,
              ),
              SizedBox(height: 20),
              if (_selectedCity != null)
                DropdownButtonFormField<String>(
                  value: _selectedOffice,
                  decoration: InputDecoration(labelText: 'Office'),
                  items: _offices[_selectedCity]!.map((office) {
                    return DropdownMenuItem(
                      value: office,
                      child: Text(office),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedOffice = value),
                  validator: (value) => value == null ? 'Select an office' : null,
                ),
              SizedBox(height: 20),
              TextFormField(
                controller: _briefController,
                decoration: InputDecoration(labelText: 'Brief Description'),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 20),
              _imageFile == null
                  ? TextButton.icon(
                icon: Icon(Icons.upload),
                label: Text('Add Photo (Optional)'),
                onPressed: _pickImage,
              )
                  : Column(
                children: [
                  Image.file(File(_imageFile!.path), height: 100),
                  TextButton(
                    onPressed: _pickImage,
                    child: Text('Change Photo'),
                  ),
                ],
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
