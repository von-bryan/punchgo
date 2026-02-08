import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/login_record.dart';
import '../services/database_helper.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final int empId;
  const AttendanceHistoryScreen({Key? key, required this.empId})
      : super(key: key);

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  List<LoginRecord> _records = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() => _loading = true);
    final dateStr =
        DateFormat('yyyy-MM-dd').format(_selectedDate); // keep for DB query
    _records = await DatabaseHelper.instance
        .getLoginRecordsByDate(widget.empId, dateStr);
    setState(() => _loading = false);
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DTR'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Date: ${DateFormat('MM/dd/yyyy').format(_selectedDate)}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          tooltip: 'Pick Date',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _loading
                        ? const Center(
                            child: CircularProgressIndicator.adaptive())
                        : _records.isEmpty
                            ? const Center(child: Text('No records found'))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _records.length,
                                itemBuilder: (context, idx) {
                                  final rec = _records[idx];
                                  DateTime? parsedTime;
                                  try {
                                    parsedTime =
                                        DateFormat('HH:mm:ss').parse(rec.time);
                                  } catch (_) {
                                    parsedTime = null;
                                  }
                                  final formattedTime = parsedTime != null
                                      ? DateFormat('h:mm a').format(parsedTime)
                                      : rec.time;
                                  return Card(
                                    color: Colors.white,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 8),
                                    elevation: 2,
                                    child: ListTile(
                                      leading: Icon(
                                        rec.state == '1'
                                            ? Icons.login
                                            : Icons.logout,
                                        color: rec.state == '1'
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      title: Text(
                                        rec.state == '1'
                                            ? 'Time In'
                                            : 'Time Out',
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                          '$formattedTime - ${rec.loginStatus}',
                                          style: theme.textTheme.bodyMedium),
                                    ),
                                  );
                                },
                              ),
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
