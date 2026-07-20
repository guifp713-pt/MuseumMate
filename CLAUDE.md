# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This is a monorepo with two independent, separately-git-tracked projects (each has its own `.git`):

- **`TourAssistent-main/`** — "Museum Mate", a Qt/QML mobile app (C++17 + QML/JS) for Android and Desktop. This is the museum visitor-facing tour guide app.
- **`backend/`** — A Strapi 5 (Node/TypeScript) CMS that serves content (entities, tours, maps, areas, items, dictionaries) and receives analytics events from the app.

There is no top-level build that spans both; treat them as separate codebases that communicate over HTTP.

## Backend (`backend/`)

Strapi 5 project lives in `backend/app/`. Package manager is npm.

### Commands (run from `backend/app/`)

```
npm run develop      # start with autoReload (admin UI watches too)
npm run dev           # strapi develop
npm run start         # start without autoReload (production-style)
npm run build          # build the admin panel
npm run console          # Strapi console (REPL)
```

There is no test suite configured in `backend/app/package.json`.

### Docker

`backend/docker-compose.yml` builds from `backend/Dockerfile` and runs `backend/restore.sh`, which:
1. Scaffolds a Strapi app into `/app` if `package.json` is missing.
2. Installs root `node_modules` if missing.
3. For every directory under `src/plugins/*` with its own `package.json`, installs its deps and runs `npm run watch` in the background (so local plugins live-rebuild).
4. Starts `strapi develop --watch-admin`.

Ports: `1337` (Strapi API/admin), `5173` (Vite, admin dev server). `backend/backup/backup.sh` tars `/app` (excluding `node_modules`, `.cache`, `build`) for backups.

### Content model

Collection types under `backend/app/src/api/*/content-types/*/schema.json`, all i18n-localized (`pluginOptions.i18n.localized`) with draft & publish enabled:

- **`entidade`** (Entity) — root object per museum; has `imageEntity`, `audio`, `welcome_message`, and one-to-many relations to `maps`, `tours`, `dictionaries`.
- **`tour`** — belongs to an `entidade`; has its own `items` and `maps` relations.
- **`map`** — belongs to an `entidade`; contains `areas`.
- **`area`** — belongs to a `map`; has `posX`/`posY` coordinates, `imageArea`, `audioArea`, and its own `items`.
- **`item`** — a stop/exhibit; has `posXItem`/`posYItem`, `coverItem`, `audioItem`, and a `code` (used for QR/NFC lookup).
- **`dictionary`** — per-entity key/value translation strings, consumed client-side as a flat lookup table.
- **`analytics-event`** — event log written by the mobile app (see Analytics below).

Because relations are deeply nested and localized, the API is queried with a single large `populate` chain (see `ApiHandler.js` in the mobile app) rather than multiple requests — Strapi responses may or may not be wrapped in `.data`/`.attributes` depending on version/config, so client code defensively checks both shapes (`rawData.attributes || rawData`).

### Custom plugins (`backend/app/src/plugins/`)

- **`analytics-dashboard`** — admin-panel dashboard for visualizing analytics events; has its own `admin/src` and `server/src`, built with `@strapi/sdk-plugin` (`npm run build` / `npm run watch` inside the plugin dir).
- **`map-picker`** ("Map Pin Picker") — admin-panel widget for visually placing `posX`/`posY` pins on a map image when editing `area`/`item` content.

## Mobile app (`TourAssistent-main/`)

Qt Quick application. Project file: `AssistentTourPhone.pro` (qmake, `CONFIG += c++17`). Requires Qt modules: `core gui quick virtualkeyboard network multimedia`. Built via Qt Creator or `qmake && make` / Android build tooling (see `.qtcreator/AssistentTourPhone.pro.user` for the configured kits — Desktop MinGW 64-bit and Android arm64-v8a/armeabi-v7a, per `build/` subfolder names).

QR code scanning uses the bundled **qzxing** library (git submodule at `3rdparty/qzxing`, also vendored under `TourAssistent-main/qzxing/`) — enabled via `CONFIG += qzxing_qml qzxing_multimedia` and `include(qzxing/QZXing.pri)`.

### Architecture: C++ bridges exposed to QML

`main.cpp` instantiates C++ `QObject`s and exposes them into the QML root context (`engine.rootContext()->setContextProperty(...)`), so QML/JS calls into native code via `Q_INVOKABLE` methods and listens to Qt signals:

- **`AudioBridge`** (`AudioBridge.h/.cpp`) — playlist-based audio playback (`startAudio`, `setPlaylist`, `goToNext/Previous`, `seekTo`); on Android this proxies to a native `TourAudioService` (see `android/src/.../TourAudioService.java`) so audio survives backgrounding, with position/track-change callbacks routed back through `handlePositionChangedFromJava`/`handleTrackChangedFromJava`.
- **`FileHelper`** (`FileHelper.h/.cpp`) — downloads and locally caches remote media (`downloadFiles`), and resolves the local per-language media folder (`getLocalMediaFolder`) so previously downloaded audio/images work offline.
- **`NfcManager`** (`nfcmanager.h`) — singleton bridging Android NFC tag reads (via JNI from `MuseumActivity.java`) to a QML-visible `tagDetected(code)` signal, used to jump straight to an item by `code`.
- **`AndroidPermission`** (`androidpermission.h/.cpp`) — runtime camera permission check/request for QR scanning.
- **`QZXing`** — registered as a QML type for the QR scanner (`ScannerPage.qml`).

### Architecture: QML/JS data layer

App state lives in `main.qml` as a single `appData` property (`entities`, `maps`, `areas`, `items`, `dictionary`, `tours`, `tourItem`), rebuilt whenever the language changes via `carregarDados(lingua, passarPagina)`.

- **`ApiHandler.js`** — all Strapi communication and response shaping. `getData(lang, callback)` fetches (and SQLite-caches, via `QtQuick.LocalStorage`) the full nested payload for a language, then serves from cache on repeat calls. Separate `getEntities`/`getMaps`/`getAreas`/`getItems`/`getTours`/`getTourItems`/`getDictionary`/`extractMediaUrls` functions flatten the nested Strapi response into flat arrays the QML views bind to. `resolveUrl(path, localPath)` decides whether to point at a locally-cached file or the live `baseUrl`. **`baseUrl` is a hardcoded LAN IP that must be updated per network/environment** (several commented alternatives are left in place for different networks — a real fix would make this configurable rather than edited-and-recommitted per deployment).
- **`AnalyticsHandler.js`** — device analytics. Generates and persists a permanent per-device ID in local SQLite (`app_settings` table), POSTs events to `/api/analytics-events`, and falls back to a local `analytics_cache` table when the network request fails (for later resend). Note its `baseUrl` is a separate hardcoded constant from `ApiHandler.js`'s — keep them in sync when changing environments.
- QML pages (`WelcomePage.qml`, `HomePage.qml`, `Tours.qml`, `TourPage.qml`, `ScannerPage.qml`, `GlobalQrButton.qml`, `GlobaLButtonChatIA.qml`) are loaded/composed from `main.qml`, which also owns navigation state (`nextPage`) and language selection (`linguaEscolhida`, persisted as `linguaGuardada`).

### Networking note

`main.cpp` disables SSL peer verification globally (`QSslSocket::VerifyNone`) to avoid HTTPS download failures on Android — be aware of this when touching networking code; it means TLS cert validation is off for the whole app.
