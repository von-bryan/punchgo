# Image Upload Feature - Quick Setup

## ✅ What Was Added

The app now captures and uploads employee photos to your server at **10.0.5.60**.

---

## 📱 Flutter App Changes

### 1. **New Dependencies Added**
- `http` - HTTP requests
- `dio` - File upload
- `path_provider` - File paths

### 2. **New Files Created**
- `lib/services/image_upload_service.dart` - Handles image uploads
- `lib/config/database_config.dart` - Updated with server config

### 3. **Database Changes**
- Added `photo_path` column to `info` table
- Stores server path to employee photos

### 4. **UI Changes**
- Face enrollment now captures actual photo
- Shows upload progress
- Uploads to server automatically

---

## 🖥️ Server Setup Required

### Step 1: Install on Server (10.0.5.60)

```bash
# SSH to your server
ssh user@10.0.5.60

# Navigate to your server directory
cd /var/www/

# Create punchgo directory (or copy from your project)
mkdir -p punchgo-server
cd punchgo-server

# Upload the files from server/ folder to here
# Or copy from this project:
# - punchgo-server.js
# - package.json
```

### Step 2: Install Node.js Dependencies

```bash
npm install
```

### Step 3: Run the Server

```bash
# Start the server
node punchgo-server.js

# Or use PM2 for production
pm2 start punchgo-server.js --name punchgo
pm2 save
```

### Step 4: Verify

```bash
# Test the server
curl http://10.0.5.60:3000/api/ping

# Should return: {"status":"ok","message":"Server is running"}
```

---

## 📋 Configuration

### Flutter App Config

File: `lib/config/database_config.dart`

```dart
class ServerConfig {
  static const String host = '10.0.5.60';
  static const int port = 3000;  // Your Node.js server port
}
```

**Change port if needed!**

### Server Port

File: `server/punchgo-server.js`

```javascript
const PORT = 3000; // Change if needed
```

---

## 🚀 How It Works

1. **User enrolls face** in Flutter app
2. **Camera captures** employee photo
3. **App uploads** to `http://10.0.5.60:3000/api/punchgo/upload`
4. **Server saves** to `/var/www/punchgo-server/punchgo/uploads/`
5. **Server returns** file path
6. **App saves** path to database (`photo_path` column)
7. **Images accessible** at `http://10.0.5.60:3000/punchgo/uploads/filename.jpg`

---

## 📁 File Structure

**On Server (10.0.5.60):**
```
/var/www/punchgo-server/
├── punchgo-server.js
├── package.json
└── punchgo/
    └── uploads/
        ├── emp_4_1707123456789.jpg
        ├── emp_5_1707123567890.jpg
        └── ...
```

**In Database:**
```sql
SELECT emp_id, first_name, photo_path FROM info;

+--------+------------+----------------------------------------+
| emp_id | first_name | photo_path                             |
+--------+------------+----------------------------------------+
|      4 | JOYCELINE  | punchgo/uploads/emp_4_1707123456.jpg  |
|      5 | JOHN       | punchgo/uploads/emp_5_1707234567.jpg  |
+--------+------------+----------------------------------------+
```

---

## ✅ Testing

### 1. Run Flutter App

```bash
flutter pub get
flutter run
```

### 2. Enroll a Face

- Go to Employees tab
- Select employee → Enroll Face
- Position face → Capture
- Watch console for upload status

### 3. Check Server

```bash
# On server, list uploaded files
ls -la /var/www/punchgo-server/punchgo/uploads/

# Should see:
# emp_123_1707123456789.jpg
```

### 4. View in Browser

```
http://10.0.5.60:3000/punchgo/uploads/emp_123_1707123456789.jpg
```

---

## 🔧 Troubleshooting

### Upload Fails

**Check:**
1. Is server running? `pm2 list`
2. Can app reach server? `ping 10.0.5.60`
3. Is port open? `telnet 10.0.5.60 3000`
4. Check server logs: `pm2 logs punchgo`

### Permission Errors

```bash
chmod 755 /var/www/punchgo-server/punchgo/uploads
```

### Port Already in Use

```bash
# Find what's using port 3000
lsof -i :3000

# Kill it or change PORT in punchgo-server.js
```

---

## 📝 SQL Migration (Optional)

If your table already exists without `photo_path`:

```sql
ALTER TABLE info ADD COLUMN photo_path VARCHAR(255);
```

The app will create it automatically if table doesn't exist.

---

## 🔐 Security Notes

**Development:** OK to use HTTP on local network

**Production:** 
- Use HTTPS
- Add authentication tokens
- Implement rate limiting  
- See [server/README.md](server/README.md) for details

---

## 🎯 Next Steps

1. ✅ Copy `server/` folder contents to your 10.0.5.60 server
2. ✅ Run `npm install` on server
3. ✅ Start server with `node punchgo-server.js`
4. ✅ Run `flutter pub get` in app
5. ✅ Run Flutter app and test face enrollment

---

**That's it! Photos will now be uploaded to your server!** 📸
