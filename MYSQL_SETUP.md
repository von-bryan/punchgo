# MySQL Database Setup Guide

## ✅ Switching to Remote MySQL Server

The app is now configured to connect to your MySQL server at **10.0.5.60** instead of using local SQLite.

---

## 🔧 Configuration Steps

### 1. **Update Database Credentials**

Open the file: [database_config.dart](lib/config/database_config.dart)

```dart
class DatabaseConfig {
  static const String host = '10.0.5.60';
  static const int port = 3306;
  static const String user = 'YOUR_USERNAME';        // ← Change this
  static const String password = 'YOUR_PASSWORD';    // ← Change this
  static const String database = 'punchgo';
  
  static const int timeout = 30;
  static const int maxRetries = 3;
}
```

**Replace:**
- `YOUR_USERNAME` with your MySQL username (from SQLyog)
- `YOUR_PASSWORD` with your MySQL password

---

### 2. **Database & Tables**

The app will work with your existing `punchgo` database.

#### If tables already exist:
✅ The app will use them automatically

#### If tables don't exist:
✅ The app will create them automatically on first run

**Table Structure:**
```sql
-- info table (employee information)
CREATE TABLE info (
  emp_code INT AUTO_INCREMENT PRIMARY KEY,
  emp_id INT NOT NULL,
  surname VARCHAR(100) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  middle_name VARCHAR(100),
  sex VARCHAR(10),
  email VARCHAR(100),
  status VARCHAR(20) DEFAULT 'Active',
  face_descriptors TEXT,
  -- ... all your existing columns
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- login table (attendance records)
CREATE TABLE login (
  login_id INT AUTO_INCREMENT PRIMARY KEY,
  emp_id INT NOT NULL,
  time TIME NOT NULL,
  date DATE NOT NULL,
  state VARCHAR(10) NOT NULL,
  login_status VARCHAR(50),
  -- ... all your existing columns
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

### 3. **Network Configuration**

#### For Development (Testing):
Make sure your device/emulator can reach 10.0.5.60:
- If using Android emulator, ensure network is accessible
- If using physical device, ensure it's on the same network

#### MySQL Server Settings:
Ensure your MySQL server at 10.0.5.60 allows remote connections:

```sql
-- Check user permissions
SELECT user, host FROM mysql.user;

-- If needed, grant access (run on your MySQL server)
GRANT ALL PRIVILEGES ON punchgo.* TO 'your_username'@'%' IDENTIFIED BY 'your_password';
FLUSH PRIVILEGES;
```

**MySQL Config File** (`my.cnf` or `my.ini`):
```ini
[mysqld]
bind-address = 0.0.0.0  # Allow remote connections
```

---

### 4. **Firewall Configuration**

Ensure port **3306** is open on your server (10.0.5.60):

**Ubuntu/Linux:**
```bash
sudo ufw allow 3306
sudo ufw reload
```

**Windows:**
- Open Windows Firewall
- Allow incoming connections on port 3306

---

## 🚀 Testing Connection

### From Your Device
You can test if the server is reachable:

**Android (using termux or adb shell):**
```bash
ping 10.0.5.60
telnet 10.0.5.60 3306
```

### From the App
The app will show connection status on startup:
- ✅ `Connected to MySQL database at 10.0.5.60` = Success
- ❌ `Error connecting to database` = Check credentials/network

---

## 📱 Running the App

After configuring credentials:

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

Watch the console for connection messages!

---

## 🔄 Integration with Node.js Server

Your existing Node.js server at `/var/www/equisplit-server` can also access the same database.

### Shared Database Benefits:
- ✅ **Centralized Data** - All apps use same employee database
- ✅ **Real-time Sync** - Changes reflect across all apps
- ✅ **API Integration** - Node.js can provide REST API
- ✅ **Web Dashboard** - Build admin panel with Node.js

### Example Node.js Connection:
```javascript
const mysql = require('mysql2');

const pool = mysql.createPool({
  host: '10.0.5.60',
  user: 'your_username',
  password: 'your_password',
  database: 'punchgo',
  waitForConnections: true,
  connectionLimit: 10,
});

// Query example
pool.query('SELECT * FROM info WHERE status = ?', ['Active'], (err, results) => {
  if (err) throw err;
  console.log(results);
});
```

---

## 🔍 Troubleshooting

### Connection Refused
❌ **Error:** `Connection refused`
- Check if MySQL is running: `sudo systemctl status mysql`
- Verify port 3306 is listening: `netstat -tuln | grep 3306`
- Check firewall settings

### Access Denied
❌ **Error:** `Access denied for user`
- Verify username and password in `database_config.dart`
- Check user permissions in MySQL
- Ensure user can connect from remote host

### Host Not Reachable
❌ **Error:** `No route to host`
- Verify device is on same network as 10.0.5.60
- Ping the server: `ping 10.0.5.60`
- Check network configuration

### Timeout
❌ **Error:** `Connection timeout`
- Increase timeout in `database_config.dart`
- Check network latency
- Verify MySQL is accepting connections

---

## ✅ What Changed

### Before (SQLite):
- ❌ Local database per device
- ❌ No data sharing
- ❌ Data lost on uninstall

### After (MySQL):
- ✅ Centralized database
- ✅ Shared across all apps
- ✅ Persistent data
- ✅ Multi-device support
- ✅ Integration with Node.js

---

## 📊 Data Flow

```
Flutter App (Mobile) ──┐
                       ├──→ MySQL Server (10.0.5.60)
Node.js Server ────────┘    └──→ punchgo database
                                 ├── info table
                                 └── login table
```

---

## 🔐 Security Recommendations

1. **Use Strong Passwords** - For MySQL user accounts
2. **Limit Permissions** - Grant only necessary privileges
3. **Use SSL/TLS** - For production deployments
4. **Network Security** - Use VPN or private network
5. **Don't Hardcode Credentials** - Use environment variables (production)

---

**Ready to connect! Just update your credentials and run the app.** 🎉
