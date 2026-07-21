# Contract: Assistant Ask Endpoint

New custom Strapi route — not a generated content-type CRUD endpoint. Lives at
`backend/app/src/api/assistant/` (routes/controllers/services), following the
same custom-route pattern already used by `analytics-event`'s
`01-custom-analytics-event.ts`.

## `POST /api/assistant/ask`

Public (`auth: false`, matching every other public read endpoint this app
already exposes — the assistant has no visitor authentication per FR-010).

### Request body

```json
{
  "message": "What time does the museum open?",
  "language": "en",
  "sessionId": "DEV_ABC123...",
  "history": [
    { "role": "visitor", "text": "Tell me about the Roman coins exhibit" },
    { "role": "assistant", "text": "The Roman coins exhibit is in Area B..." }
  ]
}
```

| Field | Type | Required | Constraints |
|---|---|---|---|
| `message` | string | yes | 1–2000 chars after trim; empty/whitespace-only → `400` |
| `language` | string | yes | one of `pt`, `en`, `es`, `fr`; anything else → `400` |
| `sessionId` | string | yes | the device/session id the mobile app already generates for other analytics events (see `AnalyticsHandler.js`) |
| `history` | array | no | each item `{ role: "visitor"\|"assistant", text: string }`; capped server-side at the last 20 turns to bound prompt size |

### Success response — `200`

```json
{
  "answer": "The museum is open from 10:00 to 18:00, Tuesday to Sunday.",
  "autoTranslated": false,
  "onTopic": true
}
```

| Field | Type | Notes |
|---|---|---|
| `answer` | string | Always present on `200` |
| `autoTranslated` | boolean | Drives the FR-015 "Automatic translation" indicator |
| `onTopic` | boolean | `false` on an on-domain-decline (FR-003) — `answer` is still populated with the polite decline text in this case |

### Error responses

| Status | When | Body |
|---|---|---|
| `400` | Missing/invalid `message`, `language`, or `sessionId` | `{ "error": "invalid_request", "message": "<detail>" }` |
| `502` | The AI provider call failed, errored, or the response couldn't be parsed into the expected structured shape | `{ "error": "assistant_unavailable" }` |
| `504` | The AI provider call exceeded the ~20s server-side timeout | `{ "error": "assistant_unavailable" }` |

The client (`AssistantHandler.js`) treats every non-`200` the same way: show the
"service unavailable" message (Edge Cases) and do not add a broken assistant
turn to the conversation. A network-level failure (`xhr.onerror`, no route to
host) is distinguished client-side from these and shows the "needs an internet
connection" message (FR-008) instead — the backend is not involved in that case.

### What the backend does on every call (not part of the wire contract, but load-bearing for FR-016)

1. Builds the system prompt from the current catalog for `language` (Research §3) plus the off-topic-refusal instruction (Research §4).
2. Calls the Gemini API with a structured-output schema of `{ answer, autoTranslated, onTopic }` (Research §5).
3. Writes one `analytics-event` row classified by the result (Research §8) — never containing `message` or `answer` text.
4. Returns the structured result as the HTTP response body above.
