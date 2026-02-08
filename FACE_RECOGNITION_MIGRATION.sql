-- ============================================================================
-- PUNCHGO: Mobile Phone-Like Face Recognition System Migration
-- ============================================================================
-- This script upgrades your face recognition system to support:
-- ✅ Multiple enrollment samples per user
-- ✅ Quality metrics (lighting, angle, face size, sharpness)
-- ✅ Advanced multi-sample matching
-- ✅ Better accuracy and robustness
--
-- FULLY BACKWARD COMPATIBLE: Old data is preserved, new data uses new schema
-- ============================================================================

USE punchgo;

-- Step 1: Add new columns to face_enrollments table
-- (tracks enrollment session metadata)
ALTER TABLE face_enrollments 
ADD COLUMN IF NOT EXISTS avg_quality_score FLOAT DEFAULT 0 COMMENT 'Average quality score of all samples',
ADD COLUMN IF NOT EXISTS sample_count INT DEFAULT 0 COMMENT 'Number of samples in this enrollment',
ADD COLUMN IF NOT EXISTS is_complete BOOLEAN DEFAULT FALSE COMMENT 'Whether enrollment process is finished',
ADD COLUMN IF NOT EXISTS completed_at DATETIME COMMENT 'When enrollment was completed';

-- Step 2: Create face_samples table
-- (stores individual enrollment samples with quality metrics)
CREATE TABLE IF NOT EXISTS face_samples (
  sample_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique sample ID',
  enrollment_id INT NOT NULL COMMENT 'Reference to parent enrollment',
  emp_id INT NOT NULL COMMENT 'Employee ID',
  face_descriptors TEXT NOT NULL COMMENT 'Face feature vector as JSON',
  photo_path VARCHAR(255) COMMENT 'Path to the sample photo',
  quality_score FLOAT DEFAULT 0 COMMENT 'Overall quality score (0-100)',
  lighting_quality FLOAT DEFAULT 0 COMMENT 'Lighting assessment (0-100)',
  angle_quality FLOAT DEFAULT 0 COMMENT 'Head angle assessment (0-100)',
  face_size_quality FLOAT DEFAULT 0 COMMENT 'Face size assessment (0-100)',
  sharpness_quality FLOAT DEFAULT 0 COMMENT 'Image sharpness assessment (0-100)',
  sample_angle VARCHAR(50) COMMENT 'Angle type: frontal, left, right, up, down',
  sampled_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'When sample was captured',
  
  INDEX idx_enrollment_id (enrollment_id) COMMENT 'Fast lookup by enrollment',
  INDEX idx_emp_id (emp_id) COMMENT 'Fast lookup by employee',
  INDEX idx_quality (quality_score) COMMENT 'Find high-quality samples',
  
  FOREIGN KEY (enrollment_id) REFERENCES face_enrollments(face_id) ON DELETE CASCADE,
  FOREIGN KEY (emp_id) REFERENCES info(emp_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Individual face enrollment samples with quality metrics';

-- Step 3: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_face_samples_enrollment 
  ON face_samples(enrollment_id, quality_score);

CREATE INDEX IF NOT EXISTS idx_face_samples_emp 
  ON face_samples(emp_id, sampled_at DESC);

-- Step 4: Verify new structure
SHOW TABLES LIKE 'face_samples';
DESCRIBE face_samples;
DESCRIBE face_enrollments;

-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS
-- ============================================================================
-- 
-- Option 1: AUTOMATIC (Recommended)
-- - Run flutter clean && flutter pub get
-- - Run on device/emulator
-- - App will auto-create/migrate tables on startup
--
-- Option 2: MANUAL via phpMyAdmin/MySQL Workbench
-- - Select punchgo database
-- - Copy & paste this entire script
-- - Click "Execute"
--
-- Option 3: MANUAL via Command Line
-- - mysql -u root -p punchgo < FACE_RECOGNITION_MIGRATION.sql
--
-- ============================================================================
-- WHAT'S CHANGING IN YOUR APP
-- ============================================================================
--
-- ENROLLMENT FLOW (Now with multiple samples)
-- 1. User chooses "Enroll Face"
-- 2. System creates enrollment session (face_enrollments record)
-- 3. Captures 5+ samples at different angles
-- 4. Assesses quality for each sample
-- 5. Stores samples with quality metrics (face_samples table)
-- 6. Marks enrollment complete with avg quality
--
-- MATCHING FLOW (Now uses multiple samples)
-- 1. Detects face in real-time
-- 2. Extracts descriptors from current face
-- 3. Compares against ALL stored samples
-- 4. Finds best match + applies multi-sample bonus
-- 5. More accurate, faster recognition
--
-- QUALITY METRICS (What gets assessed)
-- ✅ Lighting Quality: 100 = perfect lighting, 0 = too dark/bright
-- ✅ Angle Quality: 100 = perfectly frontal, 50 = 30+ degrees off
-- ✅ Face Size Quality: 100 = 40-60% of image, 0 = too small/large
-- ✅ Sharpness Quality: 100 = crystal clear, 0 = blurry
-- ✅ Overall Quality: Weighted average of all metrics
--
-- ============================================================================
-- DATA MIGRATION NOTES
-- ============================================================================
--
-- ✅ Old enrollments: Remain active and functional
-- ✅ Old face_descriptors: Still work with fallback logic
-- ✅ New enrollments: Use face_samples table with quality tracking
-- ✅ Zero data loss: Everything is preserved
-- ✅ No downtime: Changes are backward compatible
--
-- To migrate old enrollment to new system:
-- 1. User re-enrolls face (captures with new system)
-- 2. Old enrollment automatically deactivated
-- 3. New enrollment with multiple samples replaces it
--
-- ============================================================================
