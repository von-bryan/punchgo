import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyEmpId = 'emp_id';
  static const String _keyEmpName = 'emp_name';

  // Save login session
  static Future<void> saveSession(int empId, String empName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setInt(_keyEmpId, empId);
    await prefs.setString(_keyEmpName, empName);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Get logged in emp_id
  static Future<int?> getEmpId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyEmpId);
  }

  // Get logged in emp_name
  static Future<String?> getEmpName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmpName);
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
