# Eye Tracking Collection App - Full Technical Documentation

## 1. Purpose and Scope

This app is a Flutter-based research data collection system for assistive eye-tracking. It captures eye and head signals while participants follow visual targets, then stores structured samples in Firebase Firestore and supports CSV export for analysis or model training.

This document explains:

- End-to-end app flow
- How data is collected
- Which calculations are performed
- Which landmarks are used
- How samples are stored and exported
- Active vs optional/legacy processing paths

## 2. High-Level Architecture

Main runtime stack:

- UI and workflow: Flutter screens
- Camera frames: `camera` plugin (front camera)
- Eye landmarks + iris: Google ML Kit Face Mesh (`google_mlkit_face_mesh_detection`)
- Face/head pose: Google ML Kit Face Detection (`google_mlkit_face_detection`)
- Cloud persistence: Firebase Firestore
- Optional validation path: Azure Face API service (implemented but not active in current main screen flow)

Core files:

- App routes/bootstrap: `lib/main.dart`
- Collection loop: `lib/screens/collection_grid_screen.dart`
- MediaPipe/Face Mesh processing: `lib/services/mediapipe_service.dart`
- ML Kit processing: `lib/services/mlkit_service.dart`
- Firestore persistence: `lib/services/firestore_service.dart`
- Export/stats: `lib/services/research_export_service.dart`
- Sample schema: `lib/models/eye_tracking_sample.dart`
- MediaPipe sample fields: `lib/models/mediapipe_data.dart`

## 3. User and Session Flow

### 3.1 Startup and Routing

Startup in `lib/main.dart`:

1. Initialize Firebase.
2. Load `.env` variables (best effort).
3. Lock orientation to portrait.
4. Read `permissions_granted` from SharedPreferences.
5. Route to either:

- `PermissionScreen` (`/permissions`) on first launch
- `LanguageSelectionScreen` (`/language`) after permissions are accepted

### 3.2 Onboarding Screens

1. `PermissionScreen`

- Requests camera permission.
- Requests storage/media permission depending on Android SDK.
- Performs Firestore health ping (`_health` test document).

2. `LanguageSelectionScreen`

- Selects language (`en`, `ta`, `si`).

3. `UserAgreementScreen`

- Displays consent text and accepts agreement.

4. `UserFormScreen`

- Captures participant profile fields:
  - Name
  - Age
  - Partial blind type (dropdown)
- Also sets defaults in profile:
  - `dominantEye: both`
  - `visionAcuity: 5`
  - `wearsGlasses: false`
  - `consentGiven: true`

5. `CollectionGridScreen`

- Starts camera stream and collection phases.
- Creates Firestore session document.

6. `SessionSummaryScreen`

- Shows computed session stats.
- Allows CSV export.

Admin route:

- `AdminLoginScreen` -> `DataViewerScreen` for session browsing and export.

## 4. Collection Pipeline (Active Runtime Path)

Active runtime collection is implemented directly inside `CollectionGridScreen`.

### 4.1 Camera Setup

- Front camera selected when available.
- Resolution preset: `low`.
- Format group: `yuv420`.
- Image stream starts via `startImageStream`.

### 4.2 Per-Frame Processing

For each camera frame:

1. Build image metadata/rotation from sensor orientation.
2. Run in parallel:

- `MediaPipeService.processImage(...)`
- `MLKitService.processImage(...)`

3. Cache latest outputs for:

- Real-time overlay rendering
- Timed sample recording during experiment phases

### 4.3 Experiment Phases

`ExperimentPhase` values:

- `guidelines`
- `calibration`
- `pulse`
- `moving`
- `done`

`ExperimentMode` values used in samples:

- `calibration`
- `pulse`
- `moving`

Region set (6 target zones):

- red (top-left)
- yellow (top-center)
- green (top-right)
- blue (bottom-left)
- magenta (bottom-center)
- cyan (bottom-right)

Target coordinate generation:

- Alignment values in `[-1, 1]` are mapped to normalized `[0, 1]`.
- 8% inset padding is applied so targets are not exactly on screen edges.

### 4.4 Sampling Timing

During each dwell/visible period, samples are recorded every 200 ms using latest processed frame data.

Phase timing in `CollectionGridScreen`:

- Calibration:
  - 2 seconds per region
  - Sampling every 200 ms
- Pulse:
  - 1.5 seconds visible + 0.5 second gap
  - Repeated for each region, for 3 rounds
  - Sampling during visible 1.5-second window
- Moving:
  - 3 speed tiers: `slow`, `medium`, `fast`
  - Tick durations: 1200 ms, 800 ms, 500 ms
  - 15 seconds per speed tier
  - Region sequence follows one random line pattern each tier

Note: `lib/core/constants/collection_constants.dart` contains timing constants, but current `CollectionGridScreen` uses in-file values for moving phase durations/timings.

### 4.5 Sample Buffering and Flush

- Samples are buffered in `_pendingSamples`.
- Flush threshold uses `CollectionConstants.batchSize` (30).
- Each flush writes one chunk doc under:
  - `sessions/{sessionId}/samples/chunk_{chunkIndex}`
- Session doc updates `totalSamples` and `lastUpdated`.

## 5. Landmark Definitions and Indices

All major landmark index logic is in `lib/services/mediapipe_service.dart`.

### 5.1 Iris Landmark Indices (MediaPipe 478 model)

- Left iris: indices `468, 469, 470, 471, 472`
- Right iris: indices `473, 474, 475, 476, 477`

The app computes iris center as the average of those 5 points.

### 5.2 Eye Corner Indices

Used for geometric context and export:

- Left eye inner corner: `133`
- Left eye outer corner: `33`
- Right eye inner corner: `362`
- Right eye outer corner: `263`

### 5.3 EAR (Eye Aspect Ratio) Landmark Sets

Left EAR points (`[p1, p2, p3, p4, p5, p6]`):

- `[33, 160, 158, 133, 153, 144]`

Right EAR points (`[p1, p2, p3, p4, p5, p6]`):

- `[362, 385, 387, 263, 380, 373]`

### 5.4 Eye Crop Landmark Sets

Bounding box landmarks used before 20% padding and 64x64 resize:

- Left eye crop landmarks: `[33, 133, 159, 145, 160, 144, 158, 153]`
- Right eye crop landmarks: `[362, 263, 386, 374, 385, 380, 387, 373]`

### 5.5 Fallback Landmark Candidates

If iris points are unavailable:

- Left fallback: `[33, 133, 159, 145, 158]`
- Right fallback: `[362, 263, 386, 374, 387]`

## 6. Calculations Performed

## 6.1 Image Conversion (Android ML Kit input)

Both MediaPipe and ML Kit services convert camera YUV frames to NV21 when needed:

- Single-plane frame: use directly
- Multi-plane YUV_420_888: rebuild NV21 by:
  - Copy Y plane row by row
  - Interleave V then U for chroma

## 6.2 Iris Center and Normalization

From iris landmarks:

- `center_x = mean(point_i.x)`
- `center_y = mean(point_i.y)`

Normalized output:

- `norm_x = center_x / imageWidth`
- `norm_y = center_y / imageHeight`

## 6.3 Eye Aspect Ratio (EAR)

Formula used:

- `EAR = (|p2 - p6| + |p3 - p5|) / (2 * |p1 - p4|)`

Per-eye open/closed status:

- `eyeOpen = EAR > 0.2`

## 6.4 Interpupillary Distance (IPD)

Pixel distance:

- `ipdPx = sqrt((Lx - Rx)^2 + (Ly - Ry)^2)`

Normalized by image width:

- `ipdNormalized = ipdPx / imageWidth`

## 6.5 Iris Depth

Depth values are read from iris mesh points:

- Left depth from index `472` (`_leftIrisStart + 4`)
- Right depth from index `477` (`_rightIrisStart + 4`)

## 6.6 Face Bounding Box

From all mesh points:

- `minX, minY, maxX, maxY` across face mesh
- Stored normalized by image width/height

## 6.7 ML Kit Gaze Estimate From Head Pose

`MLKitService` computes gaze estimate using eye center plus Euler offsets.

Eye center (normalized):

- midpoint of ML Kit left/right eye landmarks divided by image size

Offset model:

- `xOffset = yaw * 0.003`
- `yOffset = pitch * 0.003`
- `gaze = clamp(eyeCenter + offset, 0..1)`

## 6.8 Confidence and Quality in Active Collection Screen

In `CollectionGridScreen._recordSample(...)`:

- `overallConfidence = average(confidence of available sources)`
- Currently available sources in main loop: MediaPipe + ML Kit
- Sample skipped only when both sources missing

Derived quality flags:

- `blink = !leftEyeOpen || !rightEyeOpen` (if MediaPipe exists)
- `headMovement = large` when `|yaw| > 15` or `|pitch| > 15`, otherwise `minimal`

## 6.9 Additional Fusion Service (Implemented, Not Used in Main Loop)

`lib/services/data_fusion_service.dart` includes weighted fusion logic:

- MediaPipe: 50%
- ML Kit: 30%
- Azure: 20%

It computes a weighted fused gaze and combined confidence floor of 0.1. This service is present but not currently called by `CollectionGridScreen`.

## 7. What Data Is Collected Per Sample

Sample schema in `EyeTrackingSample.toFirestore()`:

- `sampleId`
- `timestamp`
- `target`:
  - `pixelX`, `pixelY`
  - `normalizedX`, `normalizedY`
- `mode`, `colorLabel`, optional `speedLabel`
- `mediapipe` (if available)
- `mlkit` (if available)
- `azure` (currently null in main collection flow)
- `deviceInfo`
- `participantContext`
- `quality`

### 7.1 MediaPipe Sample Fields

From `MediaPipeData.toMap()`:

- Detection and confidence
- Left/right iris points (pixel coordinates)
- Left/right pupil center (pixel)
- Eye-open booleans
- Face landmark count
- CNN-oriented fields:
  - `leftEyeCrop` / `rightEyeCrop` (base64 JPEG)
  - `leftEAR`, `rightEAR`
  - `leftIrisDepth`, `rightIrisDepth`
  - `ipdNormalized`
  - Eye corner coordinates
  - Face box

### 7.2 ML Kit Sample Fields

From `MLKitData.toMap()`:

- Detection and confidence
- `gazeEstimate` (pixel in this model map)
- `headPose` (`yaw`, `pitch`, `roll`)
- `faceBounds`
- Eye-open probabilities

### 7.3 Device Info Fields

Collected in the sample:

- Screen width/height in pixels
- Screen density
- Camera resolution width/height
- Timestamp (ms)

### 7.4 Participant Context Fields

From profile/defaults:

- `blindnessType`
- `dominantEye`
- `visionAcuity`
- `wearsGlasses`
- `age`

## 8. Firestore Data Model

Top-level session document (`sessions/{sessionId}`):

- `userId`
- `participantProfile` (full profile map)
- `screenSize` (`width`, `height`)
- `consentGiven`
- `startTime`
- `status` (`active` then `completed` when ended)
- `totalSamples`
- `lastUpdated`

Sample chunk document (`sessions/{sessionId}/samples/chunk_{i}`):

- `chunkIndex`
- `sampleCount`
- `timestamp`
- `samples` (array of full sample maps)

## 9. Export and Session Statistics

`ResearchExportService` provides research-ready CSV export with a fixed column order, including:

- Participant metadata
- Phase/target labels
- Iris center, pupil, EAR, IPD, eye-corner, face-box features
- Head pose and eye-open probabilities
- Confidence and screen context
- Optional eye-crop base64 strings

`getSessionStats(sessionId)` computes:

- `total`
- `withCrops`
- `avgConfidence`
- `avgEAR`
- `blinkCount`
- `phaseCounts`

`SessionSummaryScreen` uses these stats for post-session feedback.

## 10. Diagnostics and Data Quality Gate

`DiagnosticScreen` runs checks for:

- Camera
- MediaPipe face detection
- Eye crop extraction
- Head pose
- Firestore connection
- Storage access
- Lighting
- Face distance (using IPD in pixels)

Mandatory pass logic:

- Camera must pass
- MediaPipe must pass or warning
- Firestore may pass or warning

`Proceed` is enabled only when mandatory checks satisfy this rule.

## 11. Active vs Optional/Legacy Paths

Active in current main collection flow:

- `CollectionGridScreen` + `MediaPipeService` + `MLKitService` + `FirestoreService`

Implemented but not active in the same runtime path:

- `DataFusionService` (weighted fused gaze)
- `DataCollectionService` (alternative orchestration path)
- Azure integration in main sample loop (currently `azureData: null` there)

Additional note:

- There are two Azure service files (`azure_service.dart`, `azure_face_service.dart`) and both implement Face API parsing patterns. The current direct collection screen does not invoke either.

## 12. Privacy and Data Characteristics

According to in-app guidelines in collection flow:

- The app states that only eye/head coordinate-related data is collected.
- No raw video is persisted by the collection screen.
- Per-sample data consists of numeric features and optional small eye crops (64x64 grayscale JPEG as base64).

## 13. Practical Summary of What Is Calculated

For each collected sample (when sources available), the app computes and stores:

- Target coordinates (normalized + pixel)
- Iris landmarks and iris center
- Pupil center (pixel)
- EAR for each eye
- Eye open/closed flags
- Iris depth (left/right)
- Interpupillary distance (normalized)
- Eye corners and face box
- Head pose yaw/pitch/roll
- Gaze estimate from head pose
- Overall confidence and quality flags (blink, head movement)
- Device and participant context

This makes the dataset suitable for calibration analysis, gaze modeling, blink/head-movement quality filtering, and downstream ML/CNN experiments.
