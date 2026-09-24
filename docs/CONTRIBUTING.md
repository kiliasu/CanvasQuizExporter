# Contributing

Use Flutter 3.47.5 / Dart 3.13.4 and Visual Studio 2022 with "Desktop development with C++". Run `tool/prepare_windows.ps1` once before the first build.

`lib/domain` reads saved pages and writes the exports, `lib/services` holds the controller and the Windows integration, `lib/ui` the interface (widgets named `Reference*` implement its Material 3 Expressive design) and `lib/l10n` every string in Chinese and English.

```powershell
dart format lib test tool
flutter analyze --no-pub
flutter test --no-pub
./tool/build_windows.ps1
```

`build_windows.ps1` repeats those checks, builds the release and verifies it: the license files and complete icon font in the output, a native self-test that exports and renders a PDF, and closing the app while idle, exporting and previewing. Reports go to `build/validation/`. It also re-renders `docs/images/` from `assets/demo.html`; commit the images when the interface changes.

Keep `pubspec.lock` committed and explain dependency upgrades; update `THIRD_PARTY_NOTICES.md` and `licenses/` with them.

Add regression tests for behavior changes: parsing, exported content, queue state, cancellation, native calls and interface flows. Tests use synthetic HTML only. Never commit real course pages, names, emails, tokens or screenshots of them, and report unsupported layouts with the smallest synthetic example that shows the problem.

Put interface text in `lib/l10n/strings.dart` with both the Chinese and the English wording. `test/l10n_test.dart` fails if Chinese text shows up in the English interface or English text overflows the minimum window.

Keep changes small and direct. Preserve saved-answer semantics, offline operation and the shared filtering pipeline, and don't add a server, browser runtime or second language for application logic.
