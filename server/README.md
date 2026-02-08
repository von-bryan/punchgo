# PunchGo Server Setup

## 📋 Overview

This server handles image uploads from the PunchGo Flutter app. It receives employee photos and saves them to `punchgo/uploads/` directory.

---

## 🚀 Installation on Server (10.0.5.60)

### 1. **Copy Files to Server**

Copy this server folder to your Node.js directory:

```bash
# On your server (10.0.5.60)
cd /var/www/
mkdir -p punchgo-server
cd punchgo-server
```

Upload `punchgo-server.js` and `package.json` to this directory.

### 2. **Install Dependencies**

```bash
npm install
```

This installs:
- `express` - Web framework
- `multer` - File upload middleware

### 3. **Run the Server**

```bash
# Start the server
node punchgo-server.js

# Or use PM2 for production (keeps running)
npm install -g pm2
pm2 start punchgo-server.js --name "punchgo"
pm2 save
pm2 startup
```

---

## 📁 Directory Structure

After running, the server creates:

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

---

## 🔌 Endpoints

### 1. Health Check
```
GET http://10.0.5.60:3000/api/ping
```

Response:
```json
{
  "status": "ok",
  "message": "Server is running"
}
```

### 2. Upload Image
```
POST http://10.0.5.60:3000/api/punchgo/upload
```

Form Data:
- `file` - Image file (JPEG/PNG, max 5MB)
- `emp_id` - Employee ID

Response:
```json
{
  "success": true,
  "message": "File uploaded successfully",
  "filePath": "punchgo/uploads/emp_123_1707123456789.jpg",
  "filename": "emp_123_1707123456789.jpg",
  "emp_id": "123",
  "size": 245678,
  "url": "http://10.0.5.60:3000/punchgo/uploads/emp_123_1707123456789.jpg"
}
```

### 3. View Image
```
GET http://10.0.5.60:3000/punchgo/uploads/emp_123_1707123456789.jpg
```

Returns the image file.

### 4. Delete Image
```
DELETE http://10.0.5.60:3000/api/punchgo/delete
```

Body:
```json
{
  "filePath": "punchgo/uploads/emp_123_1707123456789.jpg"
}
```

---

## 🔧 Configuration

### Change Port

Edit `punchgo-server.js`:
```javascript
const PORT = 3000; // Change to your preferred port
```

Then update Flutter app's `lib/config/database_config.dart`:
```dart
static const int port = 3000; // Match the port
```

### File Size Limit

Edit `punchgo-server.js`:
```javascript
limits: {
  fileSize: 5 * 1024 * 1024, // 5MB (change as needed)
}
```

### Upload Directory

Default: `/var/www/punchgo-server/punchgo/uploads/`

To change, edit:
```javascript
const uploadDir = path.join(__dirname, 'punchgo', 'uploads');
```

---

## 🔐 Security Recommendations

### 1. Use HTTPS (Production)

```javascript
// Add SSL certificates
const https = require('https');
const fs = require('fs');

const options = {
  key: fs.readFileSync('/path/to/private.key'),
  cert: fs.readFileSync('/path/to/certificate.crt')
};

https.createServer(options, app).listen(443);
```

### 2. Add Authentication

```javascript
// Simple token authentication
const authenticateToken = (req, res, next) => {
  const token = req.headers['authorization'];
  if (token !== 'YOUR_SECRET_TOKEN') {
    return res.status(403).json({ error: 'Forbidden' });
  }
  next();
};

app.post('/api/punchgo/upload', authenticateToken, upload.single('file'), ...);
```

### 3. Rate Limiting

```bash
npm install express-rate-limit
```

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/punchgo/', limiter);
```

---

## 🧪 Testing

### Test  Upload with cURL

```bash
curl -X POST http://10.0.5.60:3000/api/punchgo/upload \
  -F "file=@/path/to/image.jpg" \
  -F "emp_id=123"
```

### Test from Browser

Open: `http://10.0.5.60:3000/api/ping`

---

## 🐛 Troubleshooting

### Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000

# Kill it
kill -9 <PID>
```

### Permission Denied

```bash
# Fix upload directory permissions
chmod 755 /var/www/punchgo-server/punchgo/uploads
```

### Cannot Access from Network

```bash
# Check firewall
sudo ufw allow 3000

# Check if server is listening on 0.0.0.0
netstat -tuln | grep 3000
```

---

## 📊 Monitoring with PM2

```bash
# View logs
pm2 logs punchgo

# Monitor
pm2 monit

# Restart
pm2 restart punchgo

# Stop
pm2 stop punchgo

# Remove
pm2 delete punchgo
```

---

## 🔄 Integration with Existing Server

If you already have a server at `/var/www/equisplit-server`:

### Option 1: Separate Server (Recommended)
Run this on a different port (e.g., 3000) alongside your existing server.

### Option 2: Integrate Routes
Copy the routes into your existing Express app:

```javascript
// In your existing server.js
const multer = require('multer');
const path = require('path');

// Add the multer config and routes from punchgo-server.js
```

---

## ✅ Verification

After starting the server:

1. ✅ Check health: `curl http://10.0.5.60:3000/api/ping`
2. ✅ Check upload directory exists: `ls -la punchgo/uploads/`
3. ✅ Test upload from Flutter app
4. ✅ Verify image saved: `ls -la punchgo/uploads/`
5. ✅ Access image in browser: `http://10.0.5.60:3000/punchgo/uploads/filename.jpg`

---

That's it! Your server is ready to receive employee photos from the PunchGo app! 📸
