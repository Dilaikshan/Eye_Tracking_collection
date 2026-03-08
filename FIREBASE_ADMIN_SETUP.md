# Firebase Admin Setup Instructions

## Setting Up Firebase Authentication for Admin Access

To enable admin access to view collected data, you need to configure Firebase Authentication and create an admin user.

### Step 1: Enable Firebase Authentication

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. In the left sidebar, click on **Authentication**
4. Click on **Get Started** (if not already enabled)
5. Go to the **Sign-in method** tab
6. Enable **Email/Password** authentication:
   - Click on **Email/Password**
   - Toggle **Enable** to ON
   - Click **Save**

### Step 2: Create Admin User

1. In the Firebase Console, go to **Authentication** > **Users**
2. Click **Add user**
3. Enter admin credentials:
   - **Email**: your-admin@example.com (or your preferred email)
   - **Password**: Create a secure password
4. Click **Add user**

### Step 3: Update Firestore Security Rules

To secure your data, update your Firestore security rules:

1. Go to **Firestore Database** > **Rules**
2. Update the rules to allow authenticated users to read data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow anyone to write sessions (for data collection)
    match /sessions/{sessionId} {
      allow write: if true;

      // Only authenticated admin users can read
      allow read: if request.auth != null;

      // Allow access to subcollections (samples)
      match /samples/{document=**} {
        allow write: if true;
        allow read: if request.auth != null;
      }
    }
  }
}
```

3. Click **Publish**

## Using the Admin Features

### Accessing Admin Panel

1. Launch the app
2. On the **Language Selection** screen, tap the **Admin icon** (🔒) in the top-right corner
3. Enter your admin email and password
4. You'll be redirected to the **Data Viewer** screen

### Viewing Collected Data

The Data Viewer shows all collection sessions with:

- Participant name and details
- Blindness type and visual characteristics
- Session start time and status
- Total number of samples collected
- Session ID

### Exporting Data to CSV

1. In the Data Viewer, find the session you want to export
2. Tap on the session to expand details
3. Click the **Export to CSV** button
4. The CSV file will be saved to your device's storage
5. A notification will show the file path

### CSV File Format

The exported CSV includes the following columns:

**Timing & Context:**

- Timestamp
- Mode (calibration, pulse, moving)
- Color Label
- Target X, Target Y (where user should look)

**MediaPipe Iris Tracking:**

- Left Iris X, Y
- Right Iris X, Y
- Left/Right Eye Open status
- Confidence score

**ML Kit Data:**

- Gaze Estimate X, Y
- Head Euler Angles (X, Y, Z)
- Left/Right Eye Open probability
- Confidence score

**Azure Cognitive Services:**

- Gaze Origin X, Y
- Left/Right Pupil positions
- Confidence score

**Metadata:**

- Overall Confidence
- Speed Label (for moving phase)
- Participant information

## Understanding the Data Structure

### Firestore Database Structure

```
sessions/
  └── {sessionId}
      ├── userId: "Dilaikshan"
      ├── participantProfile: {...}
      ├── screenSize: {width, height}
      ├── consentGiven: true
      ├── startTime: timestamp
      ├── status: "active" | "completed"
      ├── totalSamples: 1234
      └── samples/
          ├── chunk_0
          │   ├── chunkIndex: 0
          │   ├── sampleCount: 30
          │   ├── timestamp: timestamp
          │   └── samples: [
          │       {
          │         timestamp: 1234567890,
          │         target: {x: 0.5, y: 0.5},
          │         mode: "calibration",
          │         color: "red",
          │         mediapipe: {...},
          │         mlkit: {...},
          │         azure: {...},
          │         fused: {
          │           gaze: {x: 0.48, y: 0.52},
          │           leftPupil: {...},
          │           rightPupil: {...}
          │         },
          │         metadata: {
          │           overallConfidence: 0.85,
          │           ambientLight: 0.5,
          │           deviceOrientation: "portraitUp"
          │         }
          │       },
          │       ...
          │     ]
          ├── chunk_1
          └── chunk_2
```

### Why Coordinates Are in Subcollections

The coordinates and eye tracking data are NOT in the main session document. They are stored in the `samples` subcollection under each session. This is by design to:

1. **Prevent document size limits**: Firestore has a 1MB limit per document
2. **Enable efficient batch uploads**: Samples are saved in chunks of 30
3. **Allow incremental data collection**: New chunks can be added without rewriting the entire session

### To View Sample Coordinates in Firebase Console

1. Go to **Firestore Database**
2. Navigate to **sessions** collection
3. Click on a session document (e.g., the one with userId "Dilaikshan")
4. Click on the **samples** subcollection
5. Open any chunk document (e.g., `chunk_0`)
6. You'll see the `samples` array with all coordinate data

## Troubleshooting

### "No data collected yet"

- Ensure you've completed at least one data collection session
- Check that the session has samples uploaded (totalSamples > 0)
- Verify Firestore security rules allow authenticated reads

### Export fails

- Grant storage permissions when prompted
- Check device storage space
- Ensure the session has sample data in subcollections

### Authentication fails

- Verify the email and password are correct
- Check Firebase Authentication is enabled
- Ensure the user exists in Firebase Console > Authentication > Users

## Security Notes

⚠️ **Important**: Only share admin credentials with authorized researchers. The admin can view all participant data including:

- Personal information (name, age)
- Medical details (blindness type, vision acuity)
- Complete eye tracking coordinates

Consider implementing additional security measures for production use:

- Two-factor authentication
- IP whitelisting
- Audit logging
- Regular password rotation
