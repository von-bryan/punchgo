import 'package:flutter/material.dart';
import 'employee_list_screen.dart';
import 'attendance_screen.dart';
import 'time_in_out_screen.dart';
import 'profile_screen.dart';
import 'attendance_history_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';

class HomeScreen extends StatefulWidget {
  final int? initialTabIndex;
  const HomeScreen({Key? key, this.initialTabIndex}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  bool _isAdmin = false;
  bool _isLoading = true;
  int? _empId;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex ?? 0;
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final empId = await AuthService.getEmpId();
    if (empId != null) {
      final isAdmin = await DatabaseHelper.instance.isAdmin(empId);
      setState(() {
        _isAdmin = isAdmin;
        _empId = empId;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _empId = null;
      });
    }
  }

  List<Widget> get _screens {
    if (_isAdmin) {
      return const [
        AttendanceScreen(),
        EmployeeListScreen(),
        SettingsScreen(),
        ProfileScreen(),
      ];
    } else {
      return [
        const TimeInOutScreen(),
        if (_empId != null) AttendanceHistoryScreen(empId: _empId!) else const SizedBox.shrink(),
        const ProfileScreen(),
      ];
    }
  }

  List<NavigationDestination> get _destinations {
    if (_isAdmin) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.access_time),
          label: 'Attendance',
        ),
        NavigationDestination(
          icon: Icon(Icons.people),
          label: 'Employees',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
        NavigationDestination(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    } else {
      return const [
        NavigationDestination(
          icon: Icon(Icons.fingerprint),
          label: 'Time In/Out',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          label: 'DTR',
        ),
        NavigationDestination(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _selectedIndex == (_isAdmin ? 3 : 1)
          ? null
          : AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ],
            ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _destinations,
      ),
    );
  }
}
