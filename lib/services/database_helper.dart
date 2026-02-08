import 'package:mysql1/mysql1.dart';
import '../models/employee.dart';
import '../models/login_record.dart';
import '../models/security_model.dart';
import '../config/database_config.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
    Future<List<LoginRecord>> getLoginRecordsByDate(int empId, String date) async {
      final conn = await instance.connection;
      var results = await conn.query(
        'SELECT * FROM login WHERE emp_id = ? AND date = ? ORDER BY time ASC',
        [empId, date],
      );
      return results.map((row) => LoginRecord.fromMap(_rowToMap(row))).toList();
    }
  static final DatabaseHelper instance = DatabaseHelper._init();
  MySqlConnection? _connection;

  DatabaseHelper._init();

  Future<MySqlConnection> get connection async {
    if (_connection != null) return _connection!;
    _connection = await _initDB();
    return _connection!;
  }

  Future<MySqlConnection> _initDB() async {
    try {
      final conn = await MySqlConnection.connect(
        ConnectionSettings(
          host: DatabaseConfig.host,
          port: DatabaseConfig.port,
          user: DatabaseConfig.user,
          password: DatabaseConfig.password,
          db: DatabaseConfig.database,
          timeout: Duration(seconds: DatabaseConfig.timeout),
        ),
      );

      print('✅ Connected to MySQL database at ${DatabaseConfig.host}');
      
      // Tables should already exist on your server
      // But we can ensure they exist with this check
      await _ensureTablesExist(conn);
      
      return conn;
    } catch (e) {
      print('❌ Error connecting to database: $e');
      rethrow;
    }
  }

  Future<void> _ensureTablesExist(MySqlConnection conn) async {
    try {
      // Check if info table exists
      var result = await conn.query(
        "SHOW TABLES LIKE 'info'",
      );
      
      if (result.isEmpty) {
        print('Creating info table...');
        await conn.query('''
          CREATE TABLE info (
            emp_code INT AUTO_INCREMENT PRIMARY KEY,
            emp_id INT NOT NULL,
            isAgency VARCHAR(10),
            alias VARCHAR(100),
            surname VARCHAR(100) NOT NULL,
            first_name VARCHAR(100) NOT NULL,
            middle_name VARCHAR(100),
            qualifier VARCHAR(50),
            salutation VARCHAR(50),
            sex VARCHAR(10),
            birth_date DATE,
            birth_place VARCHAR(100),
            marital_status VARCHAR(50),
            religion VARCHAR(50),
            citizenship VARCHAR(50),
            acr_no VARCHAR(50),
            blood_type VARCHAR(10),
            reference_id VARCHAR(50),
            no_of_dependents INT,
            head_of_family VARCHAR(10),
            status VARCHAR(20) DEFAULT 'Active',
            has_other_employer VARCHAR(10),
            email VARCHAR(100),
            email_id VARCHAR(100),
            case_sensitive VARCHAR(10),
            face_descriptors TEXT,
            gmail_id VARCHAR(100),
            photo_path VARCHAR(255)
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
        print('✅ info table created');
      }

      // Check if login table exists
      result = await conn.query(
        "SHOW TABLES LIKE 'login'",
      );
      
      if (result.isEmpty) {
        print('Creating login table...');
        await conn.query('''
          CREATE TABLE login (
            login_id INT AUTO_INCREMENT PRIMARY KEY,
            emp_id INT NOT NULL,
            time TIME NOT NULL,
            date DATE NOT NULL,
            state VARCHAR(10) NOT NULL,
            sync_id INT,
            login_status VARCHAR(50),
            swipe VARCHAR(50),
            original_time TIME,
            changed_by VARCHAR(100),
            change_on DATETIME,
            remarks TEXT,
            INDEX idx_emp_date (emp_id, date)
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
        print('✅ login table created');
      }

      // Check if security table exists
      result = await conn.query(
        "SHOW TABLES LIKE 'security'",
      );
      
      if (result.isEmpty) {
        print('Creating security table...');
        await conn.query('''
          CREATE TABLE security (
            security_id INT AUTO_INCREMENT PRIMARY KEY,
            emp_id INT NOT NULL UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            last_password_change DATETIME,
            password_reset_token VARCHAR(255),
            login_attempts INT DEFAULT 0,
            last_login_date DATE,
            last_login_time TIME,
            INDEX idx_emp_id (emp_id),
            FOREIGN KEY (emp_id) REFERENCES info(emp_id) ON DELETE CASCADE
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
        print('✅ security table created');
      }

      // Check if admin table exists
      result = await conn.query(
        "SHOW TABLES LIKE 'admin'",
      );
      
      if (result.isEmpty) {
        print('Creating admin table...');
        try {
          await conn.query('''
            CREATE TABLE admin (
              admin_id INT AUTO_INCREMENT PRIMARY KEY,
              emp_id INT NOT NULL UNIQUE,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              created_by INT,
              INDEX idx_emp_id (emp_id),
              FOREIGN KEY (emp_id) REFERENCES info(emp_id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
          ''');
          print('✅ admin table created');
        } catch (adminError) {
          print('❌ Error creating admin table: $adminError');
        }
      } else {
        print('✅ admin table already exists');
      }

      // Check if face_enrollments table exists
      result = await conn.query(
        "SHOW TABLES LIKE 'face_enrollments'",
      );
      
      if (result.isEmpty) {
        print('Creating face_enrollments table...');
        try {
          await conn.query('''
            CREATE TABLE face_enrollments (
              face_id INT AUTO_INCREMENT PRIMARY KEY,
              emp_id INT NOT NULL,
              photo_path VARCHAR(255) NOT NULL,
              face_descriptors TEXT,
              enrolled_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              is_active BOOLEAN DEFAULT TRUE,
              INDEX idx_emp_id (emp_id),
              INDEX idx_active (emp_id, is_active),
              FOREIGN KEY (emp_id) REFERENCES info(emp_id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
          ''');
          print('✅ face_enrollments table created');
        } catch (faceError) {
          print('❌ Error creating face_enrollments table: $faceError');
        }
      } else {
        print('✅ face_enrollments table already exists');
      }
    } catch (e) {
      print('Note: Tables may already exist: $e');
    }
  }

  // Employee CRUD operations
  Future<Employee> createEmployee(Employee employee) async {
    final conn = await instance.connection;
    
    var result = await conn.query(
      '''INSERT INTO info (
        emp_id, isAgency, alias, surname, first_name, middle_name,
        qualifier, salutation, sex, birth_date, birth_place, marital_status,
        religion, citizenship, acr_no, blood_type, reference_id,
        no_of_dependents, head_of_family, status, has_other_employer,
        email, email_id, case_sensitive, face_descriptors, gmail_id, photo_path
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        employee.empId,
        employee.isAgency,
        employee.alias,
        employee.surname,
        employee.firstName,
        employee.middleName,
        employee.qualifier,
        employee.salutation,
        employee.sex,
        employee.birthDate,
        employee.birthPlace,
        employee.maritalStatus,
        employee.religion,
        employee.citizenship,
        employee.acrNo,
        employee.bloodType,
        employee.referenceId,
        employee.noOfDependents,
        employee.headOfFamily,
        employee.status,
        employee.hasOtherEmployer,
        employee.email,
        employee.emailId,
        employee.caseSensitive,
        employee.faceDescriptors,
        employee.gmailId,
        employee.photoPath,
      ],
    );
    
    return employee;
  }

  Future<Employee?> getEmployee(int empId) async {
    final conn = await instance.connection;
    
    var results = await conn.query(
      'SELECT * FROM info WHERE emp_id = ?',
      [empId],
    );

    if (results.isNotEmpty) {
      return Employee.fromMap(_rowToMap(results.first));
    }
    return null;
  }

  Future<List<Employee>> getAllEmployees() async {
    final conn = await instance.connection;
    
    var results = await conn.query('SELECT * FROM info ORDER BY surname ASC');
    
    return results.map((row) => Employee.fromMap(_rowToMap(row))).toList();
  }

  Future<List<Employee>> getEmployeesWithFace() async {
    final conn = await instance.connection;
    
    var results = await conn.query(
      'SELECT * FROM info WHERE face_descriptors IS NOT NULL AND status = ? ORDER BY surname ASC',
      ['Active'],
    );
    
    return results.map((row) => Employee.fromMap(_rowToMap(row))).toList();
  }

  Future<int> updateEmployee(Employee employee) async {
    final conn = await instance.connection;
    
    var result = await conn.query(
      '''UPDATE info SET 
        isAgency = ?, alias = ?, surname = ?, first_name = ?, middle_name = ?,
        qualifier = ?, salutation = ?, sex = ?, birth_date = ?, birth_place = ?,
        marital_status = ?, religion = ?, citizenship = ?, acr_no = ?, blood_type = ?,
        reference_id = ?, no_of_dependents = ?, head_of_family = ?, status = ?,
        has_other_employer = ?, email = ?, email_id = ?, case_sensitive = ?,
        face_descriptors = ?, gmail_id = ?, photo_path = ?
      WHERE emp_id = ?''',
      [
        employee.isAgency,
        employee.alias,
        employee.surname,
        employee.firstName,
        employee.middleName,
        employee.qualifier,
        employee.salutation,
        employee.sex,
        employee.birthDate,
        employee.birthPlace,
        employee.maritalStatus,
        employee.religion,
        employee.citizenship,
        employee.acrNo,
        employee.bloodType,
        employee.referenceId,
        employee.noOfDependents,
        employee.headOfFamily,
        employee.status,
        employee.hasOtherEmployer,
        employee.email,
        employee.emailId,
        employee.caseSensitive,
        employee.faceDescriptors,
        employee.gmailId,
        employee.photoPath,
        employee.empId,
      ],
    );
    
    return result.affectedRows ?? 0;
  }

  Future<int> deleteEmployee(int empId) async {
    final conn = await instance.connection;
    
    var result = await conn.query(
      'DELETE FROM info WHERE emp_id = ?',
      [empId],
    );
    
    return result.affectedRows ?? 0;
  }

  // Login Record CRUD operations
  Future<LoginRecord> createLoginRecord(LoginRecord record) async {
    final conn = await instance.connection;
    
    await conn.query(
      '''INSERT INTO login (
        emp_id, time, date, state, sync_id, login_status,
        swipe, original_time, changed_by, change_on, remarks
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        record.empId,
        record.time,
        record.date,
        record.state,
        record.syncId,
        record.loginStatus,
        record.swipe,
        record.originalTime,
        record.changedBy,
        record.changeOn,
        record.remarks,
      ],
    );
    
    return record;
  }

  Future<List<LoginRecord>> getLoginsByEmployee(int empId) async {
    final conn = await instance.connection;
    
    var results = await conn.query(
      'SELECT * FROM login WHERE emp_id = ? ORDER BY date DESC, time DESC',
      [empId],
    );
    
    return results.map((row) => LoginRecord.fromMap(_rowToMap(row))).toList();
  }

  Future<List<LoginRecord>> getLoginsByDate(String date) async {
    final conn = await instance.connection;
    
    var results = await conn.query(
      'SELECT * FROM login WHERE date = ? ORDER BY time DESC',
      [date],
    );
    
    return results.map((row) => LoginRecord.fromMap(_rowToMap(row))).toList();
  }

  Future<LoginRecord?> getLastLogin(int empId, String date) async {
    final conn = await instance.connection;
    
    var results = await conn.query(
      'SELECT * FROM login WHERE emp_id = ? AND date = ? ORDER BY time DESC LIMIT 1',
      [empId, date],
    );
    
    if (results.isNotEmpty) {
      return LoginRecord.fromMap(_rowToMap(results.first));
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getEmployeeAttendanceToday() async {
    final conn = await instance.connection;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    var results = await conn.query('''
      SELECT 
        i.emp_id,
        i.first_name,
        i.middle_name,
        i.surname,
        MAX(CASE WHEN l.state = 'IN' THEN l.time END) as time_in,
        MAX(CASE WHEN l.state = 'OUT' THEN l.time END) as time_out
      FROM info i
      LEFT JOIN login l ON i.emp_id = l.emp_id AND l.date = ?
      WHERE i.status = 'Active'
      GROUP BY i.emp_id, i.first_name, i.middle_name, i.surname
      ORDER BY i.surname ASC
    ''', [today]);
    
    return results.map((row) => _rowToMap(row)).toList();
  }

  // Helper method to convert ResultRow to Map
  Map<String, dynamic> _rowToMap(ResultRow row) {
    Map<String, dynamic> map = {};
    for (var field in row.fields.entries) {
      map[field.key] = field.value;
    }
    return map;
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }

  // Test connection method
  Future<bool> testConnection() async {
    try {
      final conn = await connection;
      var result = await conn.query('SELECT 1');
      return result.isNotEmpty;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  // Security CRUD operations
  Future<SecurityModel> createSecurity(SecurityModel security) async {
    final conn = await instance.connection;
    
    await conn.query(
      '''INSERT INTO security (
        emp_id, password_hash, last_password_change, password_reset_token,
        login_attempts, last_login_date, last_login_time
      ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        security.empId,
        security.passwordHash,
        security.lastPasswordChange,
        security.passwordResetToken,
        security.loginAttempts,
        security.lastLoginDate,
        security.lastLoginTime,
      ],
    );
    
    return security;
  }

  Future<SecurityModel?> getSecurityByEmpId(int empId) async {
    final conn = await instance.connection;
    
    var results = await conn.query(
      'SELECT * FROM security WHERE emp_id = ?',
      [empId],
    );

    if (results.isNotEmpty) {
      return SecurityModel.fromMap(_rowToMap(results.first));
    }
    return null;
  }

  Future<int> updateSecurity(SecurityModel security) async {
    final conn = await instance.connection;
    
    var result = await conn.query(
      '''UPDATE security SET 
        password_hash = ?, last_password_change = ?, password_reset_token = ?,
        login_attempts = ?, last_login_date = ?, last_login_time = ?
      WHERE emp_id = ?''',
      [
        security.passwordHash,
        security.lastPasswordChange,
        security.passwordResetToken,
        security.loginAttempts,
        security.lastLoginDate,
        security.lastLoginTime,
        security.empId,
      ],
    );
    
    return result.affectedRows ?? 0;
  }

  Future<int> updateLoginAttempts(int empId, int attempts) async {
    final conn = await instance.connection;
    
    var result = await conn.query(
      'UPDATE security SET login_attempts = ? WHERE emp_id = ?',
      [attempts, empId],
    );
    
    return result.affectedRows ?? 0;
  }

  Future<int> updateLastLogin(int empId) async {
    final conn = await instance.connection;
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');
    
    var result = await conn.query(
      'UPDATE security SET last_login_date = ?, last_login_time = ?, login_attempts = 0 WHERE emp_id = ?',
      [dateFormat.format(now), timeFormat.format(now), empId],
    );
    
    return result.affectedRows ?? 0;
  }

  // Create default security record with birthday as password
  Future<void> createDefaultSecurity(int empId, String? birthDate) async {
    try {
      // Check if security record already exists
      final existing = await getSecurityByEmpId(empId);
      if (existing != null) {
        return; // Already has security record
      }

      String defaultPassword = '12345678'; // Fallback default
      
      if (birthDate != null && birthDate.isNotEmpty) {
        try {
          // Parse birth_date and format as %m%d%Y (MMddyyyy)
          final date = DateTime.parse(birthDate);
          defaultPassword = DateFormat('MMddyyyy').format(date);
        } catch (e) {
          print('Error parsing birth date: $e');
        }
      }

      final security = SecurityModel(
        empId: empId,
        passwordHash: SecurityModel.hashPassword(defaultPassword),
        lastPasswordChange: DateTime.now().toIso8601String(),
      );

      await createSecurity(security);
      print('✅ Created default security for employee $empId with password: $defaultPassword');
    } catch (e) {
      print('Error creating default security: $e');
    }
  }

  // Authenticate user
  Future<Employee?> authenticate(int empId, String password) async {
    try {
      // Get security record
      final security = await getSecurityByEmpId(empId);
      
      if (security == null) {
        print('No security record found for employee $empId');
        return null;
      }

      // Check if account is locked (too many attempts)
      if (security.loginAttempts >= 5) {
        print('Account locked due to too many failed attempts');
        return null;
      }

      // Verify password
      if (SecurityModel.verifyPassword(password, security.passwordHash)) {
        // Success - update last login
        await updateLastLogin(empId);
        
        // Get and return employee
        return await getEmployee(empId);
      } else {
        // Failed - increment attempts
        await updateLoginAttempts(empId, security.loginAttempts + 1);
        print('Invalid password. Attempts: ${security.loginAttempts + 1}');
        return null;
      }
    } catch (e) {
      print('Authentication error: $e');
      return null;
    }
  }

  // Change password
  Future<bool> changePassword(int empId, String oldPassword, String newPassword) async {
    try {
      final security = await getSecurityByEmpId(empId);
      
      if (security == null) {
        return false;
      }

      // Verify old password
      if (!SecurityModel.verifyPassword(oldPassword, security.passwordHash)) {
        return false;
      }

      // Update password
      final updatedSecurity = SecurityModel(
        securityId: security.securityId,
        empId: empId,
        passwordHash: SecurityModel.hashPassword(newPassword),
        lastPasswordChange: DateTime.now().toIso8601String(),
        loginAttempts: 0,
      );

      await updateSecurity(updatedSecurity);
      return true;
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }

  // Reset login attempts (admin function)
  Future<bool> resetLoginAttempts(int empId) async {
    try {
      await updateLoginAttempts(empId, 0);
      return true;
    } catch (e) {
      print('Error resetting login attempts: $e');
      return false;
    }
  }

  // Admin CRUD operations
  Future<bool> isAdmin(int empId) async {
    final conn = await instance.connection;
    
    var results = await conn.query(
      'SELECT * FROM admin WHERE emp_id = ?',
      [empId],
    );

    return results.isNotEmpty;
  }

  Future<bool> addAdmin(int empId, int createdBy) async {
    try {
      final conn = await instance.connection;
      
      await conn.query(
        'INSERT INTO admin (emp_id, created_by) VALUES (?, ?)',
        [empId, createdBy],
      );
      
      return true;
    } catch (e) {
      print('Error adding admin: $e');
      return false;
    }
  }

  Future<bool> removeAdmin(int empId) async {
    try {
      final conn = await instance.connection;
      
      await conn.query(
        'DELETE FROM admin WHERE emp_id = ?',
        [empId],
      );
      
      return true;
    } catch (e) {
      print('Error removing admin: $e');
      return false;
    }
  }

  // Face Enrollments operations
  Future<bool> enrollFace({
    required int empId,
    required String photoPath,
    required String faceDescriptors,
  }) async {
    try {
      final conn = await instance.connection;
      
      // Deactivate old enrollments
      await conn.query(
        'UPDATE face_enrollments SET is_active = FALSE WHERE emp_id = ? AND is_active = TRUE',
        [empId],
      );
      
      // Insert new enrollment
      await conn.query(
        'INSERT INTO face_enrollments (emp_id, photo_path, face_descriptors, is_active) VALUES (?, ?, ?, TRUE)',
        [empId, photoPath, faceDescriptors],
      );
      
      // Update info table with latest face data
      await conn.query(
        'UPDATE info SET face_descriptors = ?, photo_path = ? WHERE emp_id = ?',
        [faceDescriptors, photoPath, empId],
      );
      
      print('✅ Face enrollment saved to face_enrollments table');
      return true;
    } catch (e) {
      print('❌ Error enrolling face: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getActiveFaceEnrollment(int empId) async {
    try {
      final conn = await instance.connection;
      
      var result = await conn.query(
        'SELECT * FROM face_enrollments WHERE emp_id = ? AND is_active = TRUE ORDER BY enrolled_at DESC LIMIT 1',
        [empId],
      );
      
      if (result.isNotEmpty) {
        return _rowToMap(result.first);
      }
      return null;
    } catch (e) {
      print('Error getting active face enrollment: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getFaceEnrollmentHistory(int empId) async {
    try {
      final conn = await instance.connection;
      
      var result = await conn.query(
        'SELECT * FROM face_enrollments WHERE emp_id = ? ORDER BY enrolled_at DESC',
        [empId],
      );
      
      return result.map((row) => _rowToMap(row)).toList();
    } catch (e) {
      print('Error getting face enrollment history: $e');
      return [];
    }
  }
}
