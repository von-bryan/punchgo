// Node.js Express Server for PunchGo Image Uploads
// Place this in your /var/www/equisplit-server directory

const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;

// Create upload directory if it doesn't exist
const uploadDir = path.join(__dirname, 'punchgo', 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
  console.log('✅ Created upload directory:', uploadDir);
}

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const empId = req.body.emp_id || 'unknown';
    const timestamp = Date.now();
    const ext = path.extname(file.originalname) || '.jpg';
    const filename = `emp_${empId}_${timestamp}${ext}`;
    cb(null, filename);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: function (req, file, cb) {
    const allowedTypes = /jpeg|jpg|png/;
    const mimetype = allowedTypes.test(file.mimetype);
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());

    if (mimetype && extname) {
      return cb(null, true);
    }
    cb(new Error('Only image files (jpeg, jpg, png) are allowed!'));
  }
});

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve uploaded files statically
app.use('/punchgo/uploads', express.static(uploadDir));

// Health check endpoint
app.get('/api/ping', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
});

// Upload endpoint
app.post('/api/punchgo/upload', upload.single('file'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded'
      });
    }

    const empId = req.body.emp_id;
    const filePath = `punchgo/uploads/${req.file.filename}`;

    console.log(`✅ Image uploaded for employee ${empId}: ${req.file.filename}`);

    res.status(200).json({
      success: true,
      message: 'File uploaded successfully',
      filePath: filePath,
      file_path: filePath, // Alternate field name
      path: filePath, // Another alternate
      filename: req.file.filename,
      emp_id: empId,
      size: req.file.size,
      url: `http://${req.hostname}:${PORT}/${filePath}`
    });
  } catch (error) {
    console.error('❌ Upload error:', error);
    res.status(500).json({
      success: false,
      message: 'Upload failed',
      error: error.message
    });
  }
});

// Delete endpoint
app.delete('/api/punchgo/delete', (req, res) => {
  try {
    const { filePath } = req.body;

    if (!filePath) {
      return res.status(400).json({
        success: false,
        message: 'File path is required'
      });
    }

    const fullPath = path.join(__dirname, filePath);

    if (fs.existsSync(fullPath)) {
      fs.unlinkSync(fullPath);
      console.log(`✅ Deleted file: ${filePath}`);
      res.json({
        success: true,
        message: 'File deleted successfully'
      });
    } else {
      res.status(404).json({
        success: false,
        message: 'File not found'
      });
    }
  } catch (error) {
    console.error('❌ Delete error:', error);
    res.status(500).json({
      success: false,
      message: 'Delete failed',
      error: error.message
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        message: 'File size exceeds 5MB limit'
      });
    }
  }
  res.status(500).json({
    success: false,
    message: error.message || 'Internal server error'
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 PunchGo Server running on http://0.0.0.0:${PORT}`);
  console.log(`📁 Upload directory: ${uploadDir}`);
  console.log(`📤 Upload endpoint: http://0.0.0.0:${PORT}/api/punchgo/upload`);
  console.log(`🖼️  View images at: http://0.0.0.0:${PORT}/punchgo/uploads/`);
});

module.exports = app;
