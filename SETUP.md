# Setup Instructions

## Prerequisites
- Flutter SDK installed
- Android Studio or VS Code with Flutter extensions
- Android device or emulator with camera

## Installation Steps

### 1. Install Dependencies
Open terminal in project directory and run:
```bash
flutter pub get
```

### 2. For Android (Build Configuration)
Make sure your `android/app/build.gradle` has:
```gradle
android {
    compileSdkVersion 33  // or higher
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 33
    }
}
```

### 3. Run the App
```bash
# For Android
flutter run

# Or for specific device
flutter devices
flutter run -d <device_id>
```

## First Time Setup

1. **Launch the app** - It will automatically create the database
2. **Grant permissions** - Allow camera access when prompted
3. **Add employees** - Go to Employees tab, tap + button
4. **Enroll faces** - Select employee → Enroll Face
5. **Test attendance** - Go to Time In/Out tab

## Database Information

### Your Current Database is READY!
✅ No changes needed to your existing `punchgo.info` table
✅ No changes needed to your existing `punchgo.login` table  
✅ The `face_descriptors` column already exists

### The app will:
- Use existing employees from `info` table
- Store face data in `face_descriptors` column
- Record attendance in `login` table with state 'IN' or 'OUT'

## Testing Face Recognition

1. **Good Lighting**: Face recognition works best in well-lit areas
2. **Front Camera**: Use front-facing camera for enrollment
3. **Center Face**: Keep face centered in the frame
4. **Wait for Green**: Green border = face detected successfully
5. **60% Threshold**: Faces must match at least 60% to be recognized

## Common Commands

```bash
# Get dependencies
flutter pub get

# Run on Android
flutter run

# Build APK
flutter build apk

# Build release APK
flutter build apk --release

# Check devices
flutter devices

# Clean build
flutter clean
flutter pub get
flutter run
```

## Permissions (Already Configured)

The app requests:
- **Camera** - For face detection and recognition
- **Storage** - For local SQLite database

These are configured in `AndroidManifest.xml`

## Troubleshooting

### Build Errors
```bash
flutter clean
flutter pub get
flutter run
```

### Camera Issues
- Check device permissions in Settings
- Restart the app
- Try on physical device (emulator cameras can be limited)

### Database Issues
- App creates database automatically on first run
- Located in app's private storage
- Existing data is preserved

### Gradle Issues
If you get Gradle errors:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter run
```

## Project Features Summary

✅ **Face Enrollment** - Register employee faces
✅ **Face Recognition** - Auto-identify employees  
✅ **Time In/Out** - Record attendance automatically
✅ **Attendance View** - See daily attendance
✅ **Employee Management** - CRUD operations
✅ **Works with existing DB** - No migration needed

---

**Ready to go! Just run `flutter pub get` and `flutter run`**
