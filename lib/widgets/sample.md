You are an expert deep learning engineer helping me build a gaze estimation
model for a research project titled:

"Assistive Eye-Tracking System for Partially Blind Users Using Mobile Devices"
Project code: SEU/IS/19/ICT/047 — South Eastern University of Sri Lanka

════════════════════════════════════════════════════════════════
SECTION 1: PROJECT CONTEXT
════════════════════════════════════════════════════════════════

This is a Flutter Android app that uses the front camera to collect
eye-tracking data from partially blind participants (Myopia, Cataract).

The app runs three experimental phases:

1. CALIBRATION – User stares at 6 colored static targets
   (red, yellow, green, blue, magenta, cyan) at fixed screen positions.
2. PULSE – Same 6 targets flash on/off (3 rounds), 1.5s visible / 0.5s blank.
3. MOVING – A dot moves across the screen at slow/medium/fast speeds for 15s each.

For every valid camera frame, the app extracts and saves:

- MediaPipe FaceMesh (478-point model) → iris landmarks, EAR, IPD, depth, eye corners
- Google ML Kit Face Detection → head pose (yaw, pitch, roll), eye open probability
- 64×64 grayscale JPEG eye crops (stored as base64 in Firestore AND
  as files in Firebase Storage)
- Screen target position (normalized [0,1] and pixel coordinates)

The GOAL of the ML model is:
INPUT → eye image crop + numeric features (EAR, IPD, head pose, etc.)
OUTPUT → normalized gaze target position (x, y) in [0,1] screen space

This is a REGRESSION problem, not classification.

════════════════════════════════════════════════════════════════
SECTION 2: EXACT FIRESTORE DATA STRUCTURE
════════════════════════════════════════════════════════════════

Firestore root collection: `sessions`
Each session document has fields: - userId (string) - participantProfile: { personId, age, blindnessType, dominantEye,
visionAcuity, wearsGlasses, languageCode,
consentGiven, createdAt } - screenSize: { width, height } - startTime, endTime (Timestamps) - status: "active" | "completed" - totalSamples (int)

Subcollection: sessions/{sessionId}/samples/
Each chunk doc (chunk_0, chunk_1, ...): - chunkIndex (int) - sampleCount (int) - samples: [ array of sample maps ]

Each SAMPLE map has these exact fields:
sampleId → UUID string
timestamp → milliseconds since epoch
mode → "calibration" | "pulse" | "moving"
colorLabel → "red" | "yellow" | "green" | "blue" | "magenta" | "cyan"
speedLabel → "slow" | "medium" | "fast" (only for moving mode)

target:
pixelX, pixelY → screen pixel coordinates
normalizedX, normalizedY → [0,1] normalized target (USE THESE AS LABELS)

mediapipe:
detected (bool), confidence (float ~0.9)
leftIris: [ {pixelX, pixelY} × 5 ] → iris contour landmark pixels
rightIris: [ {pixelX, pixelY} × 5 ]
leftPupilCenter: { pixelX, pixelY } → camera image pixel coords
rightPupilCenter: { pixelX, pixelY }
leftEyeOpen, rightEyeOpen (bool)
leftEyeCrop: base64-encoded 64×64 grayscale JPEG string
rightEyeCrop: base64-encoded 64×64 grayscale JPEG string
leftEAR, rightEAR → Eye Aspect Ratio float (>0.18 = open)
leftIrisDepth, rightIrisDepth → Z-depth from FaceMesh (float)
ipdNormalized → interpupillary distance / image width (float)
eyeCorners:
leftInner: { x, y } → normalized [0,1]
leftOuter: { x, y }
rightInner: { x, y }
rightOuter: { x, y }
faceBox: { left, top, right, bottom } → normalized [0,1]

mlkit:
detected (bool), confidence (float)
gazeEstimate: { pixelX, pixelY } (optional)
headPose: { yaw, pitch, roll } → degrees
faceBounds: { left, top, width, height }
leftEyeOpenProb, rightEyeOpenProb → [0,1] float

deviceInfo:
screenWidthPixels, screenHeightPixels
screenDensity, cameraResolutionWidth, cameraResolutionHeight
timestamp

participantContext:
blindnessType, dominantEye, visionAcuity, wearsGlasses, age

quality:
overallConfidence, mediapipeDetected, mlkitDetected
blink (bool), headMovement ("minimal" | "large"), sourceCount

leftEyeCropUrl: Firebase Storage download URL (string, optional)
rightEyeCropUrl: Firebase Storage download URL (string, optional)

════════════════════════════════════════════════════════════════
SECTION 3: COORDINATE & UNIT NOTES
════════════════════════════════════════════════════════════════

- target.normalizedX / normalizedY → USE THESE as training labels (range [0,1])
- mediapipe iris/pupil pixel coords → camera image space (NOT screen space)
  Convert to normalized: x_norm = pixelX / cameraResolutionWidth
- ipdNormalized → already normalized by image width
- head pose yaw/pitch/roll → degrees (range roughly -90 to +90)
- EAR → 0.0 to ~0.4 (closed eye ~0.15, open eye ~0.25-0.35)
- All eye crop images are 64×64 grayscale JPEG at quality=85

════════════════════════════════════════════════════════════════
SECTION 4: MODEL ARCHITECTURE REQUIREMENTS
════════════════════════════════════════════════════════════════

Build a DUAL-INPUT HYBRID model:

INPUT BRANCH 1 — CNN Image Branch:
Input: left eye crop 64×64×1 (grayscale, float32 normalized to [0,1])
Architecture:
Conv2D(32, 3×3, relu) → BatchNorm → MaxPool(2×2)
Conv2D(64, 3×3, relu) → BatchNorm → MaxPool(2×2)
Conv2D(128, 3×3, relu) → BatchNorm → GlobalAveragePooling2D
Dense(128, relu) → Dropout(0.3)

INPUT BRANCH 2 — Numeric Features Branch:
Features (14 total):
left_ear, right_ear, → EAR values
ipd_normalized, → head distance proxy
head_yaw, head_pitch, head_roll, → head orientation
left_eye_open_prob, right_eye_open_prob, → ML Kit
left_iris_x_norm, left_iris_y_norm, → normalized iris center
right_iris_x_norm, right_iris_y_norm, → normalized iris center
left_iris_depth, right_iris_depth → Z depth
Architecture:
Dense(64, relu) → BatchNorm → Dense(64, relu) → Dropout(0.2)

FUSION:
Concatenate([cnn_branch, numeric_branch])
Dense(128, relu) → Dropout(0.3)
Dense(64, relu)
Dense(2, sigmoid) → output: [gaze_x, gaze_y] in [0,1]

Loss: MSE (Mean Squared Error)
Metrics: MAE (Mean Absolute Error), also compute pixel error = MAE × screen_width
Optimizer: Adam(lr=1e-3) with ReduceLROnPlateau(patience=5, factor=0.5)

ALSO build an RNN/LSTM variant to capture temporal gaze sequence:
For sequences of N consecutive frames from the same session/mode,
use LSTM(64) → Dense(2, sigmoid)
This captures smooth gaze movement especially in the "moving" phase.
Compare MSE of CNN vs LSTM vs Hybrid (CNN features fed into LSTM).

════════════════════════════════════════════════════════════════
SECTION 5: DATA LOADING FROM FIREBASE
════════════════════════════════════════════════════════════════

# --- STEP 1: Install dependencies ---

!pip -q install firebase-admin pandas numpy pillow requests tensorflow \
 scikit-learn tqdm matplotlib seaborn

# --- STEP 2: Upload service account ---

from google.colab import files
uploaded = files.upload() # upload your Firebase service account JSON

import firebase_admin
from firebase_admin import credentials, firestore, storage

SERVICE_ACCOUNT = list(uploaded.keys())[0]
BUCKET_NAME = "eye-tracking-data-collection.appspot.com" # ← REPLACE THIS

if not firebase_admin.\_apps:
cred = credentials.Certificate(SERVICE_ACCOUNT)
firebase_admin.initialize_app(cred, {"storageBucket": BUCKET_NAME})

db = firestore.client()
bucket = storage.bucket()
print("✅ Firebase connected")

# --- STEP 3: Load all samples ---

import base64, io, requests
import numpy as np
import pandas as pd
from PIL import Image
from tqdm import tqdm

IMG_SIZE = 64

def decode_b64_image(b64_str):
"""Decode base64 JPEG to numpy float32 array [0,1]."""
try:
raw = base64.b64decode(b64_str)
img = Image.open(io.BytesIO(raw)).convert("L").resize((IMG_SIZE, IMG_SIZE))
return np.array(img, dtype=np.float32) / 255.0
except:
return None

def fetch_url_image(url):
"""Download image from Firebase Storage URL."""
try:
r = requests.get(url, timeout=20)
r.raise_for_status()
img = Image.open(io.BytesIO(r.content)).convert("L").resize((IMG_SIZE, IMG_SIZE))
return np.array(img, dtype=np.float32) / 255.0
except:
return None

def safe(d, \*keys, default=0.0):
for k in keys:
if not isinstance(d, dict): return default
d = d.get(k, default)
return d if d is not None else default

all_rows = []

sessions = db.collection("sessions").stream()
for sdoc in tqdm(list(sessions), desc="Sessions"):
sid = sdoc.id
sdata = sdoc.to_dict() or {}
profile = sdata.get("participantProfile", {})
screen_w = safe(sdata, "screenSize", "width", default=1080)
screen_h = safe(sdata, "screenSize", "height", default=1920)

    chunks = db.collection("sessions").document(sid).collection("samples").stream()
    for cdoc in chunks:
        for s in (cdoc.to_dict() or {}).get("samples", []):
            mp  = s.get("mediapipe", {}) or {}
            ml  = s.get("mlkit", {}) or {}
            q   = s.get("quality", {}) or {}
            t   = s.get("target", {}) or {}
            ctx = s.get("participantContext", {}) or {}
            dev = s.get("deviceInfo", {}) or {}
            corners = mp.get("eyeCorners", {}) or {}
            cam_w = dev.get("cameraResolutionWidth", 320) or 320
            cam_h = dev.get("cameraResolutionHeight", 240) or 240

            # Normalize iris pixel coords to [0,1]
            lp = mp.get("leftPupilCenter", {}) or {}
            rp = mp.get("rightPupilCenter", {}) or {}
            l_iris_x = safe(lp, "pixelX") / cam_w
            l_iris_y = safe(lp, "pixelY") / cam_h
            r_iris_x = safe(rp, "pixelX") / cam_w
            r_iris_y = safe(rp, "pixelY") / cam_h

            row = {
                "session_id":   sid,
                "sample_id":    s.get("sampleId", ""),
                "timestamp":    s.get("timestamp", 0),
                "mode":         s.get("mode", ""),
                "color_label":  s.get("colorLabel", ""),
                "speed_label":  s.get("speedLabel", ""),
                "blindness_type": ctx.get("blindnessType", profile.get("blindnessType", "")),
                "age":          ctx.get("age", profile.get("age", 0)),
                # LABELS
                "target_x":     safe(t, "normalizedX"),
                "target_y":     safe(t, "normalizedY"),
                "target_px_x":  safe(t, "pixelX"),
                "target_px_y":  safe(t, "pixelY"),
                # Screen context
                "screen_w":     screen_w,
                "screen_h":     screen_h,
                # Numeric features (14)
                "left_ear":     safe(mp, "leftEAR"),
                "right_ear":    safe(mp, "rightEAR"),
                "ipd_norm":     safe(mp, "ipdNormalized"),
                "head_yaw":     safe(ml, "headPose", "yaw"),
                "head_pitch":   safe(ml, "headPose", "pitch"),
                "head_roll":    safe(ml, "headPose", "roll"),
                "l_eye_open_p": safe(ml, "leftEyeOpenProb"),
                "r_eye_open_p": safe(ml, "rightEyeOpenProb"),
                "l_iris_x":     l_iris_x,
                "l_iris_y":     l_iris_y,
                "r_iris_x":     r_iris_x,
                "r_iris_y":     r_iris_y,
                "l_iris_depth": safe(mp, "leftIrisDepth"),
                "r_iris_depth": safe(mp, "rightIrisDepth"),
                # Quality flags
                "overall_conf": safe(q, "overallConfidence"),
                "blink":        1 if q.get("blink") else 0,
                "head_move_large": 1 if q.get("headMovement") == "large" else 0,
                "mediapipe_ok": 1 if mp.get("detected") else 0,
                "mlkit_ok":     1 if ml.get("detected") else 0,
                # Image sources
                "left_crop_b64":  mp.get("leftEyeCrop"),
                "right_crop_b64": mp.get("rightEyeCrop"),
                "left_crop_url":  s.get("leftEyeCropUrl"),
                "right_crop_url": s.get("rightEyeCropUrl"),
            }
            all_rows.append(row)

df = pd.DataFrame(all_rows)
print(f"✅ Total samples loaded: {len(df)}")
print(df["mode"].value_counts())
print(df["blindness_type"].value_counts())

════════════════════════════════════════════════════════════════
SECTION 6: DATA QUALITY FILTERING & PREPROCESSING
════════════════════════════════════════════════════════════════

# Filter: keep only samples with valid labels and mediapipe detection

df_clean = df[
(df["target_x"].between(0, 1)) &
(df["target_y"].between(0, 1)) &
(df["mediapipe_ok"] == 1) &
(df["overall_conf"] >= 0.5) &
(df["blink"] == 0) & # remove blink frames
(df["head_move_large"] == 0) # remove large head movements
].copy()

print(f"Samples after quality filter: {len(df_clean)}")
print(f"Samples removed: {len(df) - len(df_clean)}")

# Normalize head pose angles to [-1, 1]

for col in ["head_yaw", "head_pitch", "head_roll"]:
df_clean[col] = df_clean[col].clip(-90, 90) / 90.0

# Build image array + numeric feature matrix

NUMERIC_COLS = [
"left_ear", "right_ear", "ipd_norm",
"head_yaw", "head_pitch", "head_roll",
"l_eye_open_p", "r_eye_open_p",
"l_iris_x", "l_iris_y", "r_iris_x", "r_iris_y",
"l_iris_depth", "r_iris_depth"
]
df_clean[NUMERIC_COLS] = df_clean[NUMERIC_COLS].fillna(0.0)

images_left, images_right, num_feats, labels = [], [], [], []
indices_used = []

for i, row in tqdm(df_clean.iterrows(), total=len(df_clean), desc="Loading images"):
img_l = None
img_r = None

    # Prefer base64, fallback to URL
    if isinstance(row.left_crop_b64, str) and len(row.left_crop_b64) > 50:
        img_l = decode_b64_image(row.left_crop_b64)
    elif isinstance(row.left_crop_url, str) and row.left_crop_url.startswith("http"):
        img_l = fetch_url_image(row.left_crop_url)

    if isinstance(row.right_crop_b64, str) and len(row.right_crop_b64) > 50:
        img_r = decode_b64_image(row.right_crop_b64)
    elif isinstance(row.right_crop_url, str) and row.right_crop_url.startswith("http"):
        img_r = fetch_url_image(row.right_crop_url)

    # Fill missing eye with zeros (some samples may have only one)
    if img_l is None: img_l = np.zeros((64, 64), dtype=np.float32)
    if img_r is None: img_r = np.zeros((64, 64), dtype=np.float32)

    images_left.append(img_l[..., np.newaxis])   # (64,64,1)
    images_right.append(img_r[..., np.newaxis])
    num_feats.append(row[NUMERIC_COLS].values.astype(np.float32))
    labels.append([row["target_x"], row["target_y"]])
    indices_used.append(i)

X_left = np.array(images_left, dtype=np.float32) # (N, 64, 64, 1)
X_right = np.array(images_right, dtype=np.float32)
X_num = np.array(num_feats, dtype=np.float32) # (N, 14)
y = np.array(labels, dtype=np.float32) # (N, 2)

print(f"Dataset shapes → X_left:{X_left.shape} X_num:{X_num.shape} y:{y.shape}")

════════════════════════════════════════════════════════════════
SECTION 7: TRAIN/VALIDATION/TEST SPLIT
════════════════════════════════════════════════════════════════

Split by SESSION (not by sample) to prevent data leakage across
participants. Samples from the same session must all go to the
same split.

from sklearn.model_selection import GroupShuffleSplit

df_used = df_clean.iloc[indices_used].reset_index(drop=True)
groups = df_used["session_id"].values

gss = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=42)
train_val_idx, test_idx = next(gss.split(X_left, y, groups=groups))

gss2 = GroupShuffleSplit(n_splits=1, test_size=0.125, random_state=42)
train_idx, val_idx = next(gss2.split(
X_left[train_val_idx], y[train_val_idx],
groups=groups[train_val_idx]
))
train_idx = train_val_idx[train_idx]
val_idx = train_val_idx[val_idx]

print(f"Train: {len(train_idx)} Val: {len(val_idx)} Test: {len(test_idx)}")

════════════════════════════════════════════════════════════════
SECTION 8: MODEL DEFINITIONS
════════════════════════════════════════════════════════════════

import tensorflow as tf
from tensorflow.keras import layers, Model, Input

# ── MODEL A: Dual-Eye CNN + Numeric Fusion ─────────────────────────────────

def build_eye_cnn(name="cnn"):
inp = Input(shape=(64, 64, 1), name=f"{name}\_input")
x = layers.Conv2D(32, 3, padding="same", activation="relu")(inp)
x = layers.BatchNormalization()(x)
x = layers.MaxPool2D()(x)
x = layers.Conv2D(64, 3, padding="same", activation="relu")(x)
x = layers.BatchNormalization()(x)
x = layers.MaxPool2D()(x)
x = layers.Conv2D(128, 3, padding="same", activation="relu")(x)
x = layers.BatchNormalization()(x)
x = layers.GlobalAveragePooling2D()(x)
x = layers.Dense(128, activation="relu")(x)
x = layers.Dropout(0.3)(x)
return Model(inp, x, name=name)

def build_cnn_model(num_features=14):
left_cnn = build_eye_cnn("left_eye_cnn")
right_cnn = build_eye_cnn("right_eye_cnn")

    inp_num = Input(shape=(num_features,), name="numeric_input")
    n = layers.Dense(64, activation="relu")(inp_num)
    n = layers.BatchNormalization()(n)
    n = layers.Dense(64, activation="relu")(n)
    n = layers.Dropout(0.2)(n)

    merged = layers.Concatenate()([left_cnn.output, right_cnn.output, n])
    z = layers.Dense(256, activation="relu")(merged)
    z = layers.Dropout(0.3)(z)
    z = layers.Dense(128, activation="relu")(z)
    z = layers.Dropout(0.2)(z)
    out = layers.Dense(2, activation="sigmoid", name="gaze_xy")(z)

    model = Model(
        inputs=[left_cnn.input, right_cnn.input, inp_num],
        outputs=out,
        name="DualEye_CNN_Gaze"
    )
    return model

# ── MODEL B: LSTM for temporal sequences (moving phase) ─────────────────────

def build_lstm_model(seq_len=10, num_features=14):
"""
Uses only numeric features in a time sequence.
For the moving phase where gaze changes smoothly over time.
"""
inp = Input(shape=(seq_len, num_features), name="sequence_input")
x = layers.LSTM(128, return_sequences=True)(inp)
x = layers.Dropout(0.3)(x)
x = layers.LSTM(64)(x)
x = layers.Dense(64, activation="relu")(x)
x = layers.Dropout(0.2)(x)
out = layers.Dense(2, activation="sigmoid", name="gaze_xy")(x)
return Model(inp, out, name="LSTM_Gaze")

# ── MODEL C: CNN features fed into LSTM (Hybrid) ────────────────────────────

def build_hybrid_model(seq_len=10, num_features=14):
"""
Extracts CNN features per frame, then passes sequence through LSTM.
Best for moving phase with rich visual data.
"""
frame_img_inp = Input(shape=(seq_len, 64, 64, 1), name="img_sequence")
frame_num_inp = Input(shape=(seq_len, num_features), name="num_sequence")

    # Apply CNN to each time step with TimeDistributed wrapper
    cnn_base = build_eye_cnn("shared_cnn")
    cnn_feats = layers.TimeDistributed(cnn_base, name="td_cnn")(frame_img_inp)

    merged_seq = layers.Concatenate(axis=-1)([cnn_feats, frame_num_inp])

    x = layers.LSTM(128, return_sequences=True)(merged_seq)
    x = layers.Dropout(0.3)(x)
    x = layers.LSTM(64)(x)
    x = layers.Dense(64, activation="relu")(x)
    out = layers.Dense(2, activation="sigmoid", name="gaze_xy")(x)

    return Model(inputs=[frame_img_inp, frame_num_inp], outputs=out,
                 name="Hybrid_CNN_LSTM_Gaze")

════════════════════════════════════════════════════════════════
SECTION 9: TRAINING (MODEL A — CNN)
════════════════════════════════════════════════════════════════

model_cnn = build_cnn_model(num_features=len(NUMERIC_COLS))
model_cnn.compile(
optimizer=tf.keras.optimizers.Adam(1e-3),
loss="mse",
metrics=["mae"]
)
model_cnn.summary()

callbacks = [
tf.keras.callbacks.ReduceLROnPlateau(
monitor="val_mae", patience=5, factor=0.5, min_lr=1e-6, verbose=1),
tf.keras.callbacks.EarlyStopping(
monitor="val_mae", patience=15, restore_best_weights=True, verbose=1),
tf.keras.callbacks.ModelCheckpoint(
"best_cnn_gaze.h5", monitor="val_mae", save_best_only=True, verbose=1),
]

history_cnn = model_cnn.fit(
x=[X_left[train_idx], X_right[train_idx], X_num[train_idx]],
y=y[train_idx],
validation_data=(
[X_left[val_idx], X_right[val_idx], X_num[val_idx]],
y[val_idx]
),
epochs=80,
batch_size=32,
callbacks=callbacks,
)

# Evaluate on test set

test*loss, test_mae = model_cnn.evaluate(
[X_left[test_idx], X_right[test_idx], X_num[test_idx]],
y[test_idx]
)
avg_screen_w = df_used.iloc[test_idx]["screen_w"].mean()
avg_screen_h = df_used.iloc[test_idx]["screen_h"].mean()
pixel_err_x = test_mae * avg*screen_w
pixel_err_y = test_mae * avg_screen_h
print(f"\n✅ Test MAE (normalized): {test_mae:.4f}")
print(f"✅ Estimated pixel error: ≈{pixel_err_x:.1f}px horizontal, {pixel_err_y:.1f}px vertical")

════════════════════════════════════════════════════════════════
SECTION 10: TRAINING (MODEL B — LSTM)
════════════════════════════════════════════════════════════════

Build sequences from the numeric features for temporal modeling.

SEQ_LEN = 10

def build_sequences(X_num_data, y_data, session_ids, seq_len=10):
"""
Groups samples by session and creates non-overlapping windows.
Only samples within the same session are sequenced together.
"""
X_seq, y_seq = [], []
unique_sessions = np.unique(session_ids)
for sid in unique_sessions:
mask = session_ids == sid
X_s = X_num_data[mask]
y_s = y_data[mask]
for start in range(0, len(X_s) - seq_len + 1, seq_len):
X_seq.append(X_s[start:start + seq_len])
y_seq.append(y_s[start + seq_len - 1]) # label = last frame target
return np.array(X_seq, dtype=np.float32), np.array(y_seq, dtype=np.float32)

sess_ids_used = df_used["session_id"].values
X_seq_tr, y_seq_tr = build_sequences(X_num[train_idx], y[train_idx], sess_ids_used[train_idx], SEQ_LEN)
X_seq_va, y_seq_va = build_sequences(X_num[val_idx], y[val_idx], sess_ids_used[val_idx], SEQ_LEN)
X_seq_te, y_seq_te = build_sequences(X_num[test_idx], y[test_idx], sess_ids_used[test_idx], SEQ_LEN)

model_lstm = build_lstm_model(seq_len=SEQ_LEN, num_features=len(NUMERIC_COLS))
model_lstm.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="mse", metrics=["mae"])

history*lstm = model_lstm.fit(
X_seq_tr, y_seq_tr,
validation_data=(X_seq_va, y_seq_va),
epochs=80, batch_size=32,
callbacks=callbacks,
)
*, lstm_mae = model_lstm.evaluate(X_seq_te, y_seq_te)
print(f"\n✅ LSTM Test MAE: {lstm_mae:.4f} (≈{lstm_mae\*avg_screen_w:.1f}px)")

════════════════════════════════════════════════════════════════
SECTION 11: VISUALIZATION & THESIS REPORTING
════════════════════════════════════════════════════════════════

import matplotlib.pyplot as plt

fig, axes = plt.subplots(1, 2, figsize=(14, 5))

# Training curves — CNN

axes[0].plot(history_cnn.history["mae"], label="CNN Train MAE")
axes[0].plot(history_cnn.history["val_mae"], label="CNN Val MAE")
axes[0].set_title("CNN Gaze Model — Learning Curve")
axes[0].set_xlabel("Epoch"); axes[0].set_ylabel("MAE (normalized)")
axes[0].legend(); axes[0].grid(True)

# Training curves — LSTM

axes[1].plot(history_lstm.history["mae"], label="LSTM Train MAE", color="orange")
axes[1].plot(history_lstm.history["val_mae"], label="LSTM Val MAE", color="red")
axes[1].set_title("LSTM Gaze Model — Learning Curve")
axes[1].set_xlabel("Epoch"); axes[1].set_ylabel("MAE (normalized)")
axes[1].legend(); axes[1].grid(True)

plt.tight_layout()
plt.savefig("training_curves.png", dpi=150)
plt.show()

# Gaze prediction scatter plot (CNN model)

y_pred_cnn = model_cnn.predict([X_left[test_idx], X_right[test_idx], X_num[test_idx]])
fig, ax = plt.subplots(figsize=(8, 6))
ax.scatter(y[test_idx, 0], y[test_idx, 1], c="blue", alpha=0.4, s=10, label="Ground Truth")
ax.scatter(y_pred_cnn[:, 0], y_pred_cnn[:, 1], c="red", alpha=0.4, s=10, label="CNN Predicted")
for i in range(min(200, len(test_idx))):
ax.plot([y[test_idx[i], 0], y_pred_cnn[i, 0]],
[y[test_idx[i], 1], y_pred_cnn[i, 1]], "gray", alpha=0.15, linewidth=0.5)
ax.set_xlim(0, 1); ax.set_ylim(0, 1)
ax.set_xlabel("X (normalized screen)"); ax.set_ylabel("Y (normalized screen)")
ax.set_title("CNN Gaze: Predicted vs Ground Truth")
ax.legend(); ax.invert_yaxis()
plt.savefig("gaze_scatter.png", dpi=150)
plt.show()

# Per-mode error breakdown

df_test = df_used.iloc[test_idx].copy()
df_test["pred_x"] = y_pred_cnn[:, 0]
df_test["pred_y"] = y_pred_cnn[:, 1]
df_test["err"] = np.sqrt(
(df_test["pred_x"] - df_test["target_x"])**2 +
(df_test["pred_y"] - df_test["target_y"])**2
)
print("\n📊 Per-phase error (Euclidean, normalized):")
print(df_test.groupby("mode")["err"].mean().round(4))
print("\n📊 Per-blindness-type error:")
print(df_test.groupby("blindness_type")["err"].mean().round(4))

# Model comparison table for thesis

print("\n╔══════════════════════════════════════════════════════╗")
print(f"║ CNN Test MAE: {test_mae:.4f} ({test_mae*avg_screen_w:.1f}px) ║")
print(f"║ LSTM Test MAE: {lstm_mae:.4f} ({lstm_mae*avg_screen_w:.1f}px) ║")
print("╚══════════════════════════════════════════════════════╝")

════════════════════════════════════════════════════════════════
SECTION 12: SAVE & EXPORT FOR THESIS
════════════════════════════════════════════════════════════════

# Save both models

model_cnn.save("gaze_model_cnn.h5")
model_lstm.save("gaze_model_lstm.h5")

# Export predictions to CSV for statistical analysis

pred_df = pd.DataFrame({
"session_id": df_used.iloc[test_idx]["session_id"].values,
"mode": df_used.iloc[test_idx]["mode"].values,
"color_label": df_used.iloc[test_idx]["color_label"].values,
"blindness_type": df_used.iloc[test_idx]["blindness_type"].values,
"target_x": y[test_idx, 0],
"target_y": y[test_idx, 1],
"pred_x": y_pred_cnn[:, 0],
"pred_y": y_pred_cnn[:, 1],
"mae_x": np.abs(y_pred_cnn[:, 0] - y[test_idx, 0]),
"mae_y": np.abs(y_pred_cnn[:, 1] - y[test_idx, 1]),
})
pred_df.to_csv("gaze_predictions.csv", index=False)
print("✅ Predictions saved to gaze_predictions.csv")

# Download all results

from google.colab import files
files.download("best_cnn_gaze.h5")
files.download("gaze_model_lstm.h5")
files.download("gaze_predictions.csv")
files.download("training_curves.png")
files.download("gaze_scatter.png")

════════════════════════════════════════════════════════════════
SECTION 13: THESIS METRICS TO REPORT
════════════════════════════════════════════════════════════════

For your thesis chapter, generate and report these exact numbers:

1. Dataset size: total sessions, total samples, per-mode breakdown
2. Quality filter retention rate (how many samples passed quality filter)
3. Train/Val/Test split counts (by session, not by sample)
4. CNN model:
   - Test MSE, Test MAE (normalized)
   - Estimated pixel error on average screen resolution
   - Per-phase MAE: calibration / pulse / moving
   - Per-blindness-type MAE: Myopia vs Cataract
5. LSTM model: same metrics
6. Model comparison table (CNN vs LSTM vs Hybrid if trained)
7. Learning curve plots (saved as PNG)
8. Gaze prediction scatter plot
9. CNN vs LSTM MAE bar chart grouped by phase
10. State your coordinate system: labels in [0,1] normalized screen space,
    (0,0) = top-left, (1,1) = bottom-right, matching Android screen coordinates

Please generate all the above code, run it step by step, and provide
complete working implementations of all three models with training,
evaluation, and visualization. Add comments throughout explaining
each design decision for the thesis write-up.
