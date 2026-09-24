# Third-party notices

The application's MIT license does not replace third-party licenses.

| Component | Role | Notices |
| --- | --- | --- |
| Flutter / Dart | UI, engine and AOT runtime | `licenses/flutter-sdk.txt`, `licenses/dart-sdk.txt`, Flutter-generated `data/flutter_assets/NOTICES.Z` |
| Roboto Flex / Noto Sans SC | Offline UI and embedded PDF fonts | SIL OFL 1.1, `assets/fonts/roboto-flex-license.txt`, `assets/fonts/noto-sans-sc-license.txt`; sources and hashes in `assets/fonts/README.md` |
| Material Symbols Rounded | Application icons | Apache 2.0, `assets/fonts/material-symbols-license.txt` |
| Roboto | Bundled UI fallback font | Apache 2.0, `assets/fonts/roboto_license.txt` |
| html, archive, crypto, path, image | Local parsing, archives, hashing, paths and images | Corresponding files in `licenses/` |
| pdf | PDF creation | Corresponding license in `licenses/` |
| pdfrx, pdfrx_engine, pdfium_dart, pdfium_flutter | PDF preview and rendering | Corresponding MIT notices in `licenses/` |
| PDFium chromium/7811 and its dependencies | Native PDF engine | `licenses/pdfium-*.txt`, copied from the matching upstream Windows archive |
| file_selector, desktop_drop, window_manager and their dependencies | Native desktop integration | Corresponding files in `licenses/` |
| Microsoft Visual C++ Runtime | Windows runtime DLLs | Microsoft redistributable runtime terms; these DLLs are not MIT-licensed |

The checked-in notices correspond to the locked package sources, Flutter SDK and matching PDFium archive. Update these notices when upgrading dependencies. Flutter also generates aggregated notices in the build assets.

In the Windows build, `LICENSE`, this file and `licenses/` sit next to `CanvasQuizExporter.exe`. The font licenses and Flutter's `NOTICES.Z` are under `data/flutter_assets/` (fonts in `data/flutter_assets/assets/fonts/`). Keep all of them when redistributing the build.

Windows builds depend on the Microsoft Visual C++ runtime provided by the Windows C++ toolchain. Build-tool licensing and any redistribution terms remain applicable to distributors. The font assets retain upstream licenses. PDF font files are static instances generated from the pinned variable fonts; no system fonts are copied into the build. Documentation images use the same bundled fonts as the application.
