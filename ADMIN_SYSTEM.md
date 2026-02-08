# Admin Role System Documentation

## Overview
The PunchGo app now supports role-based access control with two user types: **Admin** and **Employee**.

## Database Schema

### Admin Table
```sql
CREATE TABLE admin (
  admin_id INT AUTO_INCREMENT PRIMARY KEY,
  emp_id INT NOT NULL UNIQUE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by INT,
  INDEX idx_emp_id (emp_id),
  FOREIGN KEY (emp_id) REFERENCES info(emp_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
```

- `admin_id`: Auto-incremented primary key
- `emp_id`: Links to the employee in `info` table (must be unique)
- `created_at`: Timestamp when admin privileges were granted
- `created_by`: Employee ID of who granted the admin role

## User Interface Differences

### Admin View (4 tabs)
1. **Attendance** - View all employee attendance records
2. **Employees** - Manage employee records
3. **Settings** - Manage admin roles
4. **Profile** - Personal profile and settings

### Employee View (2 tabs)
1. **Time In/Out** - Clock in/out with face recognition
2. **Profile** - Personal profile, change password, enroll face

## API Methods

### DatabaseHelper

#### Check Admin Status
```dart
Future<bool> isAdmin(int empId)
```
Returns `true` if the employee has admin privileges, `false` otherwise.

#### Add Admin
```dart
Future<bool> addAdmin(int empId, int createdBy)
```
Grants admin privileges to an employee.
- `empId`: Employee to grant admin access
- `createdBy`: Employee ID of who is granting the access
- Returns `true` on success

#### Remove Admin
```dart
Future<bool> removeAdmin(int empId)
```
Revokes admin privileges from an employee.
- Returns `true` if successful

## Settings Screen (Admin Only)

The Settings screen allows admins to:
- View all employees
- Grant admin privileges to any employee (toggle switch)
- Revoke admin privileges from any employee
- See who currently has admin access (highlighted in blue)

## Face Enrollment Auto-Redirect

After successful login:
- If employee has **no face enrolled** → Redirected to Face Enrollment Screen
- If employee has **face enrolled** → Redirected to Home Screen (with role-based tabs)

This ensures all users have their face enrolled before accessing the main app features.

## Implementation Details

### Home Screen Logic
1. On initialization, checks if logged-in user is admin
2. Dynamically sets tab count and screens based on role
3. Admin sees 4 tabs, employees see 2 tabs
4. AppBar logout button hidden on Profile tab (last tab for both roles)

### Login Flow
```
Login Success → Check Face Enrollment
  ├─ No Face → Face Enrollment Screen → Home Screen
  └─ Has Face → Home Screen
```

## Granting First Admin

To grant the first admin user, you can manually insert into the database:

```sql
INSERT INTO admin (emp_id, created_by) VALUES (1, 1);
```

Replace `1` with the employee ID you want to make admin.

Alternatively, modify the code temporarily to grant admin on first login or create a setup screen.

## Security Considerations

- Admin privileges allow managing other employees and attendance data
- Admins can grant/revoke admin access to others
- No self-removal protection (admin can remove their own admin status)
- Consider implementing a "super admin" that cannot be removed if needed

## Future Enhancements

Potential features to add:
- Audit log for admin actions
- Permission levels (e.g., read-only admin, full admin)
- Prevent last admin from being removed
- Admin approval workflow for certain actions
- Export/import employee data
- System-wide settings (attendance rules, grace periods, etc.)
