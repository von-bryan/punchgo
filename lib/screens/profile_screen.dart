import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../models/employee.dart';
import '../config/database_config.dart';
import 'face_enrollment_screen.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _changePassword() async {
    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (value.length < 6) {
                      return 'Minimum 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final empId = await AuthService.getEmpId();
                  if (empId != null) {
                    final success =
                        await DatabaseHelper.instance.changePassword(
                      empId,
                      oldPasswordController.text,
                      newPasswordController.text,
                    );
                    Navigator.pop(context, success);
                  }
                }
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (result == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to change password. Check current password.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Employee? _employee;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final empId = await AuthService.getEmpId();
    if (empId != null) {
      final employee = await DatabaseHelper.instance.getEmployee(empId);
      setState(() {
        _employee = employee;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildAvatar() {
    final path = _employee?.photoPath;
    // Debug output
    print('[Avatar] Using photoPath: $path');
    if (path != null && path.isNotEmpty) {
      String avatarUrl;
      if (path.startsWith('http') || path.startsWith('https')) {
        avatarUrl = path;
      } else if (path.startsWith('file:/') || path.startsWith('/')) {
        // Local file
        return CircleAvatar(
          radius: 50,
          backgroundImage: FileImage(
            path.startsWith('file://')
                ? File(path.replaceFirst('file://', ''))
                : File(path),
          ),
        );
      } else {
        avatarUrl = '${ServerConfig.baseUrl}/uploads/punchgo/$path';
      }
      print('[Avatar] Final avatar URL: $avatarUrl');
      return CircleAvatar(
        radius: 50,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 50,
      child: Icon(Icons.person, size: 50),
    );
  }

  Future<void> _enrollFace() async {
    if (_employee == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FaceEnrollmentScreen(employee: _employee!),
      ),
    );

    // HomeScreen navigation is handled by FaceEnrollmentScreen
    // No need to reload here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade700, Colors.blue.shade400],
          ),
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : _employee == null
                  ? const Text('Error loading profile')
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildAvatar(),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  _employee!.fullName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Employee ID: ${_employee!.empId}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Chip(
                                label: Text(
                                  _employee!.status,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: _employee!.status == 'Active'
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.person),
                                title: const Text('Personal Information'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_employee!.sex != null)
                                      Text('Sex: ${_employee!.sex}'),
                                    if (_employee!.birthDate != null &&
                                        _employee!.birthDate!.isNotEmpty)
                                      Text('Birthday: '
                                          '${_employee!.birthDate != null && _employee!.birthDate!.isNotEmpty ? DateFormat('MM/dd/yyyy').format(DateTime.tryParse(_employee!.birthDate!) ?? DateTime(2000, 1, 1)) : ''}'),
                                    if (_employee!.email != null)
                                      Text('Email: ${_employee!.email}'),
                                  ],
                                ),
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.lock),
                                title: const Text('Change Password'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _changePassword,
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.face),
                                title: const Text('Face Recognition'),
                                subtitle: Text(
                                  _employee!.faceDescriptors != null &&
                                          _employee!.faceDescriptors!.isNotEmpty
                                      ? 'Enrolled ✓'
                                      : 'Not enrolled',
                                ),
                                trailing: Icon(
                                  _employee!.faceDescriptors != null &&
                                          _employee!.faceDescriptors!.isNotEmpty
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _employee!.faceDescriptors != null &&
                                          _employee!.faceDescriptors!.isNotEmpty
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                onTap: _enrollFace,
                              ),
                              if (_employee!.faceDescriptors != null &&
                                  _employee!.faceDescriptors!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: _enrollFace,
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Re-enroll Face'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 48),
                                    ),
                                  ),
                                ),
                              if (_employee!.faceDescriptors == null ||
                                  _employee!.faceDescriptors!.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: _enrollFace,
                                    icon: const Icon(Icons.fingerprint),
                                    label: const Text('Enroll Face Now'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 48),
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}
