# Login & Security System

## ✅ Features Added

1. **Login Page** - Secure authentication with Employee ID and password
2. **Security Table** - Stores hashed passwords in `punchgo.security`
3. **Default Passwords** - Birthday in format MM/DDYYYY (e.g., 09/281948)
4. **Change Password** - Users can update their password in Profile
5. **Session Management** - Keeps users logged in
6. **Profile Page** - View info and change password

---

## 🔐 Security Table Structure

```sql
CREATE TABLE security (
  security_id INT AUTO_INCREMENT PRIMARY KEY,
  emp_id INT NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  last_password_change DATETIME,
  password_reset_token VARCHAR(255),
  login_attempts INT DEFAULT 0,
  last_login_date DATE,
  last_login_time TIME,
  FOREIGN KEY (emp_id) REFERENCES info(emp_id) ON DELETE CASCADE
);
```

The table is created automatically when the app runs.

---

## 🔑 Default Password Format

For employee with birthday `1948-09-28`, the default password is:
```
09281948
```

Format: `MMDDYYYY`

If no birthday is set, default password is: `12345678`

---

## 📱 How to Use

### First Time Login

1. Launch app → Login screen appears
2. Enter Employee ID (e.g., 4)
3. Enter default password (birthday in MMDDYYYY format)
4. Tap LOGIN

### Change Password

1. Go to Profile tab (bottom navigation)
2. Tap "Change Password"
3. Enter current password
4. Enter new password (min 6 characters)
5. Confirm new password
6. Tap "Change"

### Logout

- Tap logout icon in top-right corner
- Confirm logout

---

## 🔧 For Existing Employees

If you already have employees in the database, they need security records:

### Option 1: Auto-create on first employee add
When you add a NEW employee via the app, security record is created automatically.

### Option 2: Manual SQL for existing employees

```sql
-- For employee with birthday 1948-09-28 (emp_id = 4)
INSERT INTO security (emp_id, password_hash, last_password_change)
VALUES (
  4,
  SHA2('09281948', 256),
  NOW()
);
```

### Option 3: Bulk create for all employees

```sql
INSERT INTO security (emp_id, password_hash, last_password_change)
SELECT 
  emp_id,
  SHA2(
    CASE 
      WHEN birth_date IS NOT NULL THEN 
        CONCAT(
          LPAD(MONTH(birth_date), 2, '0'),
          LPAD(DAY(birth_date), 2, '0'),
          YEAR(birth_date)
        )
      ELSE '12345678'
    END,
    256
  ),
  NOW()
FROM info
WHERE NOT EXISTS (
  SELECT 1 FROM security WHERE security.emp_id = info.emp_id
);
```

This creates security records for ALL employees using their birthdays.

---

## 🛡️ Security Features

### Password Hashing
- Passwords stored as SHA-256 hash
- Never stored in plain text

### Login Attempts
- Tracks failed login attempts
- Account locks after 5 failed attempts
- Reset via admin

### Session Management
- Uses SharedPreferences
- Stays logged in until manual logout
- Auto-logout on app restart (optional)

---

## 🔓 Reset Account Lockout

If account is locked (5 failed attempts):

```sql
UPDATE security SET login_attempts = 0 WHERE emp_id = 4;
```

---

## 📊 View Security Info

```sql
SELECT 
  s.emp_id,
  i.first_name,
  i.surname,
  s.login_attempts,
  s.last_login_date,
  s.last_login_time,
  s.last_password_change
FROM security s
JOIN info i ON s.emp_id = i.emp_id;
```

---

## 🧪 Testing

### Test Login
1. Employee ID: `4`
2. Password: `09281948` (if birthday is 1948-09-28)

### Test Password Change
1. Login
2. Go to Profile
3. Change password
4. Logout
5. Login with new password

---

## 📝 New Files Created

- `lib/models/security_model.dart` - Security data model
- `lib/services/auth_service.dart` - Session management
- `lib/screens/login_screen.dart` - Login UI
- `lib/screens/profile_screen.dart` - Profile & password change

---

## ⚙️ Configuration

### Change Default Password

Edit `lib/services/database_helper.dart`:

```dart
String defaultPassword = '12345678'; // Change this
```

### Disable Account Lockout

Edit `lib/services/database_helper.dart`:

```dart
if (security.loginAttempts >= 5) { // Change to higher number
```

---

**Users must login with Employee ID and password to access the app!** 🔐
