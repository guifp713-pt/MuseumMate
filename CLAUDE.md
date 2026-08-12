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
- **`tour`** — belongs to an `entidade`; has its own `items` and `maps` relations, plus (added by `specs/005-tours-listagem-visita-guiada`) `isMainTour` (boolean, marks the "full museum" tour pinned at the top of the listing), `audioTour` (intro audio played before the guided sequence starts), and `areas` (relation → `area`, areas mentioned during the guided visit).
- **`map`** — belongs to an `entidade`; contains `areas`.
- **`area`** — belongs to a `map`; has `posX`/`posY` coordinates, `imageArea`, `audioArea`, and its own `items`.
- **`item`** — a stop/exhibit; has `posXItem`/`posYItem`, `coverItem`, `audioItem`, and a `code` (used for QR/NFC lookup).
- **`dictionary`** — per-entity key/value translation strings, consumed client-side as a flat lookup table.
- **`analytics-event`** — event log written by the mobile app and the assistant backend (see Analytics below and Custom APIs below); `eventType` enum includes `assistant_question`/`assistant_decline`/`assistant_error`/`assistant_knowledge_fallback` alongside the visitor-tracking events. Every event also carries `entidadeDocumentId` (which `entidade`/museum it belongs to — the same value as `config/museum.ts`'s `ACTIVE_ENTITY_DOCUMENT_ID` at write time), added by `specs/004-analytics-multi-entity` so events from multiple museums never get aggregated together; pre-existing rows were backfilled once via `scripts/backfill-analytics-entity.js`.

Because relations are deeply nested and localized, the API is queried with a single large `populate` chain (see `ApiHandler.js` in the mobile app) rather than multiple requests — Strapi responses may or may not be wrapped in `.data`/`.attributes` depending on version/config, so client code defensively checks both shapes (`rawData.attributes || rawData`).

### Custom plugins (`backend/app/src/plugins/`)

- **`analytics-dashboard`** — admin-panel dashboard for visualizing analytics events; has its own `admin/src` and `server/src`, built with `@strapi/sdk-plugin` (`npm run build` / `npm run watch` inside the plugin dir; server/admin edits under `src/` require a rebuild — and a full Strapi restart for `server/src` changes to load, since `npm run develop` runs with `--no-watch-admin`). `HomePage.jsx` lets the administrator pick a museum (defaulting to whichever one `GET /analytics-dashboard/active-entity` — a small admin-only route reading `config/museum.ts` — reports as currently active) and scopes every KPI/chart/query to it via `filters[entidadeDocumentId][$eq]=...` (events) and the deep relation filter `filters[area][map][entidade][documentId][$eq]=...` (items — `item` has no direct relation to `entidade`). Also surfaces AI-assistant usage (answered/off-domain/error/general-knowledge-fallback counts) from the same `assistant_*` events. Talks to Strapi exclusively through `useFetchClient()` (`@strapi/strapi/admin`), never a hardcoded host.
- **`map-picker`** ("Map Pin Picker") — admin-panel widget for visually placing `posX`/`posY` pins on a map image when editing `area`/`item` content.

### Custom API: assistant (`backend/app/src/api/assistant/`)

Custom Strapi route (`POST /api/assistant/ask`, `auth: false`) — no `assistant` content-type exists.

- **`assistant-catalog.ts`** — fetches the full localized catalog for one `entidade`, filtered by the active museum (`config/museum.ts`'s `ACTIVE_ENTITY_DOCUMENT_ID`), with a 5-minute in-process cache per language.
- **`assistant-ai.ts`** — two Gemini calls (model pinned to `gemini-3.1-flash-lite`, `@google/genai`), both server-side only (the API key never reaches the mobile client):
  - `ask()` — the primary, always-attempted call: answers strictly from the catalog, declines off-domain questions, and reports (via structured JSON output) `onTopic`, `autoTranslated`, and whether the catalog was sufficient (`catalogSufficient`/`searchTopic`).
  - `answerFromKnowledge()` — only called when `onTopic && !catalogSufficient` and `config/assistant.ts`'s `KNOWLEDGE_FALLBACK_ENABLED` switch is on; a **plain** second Gemini call (no tools, no Google Search grounding — grounding needs billing, so it is deliberately avoided), with the catalog content passed in so it still takes precedence on conflict, that lets the model answer from its own trained knowledge and reports `confident` (false ⇒ treated as no answer, never a fabrication). The original design used Google Search grounding; see `specs/003-assistant-web-fallback/research.md §1/§2` for why it was replaced by a knowledge-based fallback.
- **`controllers/assistant.ts`** — orchestrates both calls, timeouts (`AI_TIMEOUT_MS`, reused for both), and writes one `analytics-event` row per interaction (`assistant_question`/`assistant_decline`/`assistant_error`/`assistant_knowledge_fallback`), never containing message/answer text; each row is stamped with `entidadeDocumentId` from `config/museum.ts`, same as the catalog service.

### Config (`backend/app/src/config/`)

- **`museum.ts`** — `ACTIVE_ENTITY_DOCUMENT_ID`, the single backend-side source of truth for which `entidade` the app/assistant serve (must match the mobile app's own copy in `ApiHandler.js`); also per-entity map zoom overrides.
- **`assistant.ts`** — `KNOWLEDGE_FALLBACK_ENABLED`, a backend-only kill switch for the assistant's general-knowledge fallback capability (the second call that answers from the model's own knowledge when the catalog can't); no mobile-side counterpart needed.

## Mobile app (`TourAssistent-main/`)

Qt Quick application. Project file: `AssistentTourPhone.pro` (qmake, `CONFIG += c++17`). Requires Qt modules: `core gui quick virtualkeyboard network multimedia`. Built via Qt Creator or `qmake && make` / Android build tooling (see `.qtcreator/AssistentTourPhone.pro.user` for the configured kits — Desktop MinGW 64-bit and Android arm64-v8a/armeabi-v7a, per `build/` subfolder names).

QR code scanning uses the bundled **qzxing** library (git submodule at `3rdparty/qzxing`, also vendored under `TourAssistent-main/qzxing/`) — enabled via `CONFIG += qzxing_qml qzxing_multimedia` and `include(qzxing/QZXing.pri)`.

### Architecture: C++ bridges exposed to QML

`main.cpp` instantiates C++ `QObject`s and exposes them into the QML root context (`engine.rootContext()->setContextProperty(...)`), so QML/JS calls into native code via `Q_INVOKABLE` methods and listens to Qt signals:

- **`AudioBridge`** (`AudioBridge.h/.cpp`) — playlist-based audio playback (`startAudio`, `setPlaylist`, `goToNext/Previous`, `seekTo`); on Android this proxies to a native `TourAudioService` (see `android/src/.../TourAudioService.java`) so audio survives backgrounding, with position/track-change callbacks routed back through `handlePositionChangedFromJava`/`handleTrackChangedFromJava`. `setPlaylist(urls, currentIndex, titles?, covers?, tourName?)` (added by `specs/006-audio-progresso-notificacao`) carries per-step title/cover and the tour name alongside the audio URLs (parallel arrays, same index), so the Android foreground-service notification can show rich content (capa/título/tour) instead of a generic "Museum Mate" label — the 3 metadata params default to empty when omitted, so the pre-existing ad-hoc single-item playlists (QR/NFC lookup of an item outside the current tour) keep calling the 2-arg form unchanged. `TourAudioService` preserves empty-URL entries in its playlist (steps without audio) so index alignment with the metadata arrays never drifts, and `handleAction(ACTION_NEXT/PREVIOUS)` treats an empty URL as a silent step (pauses without tearing down the foreground service/notification) rather than erroring out. The notification's draggable progress scrubber is **not** built by the app: it is drawn by the OS from the `MediaSession`, which requires `updateMediaMetadata()` to publish `METADATA_KEY_DURATION` (plus title/tour/album-art) alongside the position + `ACTION_SEEK_TO` already in `updatePlaybackState()` — `Notification.setProgress()` is silently ignored under `MediaStyle`, and custom `RemoteViews` are discarded outright by Android 13+ for media notifications, so neither is a viable route (see `specs/006-audio-progresso-notificacao/research.md §6`). Local cover paths arrive as `file://` URIs (from `FileHelper::getLocalMediaFolder`'s `QUrl::fromLocalFile`) and must have that prefix stripped before `BitmapFactory.decodeFile`, which fails silently otherwise.
- **`FileHelper`** (`FileHelper.h/.cpp`) — downloads and locally caches remote media (`downloadFiles`), and resolves the local per-language media folder (`getLocalMediaFolder`) so previously downloaded audio/images work offline.
- **`NfcManager`** (`nfcmanager.h`) — singleton bridging Android NFC tag reads (via JNI from `MuseumActivity.java`) to a QML-visible `tagDetected(code)` signal, used to jump straight to an item by `code`.
- **`AndroidPermission`** (`androidpermission.h/.cpp`) — runtime camera permission check/request for QR scanning.
- **`QZXing`** — registered as a QML type for the QR scanner (`ScannerPage.qml`).

### Architecture: QML/JS data layer

App state lives in `main.qml` as a single `appData` property (`entities`, `maps`, `areas`, `items`, `dictionary`, `tours`, `tourItem`, `tourSteps`), rebuilt whenever the language changes via `carregarDados(lingua, passarPagina)`.

- **`ApiHandler.js`** — all Strapi communication and response shaping. `getData(lang, callback)` fetches (and SQLite-caches, via `QtQuick.LocalStorage`) the full nested payload for a language, then serves from cache on repeat calls. Separate `getEntities`/`getMaps`/`getAreas`/`getItems`/`getTours`/`getTourItems`/`getTourAreas`/`getDictionary`/`extractMediaUrls` functions flatten the nested Strapi response into flat arrays the QML views bind to. `resolveUrl(path, localPath)` decides whether to point at a locally-cached file or the live `baseUrl`. **`baseUrl` is a hardcoded LAN IP that must be updated per network/environment** (several commented alternatives are left in place for different networks — a real fix would make this configurable rather than edited-and-recommitted per deployment).
  - `buildTourSequence(tour, tourItems, tourAreas)` (added by `specs/005-tours-listagem-visita-guiada`) is the single normalization point that turns a tour's items/areas/intro audio into one ordered array of "steps" (`type: "intro" | "item" | "area"`) — the guided-visit sequence that `TourPage.qml` iterates over instead of a plain item list; `getAllTourSteps(dados, localPath)` pre-computes this for every tour (same pattern as `getAllTourItems`) and feeds `appData.tourSteps`.
  - `saveTourProgress`/`getTourProgress`/`clearTourProgress` persist per-device, per-tour visit progress in a `tour_progress` table inside the same `AppDB` SQLite database `openDb()` already opens for the catalog cache — used by `TourPage.qml` to offer "continue where you left off" on reopen.
- **`AnalyticsHandler.js`** — device analytics. Generates and persists a permanent per-device ID in local SQLite (`app_settings` table), POSTs events to `/api/analytics-events` (each payload stamped with `entidadeDocumentId: Api.ACTIVE_ENTITY_DOCUMENT_ID`, reusing `ApiHandler.js`'s constant via `.import "ApiHandler.js" as Api` rather than a third copy — same pattern `AssistantHandler.js` already uses for `baseUrl`), and falls back to a local `analytics_cache` table when the network request fails (for later resend). Note its `baseUrl` is a separate hardcoded constant from `ApiHandler.js`'s — keep them in sync when changing environments.
- **`AssistantHandler.js`** — talks to the backend's `POST /api/assistant/ask` (reuses `ApiHandler.js`'s `baseUrl`, no third copy). `askAssistant(...)` returns `{ answer, autoTranslated, onTopic, usedGeneralKnowledge }`; a client-side request timeout (`REQUEST_TIMEOUT_MS`) must stay strictly greater than the backend's own timeouts so the server always gets to return a structured error first.
- **`ChatIAPanel.qml`** — the assistant's chat UI (extracted from `HomePage.qml`'s `recChat` stub), instantiated from `HomePage.qml`. In-memory conversation only (never persisted). Shows the "Automatic translation" and "AI general-knowledge answer (outside the museum catalog)" indicators per message, and swaps its typing indicator to a "still thinking…" label on an elapsed-time heuristic (the backend can't signal mid-request when it takes the slower two-call knowledge-fallback path).
- QML pages (`WelcomePage.qml`, `HomePage.qml`, `Tours.qml`, `TourPage.qml`, `ScannerPage.qml`, `GlobalQrButton.qml`, `GlobaLButtonChatIA.qml`) are loaded/composed from `main.qml`, which also owns navigation state (`nextPage`) and language selection (`linguaEscolhida`, persisted as `linguaGuardada`).

### Networking note

`main.cpp` disables SSL peer verification globally (`QSslSocket::VerifyNone`) to avoid HTTPS download failures on Android — be aware of this when touching networking code; it means TLS cert validation is off for the whole app.
