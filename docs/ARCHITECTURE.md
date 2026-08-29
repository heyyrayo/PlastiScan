# PlastiScan Architecture Overview

This document explains the main building blocks of the app and how the core navigation flow works.

## 1. App Layers

### Interface layer
- `lib/screens/` contains the feature screens for home, scan, results, history, auth, profile, and state pages.
- Shared UI primitives live in `lib/widgets/` to keep screen code consistent and reusable.

### Domain layer
- `lib/models/` defines the app data structures used across the flow such as `ScanResult`, `RiskLevel`, and history models.
- Business behavior is centered around scan analysis, storage, and auth services in `lib/services/`.

### Navigation layer
- `lib/router/app_router.dart` wires the app routes and auth redirect flow.
- `lib/core/navigation/app_navigation.dart` centralizes the back-button logic and route helpers to keep transitions consistent.

## 2. User Flow

1. The app opens on the home screen.
2. Users can choose to scan from the camera, select an image from gallery, or enter a plastic manually.
3. The scan result flows into the AI analysis screen and then the results screen.
4. History and state pages are available as shell or full-screen routes depending on user context.

## 3. Authentication and Shell Routing

- A `ShellRoute` keeps the main app scaffold and bottom navigation in a single place.
- Auth routes are protected by a redirect check in `app_router.dart`.
- The app avoids replacing the route stack in sensitive flows so back navigation still feels predictable.

## 4. Storage and Analysis

- The storage service handles image upload and compression before analysis.
- The analysis service is modeled as the application boundary for AI-driven plastic safety checks.
- Supabase keys are read from `.env` via the config object in `lib/core/config/supabase_config.dart`.

## 5. Design Principles

- UI should remain shell-stable and predictable across Android back gestures and app bar actions.
- Screen transitions should retain navigation history when a user moves into a detail flow.
- App branding, reuse, and maintainability should stay consistent across each feature area.
