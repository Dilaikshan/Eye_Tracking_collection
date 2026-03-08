# Recent Updates - Eye Tracking Collection App

## Summary of Changes

### 1. ✅ Improved Moving Phase Behavior

**Problem**: The moving dot jumped randomly too fast, making it difficult for users to follow.

**Solution**:

- **Slowed down speeds**: Changed from 600/400/200ms to 1200/800/500ms intervals
- **Added line pattern movement**: Instead of random jumps, the dot now follows predictable patterns:
  - Horizontal lines (left to right, right to left)
  - Vertical lines (top to bottom, bottom to top)
  - U-shapes
  - Diagonal patterns
- **Extended duration**: Increased from 10 seconds to 15 seconds per speed level
- This makes it much easier for partially blind users to track the moving target

### 2. ✅ Hide Camera Preview During Data Collection

**Problem**: The camera preview was distracting users during data collection.

**Solution**:

- Camera preview now only shows during the initial alignment phase
- Once "Start Data Collection" is clicked, the camera preview is hidden
- Users can focus on the colored dots without distraction
- Camera continues recording eye tracking data in the background

### 3. ✅ Admin Login System

**New Feature**: Secure admin access to view collected data

**Implementation**:

- Added admin login button (🔒 icon) in top-right corner of Language Selection screen
- Uses Firebase Authentication for secure login
- Only authorized users with correct email/password can access data
- Supports sign-out functionality

**Setup Required**:

1. Enable Email/Password authentication in Firebase Console
2. Create admin user with email and password
3. See `FIREBASE_ADMIN_SETUP.md` for detailed instructions

### 4. ✅ Data Viewer Screen

**New Feature**: View and manage all collected sessions

**Features**:

- Lists all data collection sessions
- Shows participant details:
  - Name, age, blindness type
  - Dominant eye, vision acuity
  - Glasses usage, consent status
  - Session start time and status
  - Total samples collected
- Expandable cards to see full session details
- Real-time updates using Firestore streams

### 5. ✅ CSV Export Functionality

**New Feature**: Export session data to CSV for analysis

**Implementation**:

- Export button for each session
- Generates comprehensive CSV with all data points:
  - **Timing**: Timestamp, mode, color label
  - **Target**: Where user should be looking (x, y coordinates)
  - **MediaPipe**: Left/right iris positions, eye open status, confidence
  - **ML Kit**: Gaze estimate, head pose angles, eye probabilities
  - **Azure**: Gaze origin, pupil positions
  - **Fused**: Combined weighted average data
  - **Metadata**: Overall confidence, speed label, participant info
- Saves to device storage with timestamp in filename
- Shows save location in notification

### 6. ✅ Fixed Data Structure Understanding

**Clarification**: The Firestore data structure is CORRECT

**Explanation**:
The session document you see contains metadata only:

```
sessions/{sessionId}/
  - userId
  - participantProfile
  - screenSize
  - consentGiven
  - startTime
  - status
  - totalSamples
```

**All coordinate data is in subcollections**:

```
sessions/{sessionId}/samples/
  - chunk_0
  - chunk_1
  - chunk_2
  ...each chunk contains 30 samples with full eye tracking coordinates
```

This design prevents hitting Firestore's 1MB document limit and enables efficient batch uploads.

## Files Added

1. **lib/screens/admin_login_screen.dart** - Admin authentication UI
2. **lib/screens/data_viewer_screen.dart** - Session viewer and CSV export
3. **FIREBASE_ADMIN_SETUP.md** - Complete setup instructions

## Files Modified

1. **lib/screens/collection_grid_screen.dart**

   - Added line pattern movement for moving phase
   - Slowed down movement speeds
   - Added camera hiding during data collection
   - Added `_showCamera` and `_lineStepIndex` variables

2. **lib/screens/language_selection_screen.dart**

   - Added admin login button in app bar

3. **lib/main.dart**

   - Added routes for admin login and data viewer screens
   - Imported new screen files

4. **pubspec.yaml**
   - Added `firebase_auth: ^5.4.4` dependency

## How to Use New Features

### For Researchers (Admin Access)

1. Set up Firebase Authentication (see FIREBASE_ADMIN_SETUP.md)
2. Create admin user in Firebase Console
3. Launch app and tap admin icon on language selection screen
4. Login with admin credentials
5. View all sessions and export to CSV for analysis

### For Participants

The data collection experience is now improved:

- Camera is hidden during collection (less distraction)
- Moving dots follow smooth line patterns
- Slower speeds are easier to track
- Visual timer shows remaining time for each phase

## Next Steps

1. **Set up Firebase Authentication**:

   ```
   - Enable Email/Password in Firebase Console
   - Create admin user account
   - Update Firestore security rules
   ```

2. **Test the improvements**:

   ```
   flutter run
   ```

3. **Collect test data**:

   - Go through a complete session
   - Login as admin
   - Verify data is visible
   - Export to CSV and check the data

4. **Verify CSV export location**:
   - The file is saved to external storage
   - Path shown in notification
   - Can be accessed via file manager or ADB

## Technical Notes

### CSV Export Location

- Android: `/storage/emulated/0/Android/data/com.research.eyetracking/files/`
- Filename format: `eye_tracking_{sessionId}_{timestamp}.csv`

### Data Collection Timeline

- Calibration: 6 colors × 2 seconds = 12 seconds
- Pulse: 6 colors × 3 repeats × 2 seconds = 36 seconds
- Moving: 3 speeds × 15 seconds = 45 seconds
- **Total**: ~93 seconds (~1.5 minutes of active collection)

### Sample Count Estimation

- Calibration: ~6 samples
- Pulse: ~18 samples
- Moving slow: ~12-13 samples
- Moving medium: ~18-19 samples
- Moving fast: ~30 samples
- **Total**: ~85-90 samples per session

(Actual counts may vary based on quality filtering - samples with confidence < 60% are discarded)

## Troubleshooting

### "No data collected yet" in Data Viewer

- Complete at least one full data collection session
- Check that totalSamples > 0 in Firestore
- Verify you're logged in as admin

### CSV export fails

- Grant storage permissions when prompted
- Check device has free space
- Ensure session has samples in subcollections

### Camera not hiding

- Make sure you clicked "Start Data Collection"
- Check that `_showCamera` is set to false after starting
- Restart the app if issue persists

### Moving dot still too fast

- The speeds are now 1200ms, 800ms, 500ms
- If still too fast, adjust in collection_grid_screen.dart line ~300
- Change values in `speedDurations` array

## Questions or Issues?

Refer to the main README.md and FIREBASE_ADMIN_SETUP.md for more details.
