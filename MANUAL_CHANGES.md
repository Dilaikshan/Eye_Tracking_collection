# Manual Changes & Configuration Guide

This file documents every change that **cannot be done automatically** and requires
your direct action before the app will work correctly.

---

## 1. Azure Cognitive Services Credentials

**File:** `.env` (root of project)

You must add your Azure Face API credentials to the `.env` file:

```env
AZURE_FACE_ENDPOINT=https://YOUR-RESOURCE-NAME.cognitiveservices.azure.com
AZURE_FACE_API_KEY=YOUR-32-CHAR-API-KEY-HERE
```

### How to get these:
1. Go to [portal.azure.com](https://portal.azure.com)
2. Create a **"Face API"** resource (Cognitive Services → Face)
3. Choose a region (e.g., East US)
4. After deployment, go to **Keys and Endpoint**
5. Copy **Key 1** → `AZURE_FACE_API_KEY`
6. Copy the **Endpoint URL** → `AZURE_FACE_ENDPOINT`

> ⚠️ **Never commit your `.env` file to git.** It is already listed in `.gitignore`.

---

## 2. Firebase Firestore Security Rules

In the **Firebase Console → Firestore → Rules**, update to allow write access:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write to sessions collection
    match /sessions/{sessionId} {
      allow read, write: if true;  // For research prototype
      match /samples/{chunkId} {
        allow read, write: if true;
      }
    }
  }
}
```

> For production, replace `if true` with proper authentication rules.

---

## 3. Android Permissions – `AndroidManifest.xml`

**File:** `android/app/src/main/AndroidManifest.xml`

Ensure these permissions are present inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-feature android:name="android.hardware.camera.front" android:required="true" />
```

---

## 4. Android minSdkVersion

**File:** `android/app/build.gradle.kts`

Ensure `minSdk` is set to **24** (required by Google ML Kit Face Mesh):

```kotlin
android {
    defaultConfig {
        minSdk = 24
        targetSdk = 35
    }
}
```

---

## 5. Camera Rotation Verification (Device-Specific)

The app uses the camera sensor's `sensorOrientation` to set the correct
`InputImageRotation` for MediaPipe. This works correctly on most Android devices.

**If iris dots appear in the wrong position on your specific device:**

Open `lib/screens/collection_grid_screen.dart` and find `_getImageRotation()`.
Try forcing a specific rotation to see which one aligns the dots correctly:

```dart
// Try each value to find which works for your device:
return InputImageRotation.rotation270deg;  // Most front cameras (Android)
return InputImageRotation.rotation90deg;   // Some older devices
return InputImageRotation.rotation0deg;    // If already correct
```

---

## 6. MediaPipe Face Mesh – Mesh Point Count Requirement

The service requires **478 mesh points** (`meshPoints.length < 478` check).
This is the full face mesh with iris landmarks.

If you see `"Eyes not detected"` even when your face is clearly visible:
- Ensure good lighting (front-facing light, no backlight)
- Hold the device ~30–60 cm from your face
- The face mesh detection needs a **clear, mostly-frontal face view**

---

## 7. What Was Changed Automatically (Summary of Code Changes)

### `lib/services/mediapipe_service.dart`
- ✅ Coordinates now **normalized to [0,1]** based on image width/height (were raw pixels before)
- ✅ Added `rawLeftIrisCenterPx` / `rawRightIrisCenterPx` fields for overlay rendering
- ✅ Fixed `_isEyeOpen` threshold from `> 5` to `> 3` (more sensitive)

### `lib/models/eye_tracking_data.dart`
- ✅ Added `rawLeftIrisCenterPx`, `rawRightIrisCenterPx`, `imageWidth`, `imageHeight` fields
  to `MediaPipeIrisData` (optional, only used for camera preview overlay)

### `lib/services/mlkit_service.dart`
- ✅ Gaze estimate now **normalized to [0,1]** (was raw pixel position before)
- ✅ Head-pose gaze offset scaled correctly for normalized space (`0.003` not `0.05`)

### `lib/services/data_fusion_service.dart`
- ✅ **Removed the confidence = 0 when no services detect face** — now defaults to `0.1`
- ✅ Confidence is averaged only across **sources that actually detected** (not diluted by 3)
- ✅ No samples are dropped — all timing/target metadata is preserved

### `lib/screens/collection_grid_screen.dart`
- ✅ **Removed `overallConfidence < 0.6` filter** — all samples are now saved to Firestore
- ✅ Fixed `_getImageRotation()` to use **actual camera sensor orientation** (was always `rotation0deg`)
- ✅ Added `setState()` call in camera stream so iris dots **repaint in real time**
- ✅ Added **`_IrisDotPainter`** — green iris/pupil dots shown on camera preview during alignment
- ✅ Added **eye detection status indicator** (green/red badge showing "Eyes detected ✓")

---

## 8. Firebase Firestore Data Structure

Data is stored at:
```
sessions/{sessionId}/samples/chunk_N
```

Each chunk contains up to 30 samples. Each sample includes:
- `timestamp` — milliseconds since epoch
- `target` — `{x, y}` normalized [0,1] where the dot was shown
- `mode` — `"calibration"`, `"pulse"`, or `"moving"`
- `color` — color label (`"red"`, `"yellow"`, etc.)
- `mediapipe` — iris centers, pupil centers, eye open flags, confidence
- `mlkit` — head pose (yaw/pitch/roll), gaze estimate, eye open probabilities
- `azure` — pupil positions, head pose (only when Azure credentials set)
- `fused` — weighted average of all sources
- `metadata` — overall confidence, ambient light, device orientation

Samples with `mediapipe: null` / `mlkit: null` are still saved with
`metadata.overallConfidence: 0.1` to preserve timing and target data.

---

## 9. Testing Checklist

- [ ] Run on **physical Android device** (not emulator — camera required)
- [ ] Grant **camera permission** on first launch
- [ ] Verify iris green dots appear on camera preview during alignment
- [ ] Check "Eyes detected ✓" badge turns green when face is visible
- [ ] Press "I am aligned" → "Start Data Collection"
- [ ] After session, verify data in **Firebase Console → Firestore → sessions**
- [ ] Confirm `mediapipe` field is **not null** in saved samples
- [ ] Add Azure credentials to `.env` for cloud-side processing

---

## 10. Known Limitations

| Issue | Status | Notes |
|-------|--------|-------|
| Azure integration | ⚠️ Requires credentials | Add to `.env` file |
| iOS support | ❌ Not tested | Face Mesh is Android-only |
| Ambient light sensor | 🔧 Placeholder (0.5) | Requires `sensors_plus` package |
| Gaze → screen mapping | 🔧 Approximate | Full calibration model needed for research accuracy |
| Eye open threshold | 🔧 Tuned to `> 3px` | May need adjustment per device camera resolution |
