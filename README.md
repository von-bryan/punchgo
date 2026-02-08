# PunchGo - Employee DTR with Face Recognition

A Flutter application for employee Daily Time Record (DTR) with face recognition capabilities.

## Features

- ✅ **Face Enrollment**: Register employee faces for recognition
- ✅ **Face Recognition**: Automatic employee identification via camera
- ✅ **Time In/Out**: Record attendance using face recognition
- ✅ **Attendance Tracking**: View daily attendance records
- ✅ **Employee Management**: Add, view, and manage employees

## Database Structure

### Your Current Database Tables

The app uses the existing database structure from `punchgo.db`:

#### 1. **info** table (Employee Information)
This table already exists with all necessary columns. **NO CHANGES NEEDED**.

The app uses these existing columns:
- `emp_code` - Employee code (Primary Key)
- `emp_id` - Employee ID
- `surname` - Last name
- `first_name` - First name  
- `middle_name` - Middle name
- `sex` - Gender
- `email` - Email address
- `status` - Employment status (Active/Inactive)
- `face_descriptors` - **Already exists!** Stores face recognition data
- All other columns remain as they are

#### 2. **login** table (Attendance Records)
This table already exists with all necessary columns. **NO CHANGES NEEDED**.

The app uses these existing columns:
- `login_id` - Login record ID (Primary Key)
- `emp_id` - Employee ID (Foreign Key)
- `time` - Time of login (HH:mm:ss)
- `date` - Date of login (YYYY-MM-DD)
- `state` - Login state ('IN' or 'OUT')
- `login_status` - Status/method (e.g., 'Face Recognition')
- `sync_id`, `swipe`, `original_time`, `changed_by`, `change_on`, `remarks` - All remain available for your use

## ✅ DATABASE REQUIREMENTS

### **GOOD NEWS: NO DATABASE CHANGES REQUIRED!**

Your existing database structure is **already compatible** with this app. You don't need to:
- Add any new tables
- Add any new columns
- Modify existing columns

The `face_descriptors` column in your `info` table is already there and will be used to store face recognition data.

## Installation & Setup

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Run the App

```bash
flutter run
```

## How to Use

### 1. Add Employees
- Go to **Employees** tab
- Tap the **+** button
- Fill in employee details (ID, Name, etc.)
- Save

### 2. Enroll Face
- In **Employees** tab, tap the menu (⋮) on an employee
- Select **Enroll Face**
- Position face in the camera frame
- Wait for green border (face detected)
- Tap **Capture Face** button
- Face data is saved to `face_descriptors` column

### 3. Time In/Out
- Go to **Time In/Out** tab
- Position your face in the camera
- App will automatically recognize you
- Tap **Confirm** to record attendance
- System automatically determines if it's Time IN or Time OUT based on last record

### 4. View Attendance
- Go to **Attendance** tab
- See today's attendance for all employees
- Shows Time In and Time Out for each employee
- Pull down to refresh

## Permissions Required

The app requires these permissions (already configured):
- **Camera** - For face recognition
- **Storage** - For local database

## Technical Details

### Face Recognition
- Uses Google ML Kit Face Detection
- Extracts facial landmarks and features
- Stores face descriptors as JSON in database
- Compares faces with 60% similarity threshold
- Works in real-time

### Database
- Uses SQLite (sqflite package)
- Local storage on device
- Compatible with your existing punchgo.db structure
- Auto-creates tables if they don't exist

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── employee.dart         # Employee model
│   └── login_record.dart     # Login record model
├── screens/
│   ├── home_screen.dart      # Main navigation
│   ├── time_in_out_screen.dart      # Face recognition & attendance
│   ├── attendance_screen.dart       # Daily attendance view
│   ├── employee_list_screen.dart    # Employee management
│   ├── add_employee_screen.dart     # Add new employee
│   ├── face_enrollment_screen.dart  # Face registration
│   └── employee_detail_screen.dart  # Employee details & history
└── services/
    ├── database_helper.dart         # SQLite operations
    └── face_recognition_service.dart # Face detection & matching
```

## Dependencies

- `camera` - Camera access
- `google_mlkit_face_detection` - Face detection
- `sqflite` - Database
- `path_provider` - File paths
- `intl` - Date formatting
- `permission_handler` - Permissions
- `image` - Image processing

## Notes

- Face recognition works best in good lighting
- Front camera is used by default
- Face data is stored locally for privacy
- Attendance is recorded in local SQLite database
- All existing database columns are preserved and available

## Troubleshooting

### Camera not working
- Check camera permissions in device settings
- Ensure camera hardware is available

### Face not detected
- Ensure good lighting
- Look directly at camera
- Keep face centered in frame

### Face not recognized
- Re-enroll the face with better lighting
- Ensure face is clearly visible during enrollment
- Try enrolling from front camera

---

**Your database is ready to go! No SQL commands needed.**
