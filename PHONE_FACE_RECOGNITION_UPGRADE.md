# Mobile Phone Face Recognition System Upgrade

## Database Changes Required

Run these SQL statements to upgrade your database:

```sql
-- 1. Create face_samples table for storing multiple enrollment samples
CREATE TABLE IF NOT EXISTS face_samples (
  sample_id INT AUTO_INCREMENT PRIMARY KEY,
  enrollment_id INT NOT NULL,
  emp_id INT NOT NULL,
  face_descriptors TEXT NOT NULL,
  photo_path VARCHAR(255),
  quality_score FLOAT DEFAULT 0,
  lighting_quality FLOAT DEFAULT 0,
  angle_quality FLOAT DEFAULT 0,
  face_size_quality FLOAT DEFAULT 0,
  sharpness_quality FLOAT DEFAULT 0,
  sample_angle VARCHAR(50),
  sampled_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_enrollment_id (enrollment_id),
  INDEX idx_emp_id (emp_id),
  FOREIGN KEY (enrollment_id) REFERENCES face_enrollments(face_id) ON DELETE CASCADE,
  FOREIGN KEY (emp_id) REFERENCES info(emp_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Alter face_enrollments table to add quality tracking
ALTER TABLE face_enrollments 
ADD COLUMN IF NOT EXISTS avg_quality_score FLOAT DEFAULT 0,
ADD COLUMN IF NOT EXISTS sample_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_complete BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS completed_at DATETIME;

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_face_samples_enrollment ON face_samples(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_face_samples_emp ON face_samples(emp_id);

-- Verify new tables
SHOW TABLES LIKE 'face_samples';
DESCRIBE face_samples;
```

## How to Apply

**Option A: Direct MySQL/phpMyAdmin**
1. Open your MySQL client or phpMyAdmin
2. Select database `punchgo`
3. Copy and paste the SQL above
4. Execute

**Option B: Via Flutter (Automatic)**
- The app will auto-create/migrate tables on next startup

## What's Changing in Your App

1. **Enrollment Process**: Capture 5+ samples at different angles
2. **Quality Assessment**: Evaluates lighting, angle, size, sharpness
3. **Storage**: Multiple samples stored with individual quality scores
4. **Matching**: Uses all samples for more accurate recognition
5. **UI**: Real-time feedback like modern phones (progress rings, angle guidance)

## No Data Loss
- Old enrollments remain in `face_enrollments`
- New samples stored separately in `face_samples`
- Fully backward compatible
