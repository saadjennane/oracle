# ORACLE POC

A Flutter proof-of-concept app for iOS + Android - a magic/mentalism performance tool that creates the illusion of predicting spectator choices across 3 rounds, then displays a "written in advance" prediction in a Notes-inspired interface.

## Features

### Game Types
- **Binary (Yes/No)** - 2-choice prediction game
- **Multi-choice** - 4-choice prediction game
- **Duel (RPS)** - Rock/Paper/Scissors with win/loss tracking

### Input Modes
- **Preprogrammed (Mode A)** - Performer sets predictions in advance, only records spectator choices
- **Two Inputs (Mode B)** - Record both performer and spectator choices per round

### Narrative Styles
- **Minimal** - Concise predictions (120-180 words)
- **Psychological** - Detailed, mystical narrative (160-240 words)

### Key Features
- Template-based narrative generation (no AI required)
- Pattern detection for adaptive storytelling
- Notes-inspired reveal screen with fake timestamps
- Session history (last 5 games)
- Copy & share functionality

## Project Structure

```
oracle_poc/
├── lib/
│   ├── main.dart              # App entry point
│   ├── app.dart               # MaterialApp with routes
│   ├── models/                # Data models
│   │   ├── game_type.dart
│   │   ├── input_mode.dart
│   │   ├── narrative_style.dart
│   │   ├── round_input.dart
│   │   ├── game_session.dart
│   │   ├── computed_result.dart
│   │   ├── pattern_summary.dart
│   │   └── models.dart        # Barrel export
│   ├── engine/                # Core logic
│   │   ├── game_engine.dart
│   │   ├── narrative_engine.dart
│   │   ├── pattern_detector.dart
│   │   └── engine.dart        # Barrel export
│   ├── data/                  # Persistence
│   │   ├── local_storage.dart
│   │   ├── session_repository.dart
│   │   └── data.dart          # Barrel export
│   ├── ui/
│   │   ├── screens/           # App screens
│   │   │   ├── home_screen.dart
│   │   │   ├── setup_screen.dart
│   │   │   ├── rounds_input_screen.dart
│   │   │   ├── narration_preview_screen.dart
│   │   │   ├── fake_note_screen.dart
│   │   │   ├── history_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── theme/
│   │       ├── app_theme.dart
│   │       └── note_theme.dart
│   └── utils/                 # State management
│       ├── game_provider.dart
│       ├── history_provider.dart
│       └── settings_provider.dart
└── test/
    └── engine/                # Unit tests
        ├── game_engine_test.dart
        ├── narrative_engine_test.dart
        └── pattern_detector_test.dart
```

## Prerequisites

- Flutter SDK 3.24+
- Dart SDK 3.5+
- iOS Simulator or Android Emulator (or physical device)

## Getting Started

### 1. Install Dependencies

```bash
cd oracle_poc
flutter pub get
```

### 2. Run the App

```bash
# iOS Simulator
flutter run -d ios

# Android Emulator
flutter run -d android

# List available devices
flutter devices
```

### 3. Run Tests

```bash
flutter test
```

### 4. Build for Release

```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release
```

## Usage Flow

1. **Home Screen** - Select game type (Binary, Multi-choice, or Duel)
2. **Setup Screen** - Configure input mode, customize options, set preprogrammed choices
3. **Rounds Input** - Record spectator choices (and performer choices in Mode B)
4. **Preview Screen** - View generated narrative, toggle styles, regenerate
5. **Reveal Screen** - Show Notes-inspired prediction with timestamp

## Dependencies

- `provider: ^6.1.1` - State management
- `shared_preferences: ^2.2.2` - Local storage
- `uuid: ^4.2.1` - Unique ID generation
- `share_plus: ^7.2.1` - Share functionality

## POC Validation Checklist

- [x] Discreet input flow (1-2 inputs per round)
- [x] Narrative engine generates coherent predictions
- [x] Notes-inspired reveal screen
- [x] Pattern detection (perfectRun, oneMiss, multipleMiss)
- [x] Duel scoring with flow detection
- [x] Two narrative styles with word count targets
- [x] Session history persistence
- [x] Copy and share functionality
- [x] Fake timestamp option
- [x] Unit tests for engine layer

## Architecture Notes

### State Management
Uses Provider with three main providers:
- `GameProvider` - Active game session state
- `HistoryProvider` - Session history management
- `SettingsProvider` - App preferences

### Narrative Generation
Template-based system with:
- Separate templates per game type × style
- Synonym pools for variation
- Pattern-aware commentary
- Word count validation

### Data Persistence
SharedPreferences-based storage:
- JSON serialization for all models
- Maximum 5 sessions retained
- Settings persistence

## License

Proprietary - POC Build
