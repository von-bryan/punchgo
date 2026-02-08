-- Create face_enrollments table for storing face enrollment history
USE punchgo;

CREATE TABLE IF NOT EXISTS face_enrollments (
  face_id INT AUTO_INCREMENT PRIMARY KEY,
  emp_id INT NOT NULL,
  photo_path VARCHAR(255) NOT NULL,
  face_descriptors TEXT,
  enrolled_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,
  INDEX idx_emp_id (emp_id),
  INDEX idx_active (emp_id, is_active),
  FOREIGN KEY (emp_id) REFERENCES info(emp_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Verify table was created
SHOW TABLES LIKE 'face_enrollments';

-- Show table structure
DESCRIBE face_enrollments;

-- Example: Get active face enrollment for employee
-- SELECT * FROM face_enrollments WHERE emp_id = 1 AND is_active = TRUE;

-- Example: Get enrollment history for employee
-- SELECT * FROM face_enrollments WHERE emp_id = 1 ORDER BY enrolled_at DESC;

-- Example: When enrolling new face, first deactivate old ones
-- UPDATE face_enrollments SET is_active = FALSE WHERE emp_id = 1 AND is_active = TRUE;
-- Then insert new record
-- INSERT INTO face_enrollments (emp_id, photo_path, face_descriptors) VALUES (1, '/uploads/emp1_face.jpg', 'descriptor_data');
