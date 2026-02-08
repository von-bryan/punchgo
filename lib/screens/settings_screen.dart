import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/employee.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Employee> _employees = [];
  Set<int> _adminIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final employees = await DatabaseHelper.instance.getAllEmployees();
    final adminIds = <int>{};

    for (var emp in employees) {
      final isAdmin = await DatabaseHelper.instance.isAdmin(emp.empId);
      if (isAdmin) {
        adminIds.add(emp.empId);
      }
    }

    setState(() {
      _employees = employees;
      _adminIds = adminIds;
      _isLoading = false;
    });
  }

  Future<void> _toggleAdmin(Employee employee) async {
    final isCurrentlyAdmin = _adminIds.contains(employee.empId);

    if (isCurrentlyAdmin) {
      final success = await DatabaseHelper.instance.removeAdmin(employee.empId);
      if (success) {
        setState(() {
          _adminIds.remove(employee.empId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${employee.fullName} removed from admins')),
          );
        }
      }
    } else {
      final success = await DatabaseHelper.instance.addAdmin(employee.empId, 1);
      if (success) {
        setState(() {
          _adminIds.add(employee.empId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${employee.fullName} is now an admin')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              const Text(
                                'Manage Administrators',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Grant or revoke admin access to employees',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._employees.map((employee) {
                    final isAdmin = _adminIds.contains(employee.empId);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isAdmin ? Colors.blue : Colors.grey.shade400,
                          child: Text(
                            employee.firstName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(employee.fullName),
                        subtitle: Text('ID: ${employee.empId}'),
                        trailing: Switch(
                          value: isAdmin,
                          onChanged: (value) => _toggleAdmin(employee),
                          activeColor: Colors.blue.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
