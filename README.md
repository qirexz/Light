# Gym Tracker

A full-featured workout tracking app built in 9 phases: unlimited-history
progress graphs, advanced statistics, routines with supersets, automatic
PR detection, body measurements with progress photos, a plate calculator,
and data export/import — all running locally on-device with no backend
or account required.

## Feature summary

- **Exercise library**: ~120 built-in exercises across every muscle
  group and equipment type, with search/filter/browse
- **Workout logging**: sets, reps, weight, rest timer (with optional
  background notification), supersets
- **Routines**: build/save workout templates with target sets/reps/
  weight, start a workout from one in a tap
- **History**: list and calendar views, unlimited time range, edit or
  delete any past workout
- **Personal records**: automatic detection of heaviest weight, best
  1RM, best volume, best reps, best duration/distance, with a
  celebration dialog when you PR
- **Analytics**: per-exercise progress graphs (switchable metrics),
  weekly volume trend, muscle group balance, most-trained exercises —
  all unlimited history, no time-window cutoff anywhere
- **Body measurements**: weight, body fat %, 13 circumference
  measurements, each with its own graph, plus a progress photo gallery
- **Settings**: metric/imperial units, configurable rest timer default,
  notification toggle, full data export/import (JSON backup), reset

## Project structure

```
lib/
  models/       Plain data classes (Exercise, Workout, Set, Routine, ...)
  data/         SQLite repositories - one per domain area
  state/        App-wide state (ActiveWorkoutManager, SettingsManager)
  screens/      One file per screen
  widgets/      Reusable UI pieces (charts, timers, set rows)
  utils/        Formatting, unit conversion, enum labels
```

## How to run this yourself

You'll need [Flutter](https://docs.flutter.dev/get-started/install)
installed, OR you can skip local setup entirely and use the cloud build
walkthrough below.

### 1. Generate platform folders

This project only ships the `lib/` (Dart) code. Flutter needs
platform-specific folders (`android/`, `ios/`, etc.), which are
generated locally rather than handed to you as source since they
contain machine-specific config. From inside the `gym_app` folder:

```bash
flutter create .
```

This won't touch anything in `lib/` or `pubspec.yaml` — it only fills
in the missing platform scaffolding.

**Permission notes** — a couple of features need platform permission
entries that `flutter create .` may not add by default:
- **Progress photos** (`image_picker`): on Android 13+ no extra
  permission is normally needed; older Android may need
  `READ_MEDIA_IMAGES` or `READ_EXTERNAL_STORAGE` in
  `android/app/src/main/AndroidManifest.xml`. On iOS, add
  `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription` to
  `ios/Runner/Info.plist`.
- **Rest timer notifications** (`flutter_local_notifications`): on
  Android 13+, add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
  to `AndroidManifest.xml` if it isn't already present. The app
  requests the runtime permission automatically on first launch.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run it

```bash
flutter run
```

(with an emulator running, or a phone connected via USB with developer
mode / USB debugging enabled)

## Building the APK

### Option A — locally

Once you've done steps 1–2 above:

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.
Copy it to your phone and install it (you may need to allow "install
from unknown sources" for your file manager or browser app).

### Option B — Codemagic (no local Flutter install needed)

This is the simplest path if you don't want to install Flutter/Android
Studio at all.

1. **Push this project to a GitHub repo.** Create a new repo (public or
   private both work), then from inside the `gym_app` folder:
   ```bash
   git init
   git add .
   git commit -m "Gym Tracker"
   git branch -M main
   git remote add origin <your-repo-url>
   git push -u origin main
   ```
2. **Sign up at [codemagic.io](https://codemagic.io)** using your GitHub
   account (free tier covers this comfortably).
3. **Add your app**: click "Add application", pick GitHub, and select
   the repo you just pushed. Codemagic will detect it as a Flutter app.
4. **Use the default Flutter workflow.** You don't need custom build
   scripts — the default workflow runs `flutter packages pub get` and
   `flutter build apk` for you. If it asks which build target, choose
   **Android** and **APK** (not App Bundle, since you want a
   directly-installable file rather than something for the Play Store).
5. **Start the build.** It takes a few minutes. When it finishes,
   Codemagic shows a build artifacts list — download the `.apk` file
   from there.
6. **Install on your phone**: transfer the APK (email it to yourself,
   use a cloud drive, or scan a QR code if Codemagic offers one) and
   open it on your device to install. You'll likely need to allow
   "install unknown apps" for whichever app you used to open the file.

From here on, any time you push a new commit to the repo, you can
trigger another Codemagic build to get an updated APK — handy if you
want to keep tweaking the app yourself.

## Known limitations

- **Units are a display preference, not a converter.** Switching
  metric/imperial in Settings changes default labels going forward; it
  doesn't retroactively convert numbers you've already logged, since
  individual sets don't store a per-set unit (this was a deliberate
  simplicity tradeoff from Phase 1's data model).
- **Progress photo files aren't included in exported backups** — only
  their on-device file paths are. Restoring a backup on a different
  device/install will show a broken image for any measurement that had
  a photo attached.
- **No cloud sync.** Everything lives in a local SQLite database on the
  device. Use Settings → Export Data periodically if you want a backup
  off-device.
