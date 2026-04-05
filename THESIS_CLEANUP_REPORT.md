# Thesis Cleanup Report

Date: 2026-04-05

## Objective

Finalize the app for thesis submission by removing unused files, removing unused code sections, and validating code connections.

## Duplicate-Style File Name Check

- Kept: lib/services/mediapipe_service.dart (actively used in collection and diagnostic flow)
- Removed: lib/services/media_pipe_service.dart (unused duplicate-style implementation)

## Removed Unused Files

- lib/core/constants/app_theme.dart
- lib/core/utils/camera_utils.dart
- lib/core/utils/coordinate_utils.dart
- lib/models/collection_session.dart
- lib/screens/user_profile_screen.dart
- lib/services/azure_face_service.dart
- lib/services/azure_service.dart
- lib/services/data_collection_service.dart
- lib/services/data_fusion_service.dart
- lib/services/media_pipe_service.dart
- lib/services/mlkit_face_service.dart
- lib/widgets/alignment_guide.dart
- lib/widgets/camera_preview_frame.dart

## Removed Unused Code Sections

- lib/screens/collection_grid_screen.dart
  - Removed unused import: azure_data.dart
  - Removed unused fields: \_currentGridIndex, \_gridPositions, \_showCamera
  - Removed unused local variable in build()
  - Simplified moving-tap behavior to update \_colorIndex directly
- lib/screens/diagnostic_screen.dart
  - Removed unused field: \_leftCropBytes and stale assignment
- lib/screens/user_form_screen.dart
  - Removed unused local variable: lang
- lib/services/mlkit_face_service.dart
  - Removed unnecessary import from google_mlkit_commons

## Partially Used Files (Single Inbound Connection)

- lib/core/constants/collection_constants.dart <= lib/screens/collection_grid_screen.dart
- lib/core/services/firebase_initializer.dart <= lib/main.dart
- lib/core/services/haptics_service.dart <= lib/screens/collection_grid_screen.dart
- lib/firebase_options.dart <= lib/core/services/firebase_initializer.dart
- lib/models/azure_data.dart <= lib/models/eye_tracking_sample.dart
- lib/models/eye_tracking_sample.dart <= lib/screens/collection_grid_screen.dart
- lib/screens/admin_login_screen.dart <= lib/main.dart
- lib/screens/permission_screen.dart <= lib/main.dart
- lib/screens/user_agreement_screen.dart <= lib/main.dart
- lib/screens/user_form_screen.dart <= lib/main.dart
- lib/services/eye_crop_service.dart <= lib/screens/collection_grid_screen.dart
- lib/services/firestore_service.dart <= lib/screens/collection_grid_screen.dart
- lib/services/research_export_service.dart <= lib/screens/session_summary_screen.dart
- lib/widgets/accessible_text_field.dart <= lib/screens/user_form_screen.dart
- lib/widgets/pulsing_target.dart <= lib/screens/collection_grid_screen.dart

## Validation

- Final import-graph check: no orphan Dart files remain in lib/ (except entrypoint lib/main.dart)
- flutter analyze: 15 info-level issues remain (style/deprecation/lint), no new compile-blocking errors from cleanup changes
