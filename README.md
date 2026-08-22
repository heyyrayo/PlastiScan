# PlastiScan

**AI-powered plastic safety scanner built with Flutter.**

PlastiScan lets users scan or manually identify plastic products and instantly receive a risk assessment — including plastic type, chemical codes, and a safety score — powered by an AI analysis pipeline backed by Supabase.

---

## Features

| Feature | Description |
|---|---|
| **Camera Scanner** | Live camera viewfinder with animated scan line, bracket guides, torch toggle, and one-tap capture |
| **Gallery Import** | Pick an existing product photo from the device gallery for analysis |
| **Manual Entry** | Enter product name, plastic code, and category manually to trigger AI analysis |
| **AI Analysis** | Staged loading screen that walks through polymer identification, chemical composition, safety database lookup, and risk profiling |
| **Risk Results** | Animated results screen showing risk score (0-10), risk level badge (Low / Medium / High / Unknown), plastic type, and chemical codes |
| **Scan History** | Searchable, filterable scan history grouped by time period |
| **Authentication** | Email/password sign-up, sign-in, and password reset via Supabase Auth with route-level guards |
| **Profile** | View account info and log out |
| **State Screens** | Dedicated screens for offline, no-internet, analysis-failed, no-history, and unknown-product states |
| **Image Storage** | Captured images are compressed (JPEG quality 82, max 1600x1600) and uploaded to a user-scoped Supabase Storage bucket |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart >= 3.6) |
| State Management | Riverpod (`flutter_riverpod ^2.6`) |
| Navigation | GoRouter (`^14.6`) |
| Backend / Auth | Supabase (`supabase_flutter ^2.17`) |
| Image Capture | `camera ^0.11` + `image_picker ^1.1` |
| Image Compression | `flutter_image_compress ^2.4` |
| Typography | `google_fonts ^6.2` |
| Loading Effects | `shimmer ^3.0` |
| Environment | `flutter_dotenv ^6.0` |

---

## Project Structure

```
lib/
+-- core/
|   +-- config/
|   |   +-- supabase_config.dart       # Loads SUPABASE_URL + SUPABASE_PUBLISHABLE_KEY from .env
|   +-- errors/
|       +-- auth_error_handler.dart
+-- models/
|   +-- scan_result.dart               # Immutable scan data model (id, product, type, risk, score, codes)
|   +-- risk_level.dart                # RiskLevel enum (low / medium / high / unknown) + extensions
|   +-- history_entry.dart             # Grouped history model (period label + list of ScanResults)
+-- router/
|   +-- app_router.dart                # GoRouter config with shell route + auth redirect
|   +-- auth_router_notifier.dart      # ChangeNotifier that drives auth-based redirects
+-- screens/
|   +-- auth/                          # LoginScreen, SignupScreen, AuthGate
|   +-- home/                          # HomeScreen - quick actions + recent scans
|   +-- scan/                          # ScanScreen - full-screen camera UI
|   +-- ai_analysis/                   # AiAnalysisScreen - staged loading animation
|   +-- results/                       # ResultsScreen - animated risk ring + detail cards
|   +-- history/                       # HistoryScreen - search + filter + timeline
|   +-- manual_entry/                  # ManualEntryScreen - form-based plastic lookup
|   +-- profile/                       # ProfileScreen - user info + logout
|   +-- states/                        # StateScreen - offline / error / empty states
+-- services/
|   +-- analysis_service.dart          # ScanService + AnalysisService (AI integration surface)
|   +-- auth_service.dart              # AuthService wrapping Supabase Auth
|   +-- storage_service.dart           # StorageService - compress + upload to Supabase Storage
+-- theme/
|   +-- app_theme.dart                 # MaterialTheme builder
|   +-- plastiscan_colors.dart         # Custom ThemeExtension (gradient colours, risk palette)
+-- widgets/
    +-- app_bottom_sheet.dart
    +-- app_card.dart
    +-- app_chip.dart
    +-- app_text_field.dart
    +-- bottom_nav_bar.dart
    +-- molecular_background.dart      # Animated node/particle background used in the header
    +-- risk_indicator.dart
    +-- skeleton_loader.dart
    +-- buttons/
        +-- app_buttons.dart
```

---

## Getting Started

### Prerequisites

- Flutter SDK >= 3.6 — [install guide](https://docs.flutter.dev/get-started/install)
- A [Supabase](https://supabase.com) project with:
  - Auth enabled (email/password)
  - A storage bucket named `scan-images` with user-scoped RLS policies

### 1 — Clone the repo

```bash
git clone https://github.com/heyyrayo/PlastiScan.git
cd PlastiScan
```

### 2 — Set up environment variables

Create a `.env` file in the project root:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-anon-key
```

> The `.env` file is listed in `.gitignore` and will never be committed.

### 3 — Install dependencies

```bash
flutter pub get
```

### 4 — Run the app

```bash
flutter run
```

---

## Navigation Routes

| Route | Screen | Shell Nav |
|---|---|---|
| `/` | Home | Yes |
| `/history` | History | Yes |
| `/manual-entry` | Manual Entry | Yes |
| `/profile` | Profile | Yes |
| `/scan` | Camera Scanner | Full-screen |
| `/ai-analysis` | AI Analysis Loading | Full-screen |
| `/results` | Results | Full-screen |
| `/login` | Login | Auth only |
| `/signup` | Sign Up | Auth only |
| `/state/offline` | Offline State | Full-screen |
| `/state/no-internet` | No Internet State | Full-screen |
| `/state/analysis-failed` | Analysis Failed | Full-screen |
| `/state/no-history` | No History | Full-screen |
| `/state/unknown-product` | Unknown Product | Full-screen |

---

## Risk Levels

| Level | Score Range | Meaning |
|---|---|---|
| Low | 0 - 3 | Plastic is generally considered safe for intended use |
| Medium | 3 - 6 | Some risk factors present; use with caution |
| High | 6 - 10 | Significant risk factors; avoid contact with food or heat |
| Unknown | - | Insufficient data to determine risk |

---

## Contributing

1. Fork the repo and create a feature branch: `git checkout -b feat/your-feature`
2. Commit your changes following conventional commits
3. Open a Pull Request against `main`

---

## License

This project is for demonstration and educational purposes.
