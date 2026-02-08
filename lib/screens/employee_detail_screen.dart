import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/login_record.dart';
import '../services/database_helper.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeDetailScreen({Key? key, required this.employee})
      : super(key: key);

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  List<LoginRecord> _loginRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoginRecords();
  }

  Future<void> _loadLoginRecords() async {
    setState(() {
      _isLoading = true;
    });

    final records =
        await DatabaseHelper.instance.getLoginsByEmployee(widget.employee.empId);

    setState(() {
      _loginRecords = records;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue,
                  child: Text(
                    widget.employee.firstName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.employee.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Employee ID: ${widget.employee.empId}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    widget.employee.status,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: widget.employee.status == 'Active'
                      ? Colors.green
                      : Colors.grey,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildInfoRow('Sex', widget.employee.sex ?? 'N/A'),
                    _buildInfoRow('Email', widget.employee.email ?? 'N/A'),
                    _buildInfoRow(
                      'Face Enrolled',
                      widget.employee.faceDescriptors != null &&
                              widget.employee.faceDescriptors!.isNotEmpty
                          ? 'Yes ✓'
                          : 'No',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadLoginRecords,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loginRecords.isEmpty
                    ? const Center(
                        child: Text('No attendance records'),
                      )
                    : ListView.builder(
                        itemCount: _loginRecords.length,
                        itemBuilder: (context, index) {
                          final record = _loginRecords[index];
                          return ListTile(
                            leading: Icon(
                              record.state == 'IN' ? Icons.login : Icons.logout,
                              color: record.state == 'IN'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(
                              '${record.state} - ${record.time}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('EEEE, MMMM d, yyyy')
                                  .format(DateTime.parse(record.date)),
                            ),
                            trailing: record.loginStatus != null
                                ? Chip(
                                    label: Text(
                                      record.loginStatus!,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
