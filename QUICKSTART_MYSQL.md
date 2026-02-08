# 🚀 Quick Start - MySQL Version

## ✅ You can use your existing MySQL server!

Your app now connects to **MySQL at 10.0.5.60** instead of local SQLite.

---

## 📝 IMPORTANT: Set Your Credentials

**Before running the app, update this file:**

📄 [lib/config/database_config.dart](lib/config/database_config.dart)

```dart
class DatabaseConfig {
  static const String host = '10.0.5.60';
  static const int port = 3306;
  static const String user = 'YOUR_USERNAME';     // ← CHANGE THIS
  static const String password = 'YOUR_PASSWORD'; // ← CHANGE THIS
  static const String database = 'punchgo';
}
```

Replace:
- `YOUR_USERNAME` → Your MySQL username
- `YOUR_PASSWORD` → Your MySQL password

---

## 🏃 Run the App

```bash
# 1. Install dependencies
flutter pub get

# 2. Update credentials in lib/config/database_config.dart

# 3. Run the app
flutter run
```

---

## 📊 Database Tables

The app uses these tables in your `punchgo` database:

### 1. **info** (Employees)
- Your existing table works perfectly!
- `face_descriptors` column stores face data
- All existing data is preserved

### 2. **login** (Attendance)
- Your existing table works perfectly!
- New records use `state = 'IN'` or `'OUT'`
- `login_status = 'Face Recognition'`

**Tables will be created automatically if they don't exist.**

---

## ✅ Integration with Node.js

Your Node.js server at `/var/www/equisplit-server` can share the same database:

```javascript
const mysql = require('mysql2');

const pool = mysql.createPool({
  host: '10.0.5.60',
  user: 'your_username',
  password: 'your_password',
  database: 'punchgo',
});

// Access same tables
pool.query('SELECT * FROM info', (err, results) => {
  console.log(results); // Same data as Flutter app!
});
```

---

## 🔍 Troubleshooting

### Can't connect?
1. Check username/password in `database_config.dart`
2. Ensure MySQL is running on 10.0.5.60
3. Verify port 3306 is open
4. Check device is on same network

### MySQL User Permissions
```sql
-- Grant access (run this on your MySQL server)
GRANT ALL PRIVILEGES ON punchgo.* TO 'your_user'@'%' IDENTIFIED BY 'your_pass';
FLUSH PRIVILEGES;
```

### Check Connection
```bash
# From your Android device/emulator network
ping 10.0.5.60
telnet 10.0.5.60 3306
```

---

## 📖 Full Documentation

For detailed setup instructions, see:
- [MYSQL_SETUP.md](MYSQL_SETUP.md) - Complete MySQL configuration guide
- [README.md](README.md) - App features and usage
- [SETUP.md](SETUP.md) - Flutter setup instructions

---

## 🎯 Benefits of MySQL

✅ **Shared Data** - All your apps use same database  
✅ **Centralized** - One source of truth  
✅ **Persistent** - Data survives app uninstall  
✅ **Multi-Device** - Sync across devices  
✅ **Integration** - Works with Node.js backend  

---

**That's it! Update credentials and run!** 🎉
