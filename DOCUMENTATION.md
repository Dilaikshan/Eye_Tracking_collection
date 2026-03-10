# Eye Tracking Collection — Comprehensive Documentation

> A Flutter-based mobile research application that collects eye tracking data from participants (including those who are blind or visually impaired) using a combination of on-device ML models (Google MediaPipe, ML Kit) and an optional cloud service (Azure Cognitive Services). Data is stored in Firebase Firestore and can be exported as CSV for machine-learning research.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Technology Stack & Dependencies](#2-technology-stack--dependencies)
3. [Repository Structure](#3-repository-structure)
4. [How the App Works — User Flow](#4-how-the-app-works--user-flow)
5. [Experiment Phases & Data Collection Protocol](#5-experiment-phases--data-collection-protocol)
6. [Core Services](#6-core-services)
7. [Data Models](#7-data-models)
8. [Data Pipeline — End-to-End Flow](#8-data-pipeline--end-to-end-flow)
9. [Firestore Database Schema](#9-firestore-database-schema)
10. [CSV Export Format](#10-csv-export-format)
11. [UI Screens](#11-ui-screens)
12. [Widgets](#12-widgets)
13. [Configuration & Setup](#13-configuration--setup)
14. [Admin Features](#14-admin-features)
15. [Accessibility & Multi-Language Support](#15-accessibility--multi-language-support)
16. [Special Features](#16-special-features)
17. [Known Limitations & Troubleshooting](#17-known-limitations--troubleshooting)

---

## 1. Project Overview

**Eye Tracking Collection** is a cross-platform Flutter app (Android & iOS) designed for academic research. Its primary purpose is to collect labeled eye-tracking data from participants — with a focus on users who are visually impaired — to train and evaluate gaze-estimation models (e.g., CNNs).

### What the App Does

| Capability | Detail |
|---|---|
| **Camera capture** | Streams front-facing camera frames at ~10 FPS |
| **On-device inference** | Runs MediaPipe Face Mesh (478 landmarks) and ML Kit Face Detection simultaneously |
| **Optional cloud inference** | Sends frames to Azure Cognitive Services Face API for pupil and head-pose data |
| **Data fusion** | Combines results from all sources via weighted averaging |
| **Structured storage** | Uploads batched samples to Firebase Firestore |
| **CSV export** | Admins can export any session as a CNN-ready CSV file |
| **Accessibility** | Text-to-speech instructions, haptic feedback, multilingual UI |

---

## 2. Technology Stack & Dependencies

### Framework
- **Flutter** ≥ 3.0 / **Dart** ≥ 3.0

### Key Packages

| Category | Package | Version | Purpose |
|---|---|---|---|
| **Camera** | `camera` | 0.11.0+2 | Front-facing camera streaming |
| **ML — Face Mesh** | `google_mlkit_face_mesh_detection` | ^0.4.0 | 478-point MediaPipe facial landmarks |
| **ML — Face Detection** | `google_mlkit_face_detection` | ^0.13.0 | Head pose, eye-open probabilities |
| **ML — Commons** | `google_mlkit_commons` | ^0.11.0 | Shared ML Kit types / `InputImage` |
| **Firebase** | `firebase_core` | ^3.15.2 | Firebase initialization |
| | `cloud_firestore` | ^5.6.12 | NoSQL database (sample storage) |
| | `firebase_storage` | ^12.4.10 | File storage |
| | `firebase_auth` | ^5.7.0 | Admin authentication |
| **HTTP / Azure** | `http` | ^1.6.0 | REST calls to Azure Face API |
| | `flutter_dotenv` | ^6.0.0 | Load Azure credentials from `.env` |
| **Image processing** | `image` | ^4.7.2 | JPEG encoding of 64×64 eye crops |
| **TTS** | `flutter_tts` | ^4.2.5 | Text-to-speech instructions |
| **Haptics** | `vibration` | ^3.1.5 | Haptic feedback |
| **State** | `provider` | ^6.1.5+1 | Widget state management |
| **Utilities** | `uuid` | ^4.5.2 | Generate unique session / sample IDs |
| | `device_info_plus` | ^12.3.0 | Device model / OS version |
| | `path_provider` | ^2.1.5 | File system paths for CSV export |
| | `shared_preferences` | ^2.5.3 | Persist first-run permission flag |
| | `intl` | ^0.20.2 | Localization |
| | `permission_handler` | ^11.3.1 | Runtime camera permission |

### Android Requirements
- `minSdkVersion` 24 (required by Google ML Kit)
- `targetSdkVersion` 35
- `CAMERA` permission in `AndroidManifest.xml`
- `google-services.json` placed in `android/app/`

---

## 3. Repository Structure

```
Eye_Tracking_collection/
├── lib/                            # All Dart source code
│   ├── main.dart                   # App entry point, routing table
│   ├── firebase_options.dart       # Auto-generated Firebase config
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart     # Colour palette
│   │   │   ├── app_strings.dart    # Localised strings
│   │   │   ├── app_theme.dart      # ThemeData configuration
│   │   │   └── collection_constants.dart  # Thresholds & timing constants
│   │   ├── services/
│   │   │   ├── firebase_initializer.dart  # Firebase.initializeApp()
│   │   │   ├── haptics_service.dart       # Vibration wrapper
│   │   │   └── tts_service.dart           # flutter_tts wrapper
│   │   └── utils/
│   │       ├── camera_utils.dart          # YUV → NV21 conversion
│   │       └── coordinate_utils.dart     # Normalised ↔ pixel helpers
│   │
│   ├── models/
│   │   ├── eye_tracking_data.dart  # EyeTrackingData, MediaPipeIrisData,
│   │   │                           #   MLKitFaceData, AzureFaceData
│   │   ├── eye_tracking_sample.dart
│   │   ├── mediapipe_data.dart     # MediaPipeData (pixel-space variant)
│   │   ├── mlkit_data.dart         # MLKitData
│   │   ├── azure_data.dart         # AzureData
│   │   ├── user_profile.dart       # Participant profile
│   │   └── collection_session.dart # Session metadata
│   │
│   ├── services/
│   │   ├── mediapipe_service.dart      # MediaPipe Face Mesh inference
│   │   ├── mlkit_face_service.dart     # ML Kit Face Detection inference
│   │   ├── azure_face_service.dart     # Azure Cognitive Services calls
│   │   ├── data_collection_service.dart# Orchestrator service
│   │   ├── firestore_service.dart      # Firestore read / write
│   │   ├── research_export_service.dart# CSV export (56 columns)
│   │   ├── data_fusion_service.dart    # Weighted multi-source averaging
│   │   ├── mlkit_service.dart          # (legacy / alternative MLKit path)
│   │   ├── mlkit_data.dart
│   │   └── azure_service.dart          # (legacy / alternative Azure path)
│   │
│   ├── screens/
│   │   ├── permission_screen.dart      # First-launch permission request
│   │   ├── language_selection_screen.dart
│   │   ├── user_agreement_screen.dart
│   │   ├── user_form_screen.dart       # Participant registration
│   │   ├── user_profile_screen.dart
│   │   ├── collection_grid_screen.dart # Main data collection UI (~40 KB)
│   │   ├── session_summary_screen.dart
│   │   ├── diagnostic_screen.dart      # Live service diagnostics (~25 KB)
│   │   ├── admin_login_screen.dart
│   │   └── data_viewer_screen.dart     # Admin data browser & CSV export
│   │
│   └── widgets/
│       ├── accessible_text_field.dart
│       ├── alignment_guide.dart
│       ├── camera_preview_frame.dart
│       ├── eye_tracking_overlay.dart   # Real-time gaze visualisation
│       ├── primary_button.dart
│       └── pulsing_target.dart
│
├── android/                        # Android platform code
├── ios/                            # iOS platform code
├── web/ / linux/ / macos/ / windows/ # Other platform stubs
├── test/                           # Unit & widget tests
├── pubspec.yaml                    # Dependencies
├── firebase.json                   # Firebase project config
├── .env                            # Azure credentials (NOT committed)
├── .gitignore
├── analysis_options.yaml           # Dart linter rules
├── DOCUMENTATION.md                # ← this file
├── IMPLEMENTATION_SUMMARY.md
├── RECENT_UPDATES.md
├── FIREBASE_ADMIN_SETUP.md
└── MANUAL_CHANGES.md
```

---

## 4. How the App Works — User Flow

```
App Launch
    │
    ▼
[PermissionScreen]          ← First launch only: requests CAMERA permission
    │
    ▼
[LanguageSelectionScreen]   ← Participant selects language (English / Tamil / Sinhala)
    │
    ▼
[UserAgreementScreen]       ← Informed-consent form; participant must accept
    │
    ▼
[UserFormScreen]            ← Participant fills in:
    │                            name, age, blindness type, dominant eye,
    │                            vision acuity (1–10), glasses use
    ▼
[CollectionGridScreen]      ← Main experiment (3 phases, ~90 s total)
    │                          Camera streams; MediaPipe + ML Kit run per frame
    ▼
[SessionSummaryScreen]      ← Shows total samples collected & session ID
    │
    ▼
(done)
```

**Admin path** (hidden entry point, e.g., triple-tap logo):
```
[AdminLoginScreen]   →   [DataViewerScreen]   →   CSV export
```

---

## 5. Experiment Phases & Data Collection Protocol

Data collection happens inside `CollectionGridScreen`. The experiment consists of three sequential phases driven by `ExperimentPhase` enum.

### Phase 1 — Calibration (~12 seconds)

| Attribute | Value |
|---|---|
| Target positions | 6 fixed grid positions (top-left, top-centre, top-right, bottom-left, bottom-centre, bottom-right) |
| Stimulus colours | Red, Yellow, Green, Blue, Magenta, Cyan |
| Duration per target | 2 seconds |
| Purpose | Establish baseline gaze-to-coordinate mapping |

The participant is asked to look at a pulsing coloured dot shown in each corner/edge of the screen in turn.

### Phase 2 — Pulse (~36 seconds)

| Attribute | Value |
|---|---|
| Target positions | Same 6 grid positions |
| Colours | Same 6 colours |
| Repeats per position | 3 |
| Timing | 1.5 s ON → 0.5 s blank → next |
| Purpose | Collect repeated gaze fixation data per position |

### Phase 3 — Moving (~45 seconds)

| Attribute | Value |
|---|---|
| Movement speeds | Slow (1200 ms/step), Medium (800 ms/step), Fast (500 ms/step) |
| Duration per speed | ~15 seconds |
| Patterns | Horizontal sweep, vertical sweep, U-shapes, diagonal paths |
| Purpose | Collect dynamic gaze-tracking data during smooth pursuit |

### Summary

| Phase | Duration | Expected samples |
|---|---|---|
| Calibration | ~12 s | ~20–25 |
| Pulse | ~36 s | ~40–45 |
| Moving | ~45 s | ~20–25 |
| **Total** | **~93 s** | **85–90** |

Samples with confidence < 60% (`CollectionConstants.minConfidence`) are discarded and not stored.

---

## 6. Core Services

### 6.1 MediaPipeService (`lib/services/mediapipe_service.dart`)

**Purpose**: Process camera frames with Google ML Kit Face Mesh Detection (MediaPipe) to extract precise iris and facial geometry.

**Input**: `CameraImage` (YUV_420_888) or `InputImage`

**Output**: `MediaPipeIrisData`

**Processing steps**:
1. Convert `CameraImage` YUV planes to NV21 byte array.
2. Create `InputImage` and run `FaceMeshDetector`.
3. Locate iris landmarks at indices 468–472 (left) and 473–477 (right) out of 478 total landmarks.
4. Compute normalised iris centre coordinates (values in `[0, 1]`).
5. Calculate **Eye Aspect Ratio (EAR)** from 6 eye-contour landmarks:

   ```
   EAR = ( |p2 - p6| + |p3 - p5| ) / ( 2 × |p1 - p4| )
   ```

   EAR > 0.2 → eye is open.

6. Extract 64×64 grayscale JPEG **eye crops** from the Y-plane (for CNN training).
7. Compute normalised **interpupillary distance (IPD)**.
8. Compute eye corner landmarks and face bounding box.
9. Record iris Z-depth.

**Key constants** (see `CollectionConstants`):

| Constant | Value | Meaning |
|---|---|---|
| `_leftIrisStart` | 468 | First left-iris landmark index |
| `_rightIrisStart` | 473 | First right-iris landmark index |
| EAR open threshold | 0.2 | Eye considered open above this |
| Eye crop size | 64×64 px | Grayscale JPEG dimension |
| JPEG quality | 85% | Compression level for eye crops |

---

### 6.2 MLKitFaceService (`lib/services/mlkit_face_service.dart`)

**Purpose**: Detect head pose (Euler angles) and estimate screen gaze from head orientation.

**Input**: `InputImage`

**Output**: `MLKitData`

**Processing steps**:
1. Run `FaceDetector` with `FaceDetectorOptions(enableClassification: true, enableLandmarks: true)`.
2. Extract Euler angles: **yaw** (left/right), **pitch** (up/down), **roll** (tilt).
3. Compute normalised eye centre position from face bounding box.
4. Estimate gaze using linear mapping from head pose:

   ```dart
   // ~1 degree ≈ 0.003 offset in normalised [0, 1] screen space
   gazeX = eyeCentreNorm.dx + (yaw  × 0.003)
   gazeY = eyeCentreNorm.dy + (pitch × 0.003)
   ```

5. Extract eye-open probabilities (0.0–1.0).

---

### 6.3 AzureFaceService (`lib/services/azure_face_service.dart`)

**Purpose**: Optional cloud validation using Azure Cognitive Services Face API.

**Input**: `InputImage` (converted to JPEG internally)

**Output**: `AzureData`

**Key behaviour**:
- Rate-limited to **20 requests per minute** (controlled by `CollectionConstants.azureSampleIntervalSec`).
- Skipped gracefully if `.env` credentials are missing or quota is exceeded.
- Tracks API **latency** in milliseconds per call.
- Provides pupil positions and an independent head-pose estimate for cross-validation.

---

### 6.4 DataCollectionService (`lib/services/data_collection_service.dart`)

**Purpose**: High-level orchestrator that coordinates all inference services and produces a single `EyeTrackingSample` per camera frame.

**Method**: `collectSample(InputImage, targetNormalized, screenSize, mode, colorLabel)`

**Step-by-step**:

```
1. Run MediaPipeService.processInputImage()   ─┐
2. Run MLKitFaceService.processImage()         ├── parallel
3. (optionally) AzureFaceService.processImage()─┘

4. Reject if MediaPipe OR ML Kit returned null
5. Reject if MediaPipe confidence < minIrisConfidence (default: 0.4)

6. _assessQuality():
   - Average confidence across active sources
   - Detect blink (leftEyeOpen == false || rightEyeOpen == false)
   - Classify head movement: 'large' if |yaw|>15° or |pitch|>15°

7. Reject if overallConfidence < minConfidence (default: 0.6)

8. Build EyeTrackingSample with all sub-results + device info +
   participant context
```

---

### 6.5 DataFusionService (`lib/services/data_fusion_service.dart`)

**Purpose**: Combine gaze estimates from multiple sources using reliability-weighted averaging.

**Fusion weights**:

| Source | Weight | Rationale |
|---|---|---|
| MediaPipe (iris) | 50% | Most accurate for precise iris-based gaze |
| ML Kit (head pose) | 30% | Good for context and orientation |
| Azure (cloud) | 20% | Independent validation, slower |

**Formula**:

```
fusedGaze = (mediapipe_gaze × 0.5) + (mlkit_gaze × 0.3) + (azure_gaze × 0.2)
```

Sources that returned `null` are excluded and weights are re-normalised. Confidence is averaged over only the active (non-null) sources.

---

### 6.6 FirestoreService (`lib/services/firestore_service.dart`)

**Purpose**: Persist data to Firebase Firestore.

**Key operations**:

| Method | Description |
|---|---|
| `startSession(profile, screenSize, consentGiven)` | Creates session document; returns session ID |
| `addSamples(userId, sessionId, samples, chunkIndex)` | Batched write of up to 30 samples as a `chunk_N` sub-document |
| `endSession(sessionId)` | Sets `status: "completed"` and records end timestamp |
| `getSessionStats(sessionId)` | Retrieves session document |

**Design decisions**:
- Samples are stored in sub-collections (`sessions/{id}/samples/chunk_N`) to avoid the Firestore 1 MB per-document limit.
- Batch writes are used for efficiency (one round-trip per 30 samples).
- `FieldValue.increment` is used to update `totalSamples` atomically.

---

### 6.7 ResearchExportService (`lib/services/research_export_service.dart`)

**Purpose**: Generate a CNN-ready CSV file from a completed session's Firestore data.

**Output path**: `/storage/emulated/0/Android/data/com.research.eyetracking/files/`

**Filename format**: `eye_tracking_{sessionId}_{timestamp}.csv`

**Columns (56)**: See [Section 10 — CSV Export Format](#10-csv-export-format).

---

## 7. Data Models

### 7.1 EyeTrackingData

The primary in-memory container produced by `DataFusionService`. Serialised via `toFirestore()` when writing to Firestore.

```dart
class EyeTrackingData {
  DateTime timestamp;
  Offset   target;              // Where participant should be looking (normalised)

  MediaPipeIrisData? mediapipeData;   // Iris landmarks, crops, EAR
  MLKitFaceData?     mlkitData;       // Head pose, gaze estimate
  AzureFaceData?     azureData;       // Cloud API result (optional)

  Offset? fusedGaze;            // Weighted average gaze (normalised)
  Offset? fusedLeftPupil;
  Offset? fusedRightPupil;

  String mode;                  // 'calibration' | 'pulse' | 'moving'
  String colorLabel;            // 'red' | 'yellow' | 'green' | 'blue' | 'magenta' | 'cyan'
  String? speedLabel;           // 'slow' | 'medium' | 'fast' (moving phase only)
  double overallConfidence;     // 0.0 – 1.0

  double ambientLight;          // 0.0 – 1.0
  String orientation;           // 'portraitUp'
}
```

### 7.2 MediaPipeIrisData

Extracted by `MediaPipeService`. All coordinates are normalised to `[0, 1]` (relative to camera image dimensions) unless noted.

| Field | Type | Description |
|---|---|---|
| `leftIrisCenter` | `Offset` | Normalised centre of left iris |
| `rightIrisCenter` | `Offset` | Normalised centre of right iris |
| `leftPupilCenter` | `Offset` | Normalised left pupil centre |
| `rightPupilCenter` | `Offset` | Normalised right pupil centre |
| `leftIrisLandmarks` | `List<Offset>` | 5 iris landmark points (left) |
| `rightIrisLandmarks` | `List<Offset>` | 5 iris landmark points (right) |
| `leftEyeOpen` | `bool` | EAR > 0.2 |
| `rightEyeOpen` | `bool` | EAR > 0.2 |
| `confidence` | `double` | Detection confidence 0–1 |
| `leftEyeCropBase64` | `String?` | Base64-encoded 64×64 grayscale JPEG |
| `rightEyeCropBase64` | `String?` | Base64-encoded 64×64 grayscale JPEG |
| `leftEAR` | `double` | Eye Aspect Ratio (left) |
| `rightEAR` | `double` | Eye Aspect Ratio (right) |
| `leftIrisDepth` | `double` | Z-depth from Face Mesh |
| `rightIrisDepth` | `double` | Z-depth from Face Mesh |
| `ipdNormalized` | `double` | Inter-pupillary distance / image width |
| `leftEyeInnerCorner` | `Offset` | Normalised inner corner (left) |
| `leftEyeOuterCorner` | `Offset` | Normalised outer corner (left) |
| `rightEyeInnerCorner` | `Offset` | Normalised inner corner (right) |
| `rightEyeOuterCorner` | `Offset` | Normalised outer corner (right) |
| `faceBox` | `Rect?` | Normalised face bounding box |
| `rawLeftIrisCenterPx` | `Offset?` | Left iris centre in camera pixel space |
| `rawRightIrisCenterPx` | `Offset?` | Right iris centre in camera pixel space |

### 7.3 MLKitFaceData

Extracted by `MLKitFaceService` / `MLKitService`.

| Field | Type | Description |
|---|---|---|
| `gazeEstimate` | `Offset?` | Normalised gaze point computed from head pose |
| `headYaw` | `double` | Left-right rotation (degrees) |
| `headPitch` | `double` | Up-down rotation (degrees) |
| `headRoll` | `double` | Head tilt (degrees) |
| `faceBounds` | `Rect` | Face bounding box in image pixels |
| `leftEyeOpenProbability` | `double` | 0.0–1.0 |
| `rightEyeOpenProbability` | `double` | 0.0–1.0 |
| `confidence` | `double` | Detection confidence 0–1 |

### 7.4 AzureFaceData

Returned by `AzureFaceService`.

| Field | Type | Description |
|---|---|---|
| `leftPupil` | `Offset` | Left pupil position (normalised) |
| `rightPupil` | `Offset` | Right pupil position (normalised) |
| `headPose` | `Map` | `{yaw, pitch, roll}` from Azure |
| `eyeGaze` | `Map` | Azure gaze direction vectors |
| `confidence` | `double` | Azure detection confidence |
| `latencyMs` | `int` | Round-trip API latency |

### 7.5 UserProfile

Participant registration data.

| Field | Type | Description |
|---|---|---|
| `name` | `String` | Participant name |
| `age` | `int` | Age in years |
| `blindnessType` | `String` | e.g. `'congenital'`, `'acquired'`, `'low vision'` |
| `dominantEye` | `String` | `'left'`, `'right'`, or `'both'` |
| `visionAcuity` | `int` | Self-reported scale 1–10 |
| `wearsGlasses` | `bool` | Whether participant uses glasses |
| `languageCode` | `String` | `'en'`, `'ta'`, or `'si'` |
| `consentGiven` | `bool` | Must be `true` to proceed |
| `createdAt` | `DateTime` | Registration timestamp |

### 7.6 CollectionSession

Session-level metadata.

| Field | Type | Description |
|---|---|---|
| `sessionId` | `String` | Firestore document ID |
| `userId` | `String` | Participant name |
| `startTime` | `DateTime` | Session start |
| `endTime` | `DateTime?` | Session end (null while active) |
| `status` | `String` | `'active'` or `'completed'` |
| `totalSamples` | `int` | Running count of stored samples |
| `metadata` | `Map` | Arbitrary extra fields |

### 7.7 EyeTrackingSample

The final per-frame object written to Firestore. Produced by `DataCollectionService` after quality filtering.

```dart
class EyeTrackingSample {
  String   sampleId;          // UUID v4
  DateTime timestamp;
  Offset   targetPixel;       // Target in screen pixels
  Offset   targetNormalized;  // Target in [0, 1]
  String   mode;              // Phase name
  String   colorLabel;
  String?  speedLabel;

  MediaPipeData  mediapipeData;
  MLKitData      mlkitData;
  AzureData?     azureData;

  Map<String, dynamic> deviceInfo;        // Screen size, camera resolution, OS
  Map<String, dynamic> participantContext; // Blindness type, dominant eye, acuity
  Map<String, dynamic> quality;           // confidence, blink flag, headMovement
}
```

---

## 8. Data Pipeline — End-to-End Flow

```
Front Camera (CameraController)
         │
         │ CameraImage (YUV_420_888) @ ~10 FPS
         ▼
  ┌─────────────────────────────────────────────────────┐
  │              DataCollectionService                  │
  │                                                     │
  │  ┌─────────────────────┐  ┌──────────────────────┐ │
  │  │  MediaPipeService   │  │  MLKitFaceService    │ │
  │  │  (Face Mesh 478 pts)│  │  (Face Detection)    │ │
  │  │                     │  │                      │ │
  │  │  • Iris landmarks   │  │  • Head yaw/pitch/   │ │
  │  │    (indices 468-477)│  │    roll              │ │
  │  │  • EAR calculation  │  │  • Eye-open probs    │ │
  │  │  • Eye crops 64×64  │  │  • Gaze estimate     │ │
  │  │  • IPD, Z-depth     │  │    from head pose    │ │
  │  └──────────┬──────────┘  └──────────┬───────────┘ │
  │             │                         │             │
  │             │    ┌────────────────┐   │             │
  │             │    │ AzureFaceService│  │             │
  │             │    │ (rate-limited  │   │             │
  │             │    │  20 req/min)   │   │             │
  │             │    └───────┬────────┘   │             │
  │             └────────────┼────────────┘             │
  │                          ▼                          │
  │               Quality Assessment                    │
  │               • avg confidence                      │
  │               • blink detection                     │
  │               • head movement size                  │
  │                          │                          │
  │                 confidence < 0.6?  → DISCARD        │
  │                          │                          │
  │                          ▼                          │
  │                  EyeTrackingSample                  │
  └──────────────────────────┬──────────────────────────┘
                             │
                  Batch buffer (max 30)
                             │
                             ▼
                   FirestoreService.addSamples()
                             │
                             ▼
               Firestore: sessions/{id}/samples/chunk_N
```

---

## 9. Firestore Database Schema

```
sessions/                                   ← top-level collection
  {sessionId}/                              ← auto-generated document ID
    userId:               "Participant Name"
    participantProfile:
      name:               "Alice"
      age:                32
      blindnessType:      "low vision"
      dominantEye:        "right"
      visionAcuity:       6
      wearsGlasses:       false
      languageCode:       "en"
      consentGiven:       true
      createdAt:          1706745600000     ← Unix ms
    screenSize:
      width:              1080
      height:             2400
    consentGiven:         true
    startTime:            <Firestore Timestamp>
    endTime:              <Firestore Timestamp>   ← null while active
    status:               "active" | "completed"
    totalSamples:         87
    lastUpdated:          <Firestore Timestamp>
    │
    └── samples/                            ← sub-collection
          chunk_0/                          ← up to 30 samples
            chunkIndex:     0
            sampleCount:    30
            timestamp:      <Firestore Timestamp>
            samples: [
              {
                sampleId:   "uuid-v4",
                timestamp:  1706745600123,  ← Unix ms
                target:     { x: 0.1, y: 0.1 },
                mode:       "calibration" | "pulse" | "moving",
                color:      "red",
                speedLabel: "slow",         ← only in moving phase

                mediapipe: {
                  leftIrisCenter:   { x: 0.48, y: 0.51 },
                  rightIrisCenter:  { x: 0.52, y: 0.49 },
                  leftPupilCenter:  { x: 0.48, y: 0.51 },
                  rightPupilCenter: { x: 0.52, y: 0.49 },
                  confidence:       0.92,
                  leftEyeOpen:      true,
                  rightEyeOpen:     true,
                  leftEAR:          0.35,
                  rightEAR:         0.34,
                  leftIrisDepth:    0.50,
                  rightIrisDepth:   0.48,
                  ipdNormalized:    0.25,
                  leftEyeCrop:      "<base64 JPEG string>",
                  rightEyeCrop:     "<base64 JPEG string>",
                  eyeCorners: {
                    leftInner:  { x: 0.44, y: 0.51 },
                    leftOuter:  { x: 0.38, y: 0.51 },
                    rightInner: { x: 0.56, y: 0.49 },
                    rightOuter: { x: 0.62, y: 0.49 }
                  },
                  faceBox: { left: 0.2, top: 0.1, right: 0.8, bottom: 0.9 }
                },

                mlkit: {
                  gazeEstimate: { x: 0.50, y: 0.50 },
                  headPose: { yaw: -2.5, pitch: 1.2, roll: 0.8 },
                  leftEyeOpenProbability:  0.98,
                  rightEyeOpenProbability: 0.97,
                  confidence: 0.88
                },

                azure: {                          ← present every ~3 seconds
                  leftPupil:  { x: 0.48, y: 0.51 },
                  rightPupil: { x: 0.52, y: 0.49 },
                  headPose:   { yaw: -2.2, pitch: 1.1, roll: 0.9 },
                  eyeGaze:    { ... },
                  confidence: 0.91,
                  latencyMs:  420
                },

                fused: {
                  gaze:       { x: 0.50, y: 0.50 },
                  leftPupil:  { x: 0.48, y: 0.51 },
                  rightPupil: { x: 0.52, y: 0.49 }
                },

                metadata: {
                  overallConfidence: 0.89,
                  ambientLight:      0.5,
                  deviceOrientation: "portraitUp"
                }
              },
              ...
            ]
          chunk_1/   ...
          chunk_2/   ...
```

---

## 10. CSV Export Format

Generated by `ResearchExportService`. Each row represents one `EyeTrackingSample`.

| # | Column name | Source | Description |
|---|---|---|---|
| 1 | `sample_id` | Sample | UUID v4 |
| 2 | `session_id` | Session | Firestore session ID |
| 3 | `participant_name` | Profile | Participant name |
| 4 | `timestamp` | Sample | Unix milliseconds |
| 5 | `mode` | Sample | `calibration` / `pulse` / `moving` |
| 6 | `color` | Sample | Stimulus colour label |
| 7 | `speed` | Sample | `slow` / `medium` / `fast` / `""` |
| 8 | `target_x` | Sample | Normalised target X [0, 1] |
| 9 | `target_y` | Sample | Normalised target Y [0, 1] |
| 10 | `mp_left_iris_x` | MediaPipe | Normalised left iris centre X |
| 11 | `mp_left_iris_y` | MediaPipe | Normalised left iris centre Y |
| 12 | `mp_right_iris_x` | MediaPipe | Normalised right iris centre X |
| 13 | `mp_right_iris_y` | MediaPipe | Normalised right iris centre Y |
| 14 | `mp_left_pupil_x` | MediaPipe | Normalised left pupil X |
| 15 | `mp_left_pupil_y` | MediaPipe | Normalised left pupil Y |
| 16 | `mp_right_pupil_x` | MediaPipe | Normalised right pupil X |
| 17 | `mp_right_pupil_y` | MediaPipe | Normalised right pupil Y |
| 18 | `mp_left_ear` | MediaPipe | Left Eye Aspect Ratio |
| 19 | `mp_right_ear` | MediaPipe | Right Eye Aspect Ratio |
| 20 | `mp_left_eye_open` | MediaPipe | `true` / `false` |
| 21 | `mp_right_eye_open` | MediaPipe | `true` / `false` |
| 22 | `mp_left_iris_depth` | MediaPipe | Z-depth from Face Mesh |
| 23 | `mp_right_iris_depth` | MediaPipe | Z-depth from Face Mesh |
| 24 | `mp_ipd_normalized` | MediaPipe | Inter-pupillary distance / image width |
| 25 | `mp_confidence` | MediaPipe | Detection confidence |
| 26 | `mp_left_eye_crop` | MediaPipe | Base64 64×64 grayscale JPEG (left) |
| 27 | `mp_right_eye_crop` | MediaPipe | Base64 64×64 grayscale JPEG (right) |
| 28 | `mlkit_gaze_x` | ML Kit | Estimated gaze X [0, 1] |
| 29 | `mlkit_gaze_y` | ML Kit | Estimated gaze Y [0, 1] |
| 30 | `mlkit_head_yaw` | ML Kit | Head yaw in degrees |
| 31 | `mlkit_head_pitch` | ML Kit | Head pitch in degrees |
| 32 | `mlkit_head_roll` | ML Kit | Head roll in degrees |
| 33 | `mlkit_left_eye_open_prob` | ML Kit | Left eye-open probability |
| 34 | `mlkit_right_eye_open_prob` | ML Kit | Right eye-open probability |
| 35 | `mlkit_confidence` | ML Kit | Detection confidence |
| 36 | `azure_left_pupil_x` | Azure | Left pupil X [0, 1] |
| 37 | `azure_left_pupil_y` | Azure | Left pupil Y [0, 1] |
| 38 | `azure_right_pupil_x` | Azure | Right pupil X [0, 1] |
| 39 | `azure_right_pupil_y` | Azure | Right pupil Y [0, 1] |
| 40 | `azure_head_yaw` | Azure | Azure head yaw |
| 41 | `azure_head_pitch` | Azure | Azure head pitch |
| 42 | `azure_latency_ms` | Azure | API round-trip latency |
| 43 | `fused_gaze_x` | Fusion | Weighted average gaze X |
| 44 | `fused_gaze_y` | Fusion | Weighted average gaze Y |
| 45 | `overall_confidence` | Quality | Average confidence across sources |
| 46 | `blink` | Quality | `true` if either eye closed |
| 47 | `head_movement` | Quality | `'minimal'` or `'large'` |
| 48 | `device_model` | Device | `'Android'` or `'iOS'` |
| 49 | `screen_width` | Device | Screen width in pixels |
| 50 | `screen_height` | Device | Screen height in pixels |
| 51 | `camera_width` | Device | Camera frame width in pixels |
| 52 | `camera_height` | Device | Camera frame height in pixels |
| 53 | `blindness_type` | Profile | Participant's blindness category |
| 54 | `dominant_eye` | Profile | `'left'` / `'right'` / `'both'` |
| 55 | `vision_acuity` | Profile | 1–10 self-reported scale |
| 56 | `wears_glasses` | Profile | `true` / `false` |

---

## 11. UI Screens

### PermissionScreen (`lib/screens/permission_screen.dart`)
Shown only on first launch. Requests `CAMERA` permission via `permission_handler`. On grant, sets `SharedPreferences` key `permissions_granted = true` and navigates to `LanguageSelectionScreen`.

### LanguageSelectionScreen (`lib/screens/language_selection_screen.dart`)
Displays three language buttons (English 🇬🇧, Tamil 🇮🇳, Sinhala 🇱🇰). Passes selected `languageCode` to subsequent screens.

### UserAgreementScreen (`lib/screens/user_agreement_screen.dart`)
Shows the informed-consent text in the selected language. Participant must accept before proceeding. `consentGiven: true` is written to the `UserProfile` and stored in Firestore.

### UserFormScreen (`lib/screens/user_form_screen.dart`)
Collects participant demographics:
- Name
- Age
- Blindness type (dropdown)
- Dominant eye (radio buttons)
- Vision acuity (slider 1–10)
- Glasses use (checkbox)

On submit, creates a `UserProfile` and navigates to `CollectionGridScreen`.

### CollectionGridScreen (`lib/screens/collection_grid_screen.dart`)
The main data collection interface (~40 KB). Responsibilities:
- Initialises `CameraController` (front camera, medium resolution)
- Starts `FirestoreService.startSession()`
- Drives the three experiment phases (calibration → pulse → moving)
- Per frame: calls `DataCollectionService.collectSample()` and accumulates results
- Batches every 30 samples to `FirestoreService.addSamples()`
- Shows `PulsingTarget` widget at the current grid position
- Hides camera preview during collection to avoid distraction
- After phase 3: calls `FirestoreService.endSession()` and navigates to `SessionSummaryScreen`

### SessionSummaryScreen (`lib/screens/session_summary_screen.dart`)
Displays:
- Session ID
- Total samples collected
- Breakdown by phase
- "Start New Session" button

### DiagnosticScreen (`lib/screens/diagnostic_screen.dart`)
Developer/researcher tool showing live service status:
- Camera preview with `EyeTrackingOverlay`
- Per-source confidence values
- Frame rate counter
- Toggle buttons for individual services
- Useful for verifying camera alignment and service connectivity

### AdminLoginScreen (`lib/screens/admin_login_screen.dart`)
Firebase Authentication email/password login. On success navigates to `DataViewerScreen`.

### DataViewerScreen (`lib/screens/data_viewer_screen.dart`)
Admin dashboard:
- Real-time Firestore stream of all sessions
- Expandable session cards (participant info, sample count, timestamps)
- "Export CSV" button per session (calls `ResearchExportService`)

---

## 12. Widgets

| Widget | File | Purpose |
|---|---|---|
| `PulsingTarget` | `pulsing_target.dart` | Animated coloured circle at grid positions |
| `EyeTrackingOverlay` | `eye_tracking_overlay.dart` | Draws gaze dots during alignment: green (MediaPipe), blue (ML Kit), red (Azure), yellow (fused) |
| `CameraPreviewFrame` | `camera_preview_frame.dart` | Camera preview with aspect-ratio correction |
| `AlignmentGuide` | `alignment_guide.dart` | Overlay guide for positioning device |
| `AccessibleTextField` | `accessible_text_field.dart` | Text field with large tap target and TTS label |
| `PrimaryButton` | `primary_button.dart` | Styled primary action button |

---

## 13. Configuration & Setup

### Step 1 — Prerequisites
- Flutter SDK ≥ 3.0 installed
- Android Studio / Xcode
- Firebase project with Firestore and Firebase Auth enabled
- (Optional) Azure Cognitive Services account with Face API

### Step 2 — Firebase
1. Create a Firebase project at https://console.firebase.google.com
2. Register an Android app with package name `com.research.eyetracking`
3. Download `google-services.json` and place it in `android/app/`
4. Enable **Cloud Firestore** in the Firebase console
5. Enable **Firebase Authentication** → Email/Password provider
6. Create an admin user in Firebase Auth
7. Deploy Firestore security rules:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /sessions/{sessionId} {
      allow write: if true;              // Any device can write (participants)
      allow read:  if request.auth != null;  // Only authenticated admins can read
      match /samples/{document=**} {
        allow write: if true;
        allow read:  if request.auth != null;
      }
    }
  }
}
```

### Step 3 — Azure (optional)
Create a file named `.env` in the project root (already in `.gitignore`):
```env
AZURE_FACE_ENDPOINT=https://<your-resource>.cognitiveservices.azure.com/
AZURE_FACE_API_KEY=<your-api-key>
```
If this file is absent or the keys are blank, Azure is silently skipped.

### Step 4 — Android `build.gradle`
In `android/app/build.gradle`:
```groovy
android {
    defaultConfig {
        minSdkVersion 24      // Required by Google ML Kit
        targetSdkVersion 35
    }
}
```

### Step 5 — Android permissions (`AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### Step 6 — Run
```bash
flutter pub get
flutter run --release   # Use release mode for best ML performance
```

---

## 14. Admin Features

### Accessing the Admin Panel
From the app's `LanguageSelectionScreen`, navigate to `/admin-login` (or use a hidden gesture if implemented). Log in with the Firebase Auth credentials created during setup.

### Data Viewer
- Browse all sessions with participant metadata
- View sample counts per session
- Filter by date or participant name

### CSV Export
1. Open a session in the Data Viewer
2. Tap **Export CSV**
3. File is saved to device external storage
4. Transfer to a research computer for analysis

### Working with the CSV in Python
```python
import pandas as pd
import base64

df = pd.read_csv('eye_tracking_session_abc123.csv')

# Decode eye crops for CNN training
import io
from PIL import Image
import numpy as np

def decode_crop(b64_str):
    if pd.isna(b64_str):
        return None
    img_bytes = base64.b64decode(b64_str)
    return np.array(Image.open(io.BytesIO(img_bytes)))  # 64×64 grayscale

df['left_crop_array']  = df['mp_left_eye_crop'].apply(decode_crop)
df['right_crop_array'] = df['mp_right_eye_crop'].apply(decode_crop)

# Filter high-confidence, non-blink samples
clean = df[(df['overall_confidence'] > 0.7) & (df['blink'] == False)]

# Features for gaze regression
X = clean[['mp_left_iris_x','mp_left_iris_y',
           'mp_right_iris_x','mp_right_iris_y',
           'mlkit_head_yaw','mlkit_head_pitch']].values
y = clean[['target_x','target_y']].values
```

---

## 15. Accessibility & Multi-Language Support

### Text-to-Speech (`TtsService`)
`flutter_tts` reads instructions aloud at each phase transition and when a target position changes. Useful for participants with severe visual impairment who cannot see the screen clearly.

### Haptic Feedback (`HapticsService`)
`vibration` provides tactile confirmation:
- Short vibration when a target appears
- Double vibration at phase transitions
- Long vibration when session ends

### Multi-Language
Supported languages:

| Code | Language | Script |
|---|---|---|
| `en` | English | Latin |
| `ta` | Tamil | Tamil |
| `si` | Sinhala | Sinhala |

All user-facing strings are defined in `lib/core/constants/app_strings.dart` and selected based on the `languageCode` stored in `UserProfile`.

### High-Contrast UI
The dark theme (`AppColors.background`) and large, brightly coloured targets are designed to be visible at low vision acuity levels.

---

## 16. Special Features

### Eye Crop Extraction (CNN Training Data)
MediaPipe provides 8 eye-contour landmarks. For each eye the service:
1. Computes a bounding box around the 8 points
2. Adds 20% padding on all sides
3. Decodes the Y-plane (luminance) from the NV21 byte array
4. Crops the region and resizes to **64×64** pixels using linear interpolation
5. Encodes as a JPEG at 85% quality
6. Base64-encodes the result for Firestore storage

These crops are ready for direct input to a CNN gaze model.

### Blink Detection via Eye Aspect Ratio
```
EAR = ( ||p2 − p6|| + ||p3 − p5|| ) / ( 2 × ||p1 − p4|| )
```
where p1–p6 are the six eyelid-contour landmarks:
- p1, p4 — horizontal endpoints
- p2, p3, p5, p6 — vertical pairs

`EAR > 0.2` → eye open. Both eyes are checked independently; either being closed marks the sample as a blink (`quality['blink'] = true`).

### Multi-Source Data Fusion
Because no single source is perfect in all conditions:

| Condition | Best source |
|---|---|
| Precise iris position | MediaPipe |
| Head rotation / large movements | ML Kit |
| Independent cross-validation | Azure |

The `DataFusionService` computes a weighted average so that the combined estimate is more robust than any single source.

### Rate-Limited Azure Integration
The Azure Free tier allows 20 Face API calls per minute. The service tracks `_lastAzureCall` and enforces `CollectionConstants.azureSampleIntervalSec` (default: 3 seconds) between requests. All Azure failures are caught and logged without interrupting the session.

### Quality Filtering Pipeline
Samples go through a two-stage filter before storage:
1. **Service-level**: reject if MediaPipe or ML Kit returns `null`
2. **Confidence-level**: reject if `overallConfidence < 0.6`

This ensures that only high-quality, reliable samples reach Firestore, even if some frames fail detection.

---

## 17. Known Limitations & Troubleshooting

### Camera rotation
The camera `InputImageRotation` must match the physical device orientation. If gaze coordinates appear mirrored or rotated, verify the rotation value passed to `MediaPipeService` and `MLKitFaceService`. This is device-specific and may require manual testing.

### Android minSdkVersion
Google ML Kit requires `minSdkVersion 24`. Devices running Android 6 (API 23) or earlier are not supported.

### Azure rate limit
The free Azure tier allows 20 face-detection requests per minute. During a ~90-second session this means approximately 30 Azure samples are collected (every 3 seconds). For higher throughput, upgrade to a paid tier and adjust `CollectionConstants.azureSampleIntervalSec`.

### Sample count variation
The app targets 85–90 samples per session, but the actual count depends on:
- Camera frame rate (affected by device performance and lighting)
- Confidence filtering (low-light or occluded conditions increase rejections)
- Blink frequency of the participant

### `.env` not loading
If the `.env` file is not included in `pubspec.yaml`'s `assets` section or is malformed, `dotenv.load()` will warn and Azure will be silently disabled. Ensure:
```yaml
flutter:
  assets:
    - .env
```

### Firestore write failures
Batch writes may fail with a Firestore quota error during high-traffic testing. If this happens:
- Reduce `CollectionConstants.batchSize` below 30
- Check Firestore quota in the Firebase console

### ML Kit not detecting face
Ensure the participant's face is:
- Well-lit (front-facing light, not backlit)
- Within ~40–80 cm of the camera
- Roughly centred in the frame
- Not obscured by hair, glasses frames, or hands

The `DiagnosticScreen` shows live confidence scores and can be used to verify detection before starting a session.

---

*Generated for the Eye Tracking Collection research project. For questions about the data format, contact the project maintainer.*
