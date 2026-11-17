# AgroShield IoT

Smart swine farm monitoring & control app built with Flutter — Dashboard,
Schedule, History & Logs, Spray Control, and Alerts, with a persistent
bottom nav, side drawer, and full light/dark theming.

This project ships as **pure source** (no compiled build artifacts), so it
stays small and works on any OS Flutter supports. You need the Flutter SDK
installed to run it — that's the only requirement.

## Quick start

1. Install Flutter (if you don't already have it): https://docs.flutter.dev/get-started/install
2. Unzip this project and open a terminal in its root folder (the one with `pubspec.yaml`).
3. Install dependencies:
   ```
   flutter pub get
   ```
4. Run it:
   ```
   flutter run
   ```
   Pick any connected device/emulator, or run straight in a browser:
   ```
   flutter run -d chrome
   ```
   or on desktop:
   ```
   flutter run -d macos      # or -d windows / -d linux
   ```

That's it — `flutter pub get` + `flutter run` is all that's needed on a
machine with Flutter installed.

## If a platform folder is missing or won't build

This zip includes ready-to-go **Android** and **Web** platform folders.
If you want to target iOS, macOS, Windows, or Linux, or if your local
Flutter/Android toolchain version needs different native project files,
just run this once in the project root:

```
flutter create .
```

This is the standard, safe way to (re)generate platform folders for an
existing Flutter codebase — it only adds/refreshes the native `ios/`,
`macos/`, `windows/`, `linux/` scaffolding and never touches your `lib/`
code, so nothing you see in this app is lost.

## What's included

- `lib/` — all app code (screens, widgets, providers, models, theme)
- `pubspec.yaml` — dependencies: `provider`, `shared_preferences`, `intl`
- `android/` — full Gradle/Kotlin project, launcher icons included
- `web/` — full web project, icons + manifest included

## Architecture at a glance

- **State management:** `provider` (`ChangeNotifier`), one provider per
  domain: theme, alerts, dashboard toggles, spray control, schedules,
  history logs.
- **Theme:** dark mode by default, persisted via `SharedPreferences`
  (`isDark` key). Toggling rebuilds the whole tree through `ThemeProvider`.
- **Navigation:** `MainShell` hosts the persistent bottom nav
  (Dashboard / Schedule / History) via `IndexedStack`. Spray Control and
  Alerts are reachable only from the drawer and are pushed as full-screen
  routes on top.
- **Responsive layout:** `lib/utils/responsive.dart` adapts grid columns,
  padding, and max content width across phone / tablet / desktop widths,
  and `main.dart` clamps system text-scaling so custom-sized widgets
  (pills, toggles) never overflow on accessibility-scaled devices.
- **Shared widgets:** `StatusPill`, `CustomToggle`, `CustomSlider`,
  `TitleBar`, `AppDrawer` — all in `lib/widgets/`.

## Notes

- The 4 pre-populated alerts and sample schedule/history entries are
  seeded in their respective providers (`lib/providers/`) so the app has
  realistic data on first launch — replace with real API/IoT data
  whenever you wire up a backend.
- Fonts use the system default (no external font downloads at runtime),
  so the app works fully offline out of the box.
