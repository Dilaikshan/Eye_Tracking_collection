# Firebase to Colab Training Guide

Date: 2026-04-05
Project: Eye Tracking Collection

## 1. End-to-End Data Collection Flow

This app collects gaze-training data in this order:

1. Permission flow and language/consent screens.
2. Participant profile capture (age, blindness type, etc.).
3. Session creation in Firestore (`sessions` collection).
4. Real-time data capture while user follows targets:
   - calibration mode
   - pulse mode
   - moving mode
5. For each valid frame/sample:
   - MediaPipe features are extracted.
   - ML Kit features are extracted.
   - Eye crop images are generated (64x64 grayscale JPEG).
   - Sample is appended to an in-memory batch.
6. Batch flush to Firestore every 30 samples (`CollectionConstants.batchSize`).
7. Session is marked completed at end.

Important behavior:

- A sample is skipped if no eye source is available (both MediaPipe and ML Kit missing).
- Azure fields are currently set as not used in the current collection flow.

## 2. Firestore Data Structure

### 2.1 Root collection

Collection: `sessions`

Each session document contains:

- `userId` (string)
- `participantProfile` (map)
- `screenSize` (map: width, height)
- `consentGiven` (bool)
- `startTime` (server timestamp)
- `status` (string: active/completed)
- `totalSamples` (number)
- `lastUpdated` (server timestamp, added during chunk writes)
- `endTime` (server timestamp, when completed)

### 2.2 Session sample chunks

Subcollection path:

- `sessions/{sessionId}/samples/{chunkId}`

Chunk document format:

- `chunkIndex` (int)
- `sampleCount` (int)
- `timestamp` (server timestamp)
- `samples` (array of sample maps)

Chunk ID pattern:

- `chunk_0`, `chunk_1`, `chunk_2`, ...

### 2.3 Sample object format (inside `samples` array)

Top-level fields written per sample:

- `sampleId` (UUID string)
- `timestamp` (milliseconds since epoch)
- `target` (map)
  - `pixelX`, `pixelY`
  - `normalizedX`, `normalizedY`
- `mode` (calibration/pulse/moving)
- `colorLabel` (red, yellow, green, blue, magenta, cyan)
- `speedLabel` (optional, mainly for moving mode)
- `mediapipe` (optional map)
- `mlkit` (optional map)
- `azure` (optional map, currently not populated)
- `leftEyeCropUrl` (optional string; Firebase Storage download URL)
- `rightEyeCropUrl` (optional string; Firebase Storage download URL)
- `deviceInfo` (map)
- `participantContext` (map)
- `quality` (map)

## 3. Exact Feature Maps

### 3.1 `mediapipe` map

Fields currently saved:

- `detected` (bool)
- `confidence` (float)
- `leftIris` (list of points)
  - each point: `pixelX`, `pixelY`
- `rightIris` (list of points)
  - each point: `pixelX`, `pixelY`
- `leftPupilCenter`: `pixelX`, `pixelY`
- `rightPupilCenter`: `pixelX`, `pixelY`
- `leftEyeOpen` (bool)
- `rightEyeOpen` (bool)
- `faceLandmarkCount` (int)
- `leftEyeCrop` (optional base64 JPEG string)
- `rightEyeCrop` (optional base64 JPEG string)
- `leftEAR`, `rightEAR` (float)
- `leftIrisDepth`, `rightIrisDepth` (float)
- `ipdNormalized` (float)
- `eyeCorners` map
  - `leftInner`: x, y
  - `leftOuter`: x, y
  - `rightInner`: x, y
  - `rightOuter`: x, y
- `faceBox` (optional): left, top, right, bottom

### 3.2 `mlkit` map

Fields currently saved:

- `detected` (bool)
- `confidence` (float)
- `gazeEstimate` (optional): `pixelX`, `pixelY`
- `headPose`: yaw, pitch, roll
- `faceBounds`: left, top, width, height
- `leftEyeOpenProb`, `rightEyeOpenProb` (float)

### 3.3 `deviceInfo` map

Fields:

- `screenWidthPixels`
- `screenHeightPixels`
- `screenDensity`
- `cameraResolutionWidth`
- `cameraResolutionHeight`
- `timestamp`

### 3.4 `participantContext` map

Fields:

- `blindnessType`
- `dominantEye`
- `visionAcuity`
- `wearsGlasses`
- `age`

### 3.5 `quality` map

Fields:

- `overallConfidence`
- `mediapipeDetected`
- `mlkitDetected`
- `azureDetected`
- `blink`
- `headMovement` (minimal/large)
- `sourceCount`

## 4. Firebase Storage Image Format

Eye crops are also uploaded to Firebase Storage at:

- `eye_crops/{sessionId}/{sampleId}_left.jpg`
- `eye_crops/{sessionId}/{sampleId}_right.jpg`

Image properties:

- Resolution: 64 x 64
- Color: grayscale (stored as JPEG)
- JPEG quality: 85

So each sample may contain eye images in two forms:

1. Firestore base64 strings (`mediapipe.leftEyeCrop`, `mediapipe.rightEyeCrop`)
2. Firebase Storage URLs (`leftEyeCropUrl`, `rightEyeCropUrl`)

## 5. Coordinate and Unit Notes (Important for Training)

1. Target labels:

- `target.normalizedX`, `target.normalizedY` are in [0, 1].
- `target.pixelX`, `target.pixelY` are screen-space pixels.

2. MediaPipe iris and pupil in saved `mediapipe` map are pixel-space in camera image coordinates.

3. `ipdNormalized` is normalized by image width.

4. Head pose angles (`yaw`, `pitch`, `roll`) are in degrees.

## 6. Google Colab Setup for Firebase

## 6.1 Install Python packages

```python
!pip -q install firebase-admin pandas numpy pillow requests tensorflow scikit-learn tqdm
```

## 6.2 Upload Firebase service account JSON

In Firebase Console:

- Project Settings -> Service accounts -> Generate new private key

Then in Colab:

```python
from google.colab import files
uploaded = files.upload()  # upload your service-account JSON
```

## 6.3 Connect Firestore and Storage

```python
import os
import firebase_admin
from firebase_admin import credentials, firestore, storage

SERVICE_ACCOUNT_PATH = "/content/your-service-account.json"
BUCKET_NAME = "your-project-id.appspot.com"  # replace

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred, {"storageBucket": BUCKET_NAME})

db = firestore.client()
bucket = storage.bucket()
print("Firebase connected")
```

## 7. Load All Samples from Firestore

```python
import pandas as pd


def safe_get(d, *keys, default=None):
    cur = d
    for k in keys:
        if not isinstance(cur, dict) or k not in cur:
            return default
        cur = cur[k]
    return cur


def iter_all_samples(db_client):
    sessions = db_client.collection("sessions").stream()
    for sdoc in sessions:
        session_id = sdoc.id
        sdata = sdoc.to_dict() or {}
        participant_profile = sdata.get("participantProfile", {})

        chunks = (
            db_client.collection("sessions")
            .document(session_id)
            .collection("samples")
            .stream()
        )
        for cdoc in chunks:
            cdata = cdoc.to_dict() or {}
            for sample in cdata.get("samples", []):
                yield session_id, participant_profile, sample


rows = []
for session_id, profile, sample in iter_all_samples(db):
    mp = sample.get("mediapipe", {}) or {}
    ml = sample.get("mlkit", {}) or {}
    q = sample.get("quality", {}) or {}
    t = sample.get("target", {}) or {}

    rows.append({
        "session_id": session_id,
        "sample_id": sample.get("sampleId"),
        "timestamp": sample.get("timestamp"),
        "mode": sample.get("mode"),
        "color_label": sample.get("colorLabel"),
        "speed_label": sample.get("speedLabel"),
        "target_x": t.get("normalizedX"),
        "target_y": t.get("normalizedY"),
        "left_ear": mp.get("leftEAR"),
        "right_ear": mp.get("rightEAR"),
        "ipd_norm": mp.get("ipdNormalized"),
        "head_yaw": safe_get(ml, "headPose", "yaw"),
        "head_pitch": safe_get(ml, "headPose", "pitch"),
        "head_roll": safe_get(ml, "headPose", "roll"),
        "left_eye_open_prob": ml.get("leftEyeOpenProb"),
        "right_eye_open_prob": ml.get("rightEyeOpenProb"),
        "overall_conf": q.get("overallConfidence"),
        "left_crop_b64": mp.get("leftEyeCrop"),
        "right_crop_b64": mp.get("rightEyeCrop"),
        "left_crop_url": sample.get("leftEyeCropUrl"),
        "right_crop_url": sample.get("rightEyeCropUrl"),
        "blindness_type": sample.get("participantContext", {}).get("blindnessType", profile.get("blindnessType")),
    })


df = pd.DataFrame(rows)
print("Total samples:", len(df))
df.head()
```

## 8. Build Training Dataset in Colab

This baseline predicts normalized gaze target (`target_x`, `target_y`) from one eye image plus numeric features.

```python
import base64
import io
import numpy as np
import requests
from PIL import Image


IMG_SIZE = 64


def decode_eye_image(row):
    # Prefer base64 from Firestore
    if isinstance(row.left_crop_b64, str) and len(row.left_crop_b64) > 20:
        try:
            raw = base64.b64decode(row.left_crop_b64)
            im = Image.open(io.BytesIO(raw)).convert("L").resize((IMG_SIZE, IMG_SIZE))
            return np.array(im, dtype=np.float32) / 255.0
        except Exception:
            pass

    # Fallback to Storage URL
    if isinstance(row.left_crop_url, str) and row.left_crop_url.startswith("http"):
        try:
            r = requests.get(row.left_crop_url, timeout=20)
            r.raise_for_status()
            im = Image.open(io.BytesIO(r.content)).convert("L").resize((IMG_SIZE, IMG_SIZE))
            return np.array(im, dtype=np.float32) / 255.0
        except Exception:
            pass

    return None


work = df.dropna(subset=["target_x", "target_y"]).copy()
work = work[(work["target_x"] >= 0) & (work["target_x"] <= 1) &
            (work["target_y"] >= 0) & (work["target_y"] <= 1)]

images = []
num_features = []
labels = []

for row in work.itertuples(index=False):
    img_arr = decode_eye_image(row)
    if img_arr is None:
        continue

    images.append(img_arr[..., None])
    num_features.append([
        row.left_ear if row.left_ear is not None else 0.0,
        row.right_ear if row.right_ear is not None else 0.0,
        row.ipd_norm if row.ipd_norm is not None else 0.0,
        row.head_yaw if row.head_yaw is not None else 0.0,
        row.head_pitch if row.head_pitch is not None else 0.0,
        row.head_roll if row.head_roll is not None else 0.0,
        row.left_eye_open_prob if row.left_eye_open_prob is not None else 0.0,
        row.right_eye_open_prob if row.right_eye_open_prob is not None else 0.0,
        row.overall_conf if row.overall_conf is not None else 0.0,
    ])
    labels.append([row.target_x, row.target_y])

X_img = np.array(images, dtype=np.float32)
X_num = np.array(num_features, dtype=np.float32)
y = np.array(labels, dtype=np.float32)

print("Trainable samples:", len(X_img), X_img.shape, X_num.shape, y.shape)
```

## 9. Baseline CNN Regression Model

```python
import tensorflow as tf
from sklearn.model_selection import train_test_split

X_img_tr, X_img_va, X_num_tr, X_num_va, y_tr, y_va = train_test_split(
    X_img, X_num, y, test_size=0.2, random_state=42
)

img_in = tf.keras.Input(shape=(64, 64, 1), name="eye_image")
x = tf.keras.layers.Conv2D(16, 3, activation="relu")(img_in)
x = tf.keras.layers.MaxPool2D()(x)
x = tf.keras.layers.Conv2D(32, 3, activation="relu")(x)
x = tf.keras.layers.MaxPool2D()(x)
x = tf.keras.layers.Conv2D(64, 3, activation="relu")(x)
x = tf.keras.layers.GlobalAveragePooling2D()(x)

num_in = tf.keras.Input(shape=(9,), name="numeric_features")
n = tf.keras.layers.Dense(32, activation="relu")(num_in)

z = tf.keras.layers.Concatenate()([x, n])
z = tf.keras.layers.Dense(64, activation="relu")(z)
out = tf.keras.layers.Dense(2, activation="sigmoid", name="gaze_xy")(z)

model = tf.keras.Model(inputs=[img_in, num_in], outputs=out)
model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-3),
    loss="mse",
    metrics=[tf.keras.metrics.MeanAbsoluteError(name="mae")],
)

history = model.fit(
    {"eye_image": X_img_tr, "numeric_features": X_num_tr},
    y_tr,
    validation_data=({"eye_image": X_img_va, "numeric_features": X_num_va}, y_va),
    epochs=20,
    batch_size=64,
)
```

## 10. Recommended Thesis Reporting Points

When writing your thesis chapter, include:

1. How labels are generated:

- Screen target positions are controlled by experiment phase and stored as normalized and pixel coordinates.

2. How eye images are generated:

- 64x64 grayscale eye patches from Y plane, JPEG quality 85.
- Stored both as base64 in Firestore and as JPEG files in Firebase Storage.

3. Feature modalities:

- Image modality: eye crops.
- Numeric modality: EAR, IPD, head pose, eye openness, confidence.

4. Data quality and filtering:

- Samples without any valid detection source are skipped.
- Quality flags are stored per sample.

5. Train/validation split and metrics:

- Use normalized output target (x, y).
- Report MAE and MSE on validation set.

## 11. Quick Validation Checklist

Before training in Colab:

1. Confirm at least one completed session in `sessions`.
2. Confirm chunk docs exist in `sessions/{sessionId}/samples`.
3. Confirm sample arrays are non-empty.
4. Confirm at least one of these is present:
   - `mediapipe.leftEyeCrop` (base64)
   - `leftEyeCropUrl` (Firebase Storage URL)
5. Confirm labels exist:
   - `target.normalizedX`
   - `target.normalizedY`

## 12. Security Notes

1. Never commit service account JSON to git.
2. Use read-only credentials for analysis notebooks if possible.
3. Share only anonymized exports in publications.
