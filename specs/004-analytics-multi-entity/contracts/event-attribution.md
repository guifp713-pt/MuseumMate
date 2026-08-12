# Contract: Event Attribution (`entidadeDocumentId`)

Both producers of `analytics-event` rows MUST stamp the same field, read from the
same source each stack already has (feature 002's `ACTIVE_ENTITY_DOCUMENT_ID`) —
never a locally declared copy (FR-002).

## Schema addition

`backend/app/src/api/analytics-event/content-types/analytics-event/schema.json`
gains one attribute, additive only:

```json
"entidadeDocumentId": {
  "type": "string"
}
```

## Producer 1 — Mobile app (`AnalyticsHandler.js`, `sendEvent`)

**Before**:
```js
var payload = {
    "data": {
        "eventType": eventType,
        "timestamp": timestamp,
        "sessionId": sessionId || "UNKNOWN_SESSION",
        "language": language || null,
        "itemId": itemId ? parseInt(itemId) : null,
        "tourId": tourId ? parseInt(tourId) : null,
        "success": success !== undefined ? success : true,
        "metadata": { "deviceId": getOrCreateDeviceId(), "source": "qml_application", "os": Qt.platform.os }
    }
}
```

**After** (top of file gains `.import "ApiHandler.js" as Api`; payload gains one field):
```js
var payload = {
    "data": {
        "eventType": eventType,
        "timestamp": timestamp,
        "sessionId": sessionId || "UNKNOWN_SESSION",
        "language": language || null,
        "itemId": itemId ? parseInt(itemId) : null,
        "tourId": tourId ? parseInt(tourId) : null,
        "success": success !== undefined ? success : true,
        "entidadeDocumentId": Api.ACTIVE_ENTITY_DOCUMENT_ID,
        "metadata": { "deviceId": getOrCreateDeviceId(), "source": "qml_application", "os": Qt.platform.os }
    }
}
```

Applies identically to the cached/retry path (`enviarEventoAgendado`) — it
re-sends whatever `payload` was already built by `sendEvent`, so no separate
change is needed there; a payload built before this feature shipped and only
flushed from the offline cache afterwards simply lacks the field (accepted by
the additive schema, FR-004) rather than being rejected.

## Producer 2 — Backend assistant (`assistant.ts`, `writeAnalytics`)

**Before**:
```ts
async function writeAnalytics(strapi, eventType, language, sessionId, success) {
  await strapi.documents('api::analytics-event.analytics-event').create({
    status: 'published',
    data: { eventType, timestamp: new Date().toISOString(), sessionId, language,
             itemId: null, tourId: null, success, metadata: { source: 'assistant' } },
  });
}
```

**After** (file gains `import { ACTIVE_ENTITY_DOCUMENT_ID } from '../../../config/museum';`):
```ts
async function writeAnalytics(strapi, eventType, language, sessionId, success) {
  await strapi.documents('api::analytics-event.analytics-event').create({
    status: 'published',
    data: { eventType, timestamp: new Date().toISOString(), sessionId, language,
             itemId: null, tourId: null, success,
             entidadeDocumentId: ACTIVE_ENTITY_DOCUMENT_ID,
             metadata: { source: 'assistant' } },
  });
}
```

No change to `writeAnalytics`'s call sites or signature — the value is read
from ambient config, not threaded through as a new parameter (research.md §3).

## Invariant

Every `analytics-event` row created after this feature ships carries a non-null
`entidadeDocumentId` equal to whichever museum's `ACTIVE_ENTITY_DOCUMENT_ID` was
configured (mobile-side or backend-side, respectively) at the moment the event
was recorded. A row missing it after rollout indicates a defect (FR-016), never
a legitimate state to design around.
