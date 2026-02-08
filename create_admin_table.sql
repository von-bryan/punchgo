-- Manual script to create the admin table
-- Run this in SQLyog or MySQL command line if auto-creation fails

USE punchgo;

-- Create admin table if it doesn't exist
CREATE TABLE IF NOT EXISTS admin (
  admin_id INT AUTO_INCREMENT PRIMARY KEY,
  emp_id INT NOT NULL UNIQUE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by INT,
  INDEX idx_emp_id (emp_id),
  FOREIGN KEY (emp_id) REFERENCES info(emp_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Verify table was created
SHOW TABLES LIKE 'admin';

-- Show table structure
DESCRIBE admin;

-- Optional: Insert your first admin (replace 1 with your employee ID)
-- INSERT INTO admin (emp_id, created_by) VALUES (1, 1);
