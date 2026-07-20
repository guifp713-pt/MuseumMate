# Quickstart: Validating the AI Museum Assistant

Manual validation guide — neither stack has an automated test suite yet
(Constitution: Development Workflow & Quality Gates), so this is the
end-to-end verification path before calling the feature done.

## Prerequisites

1. Backend running locally with a valid `entidade` populated with at least one
   tour, one area with items, and dictionary entries for at least two of the
   four supported languages (so both the "official translation exists" and
   "must AI-translate" paths in User Story 1 can be exercised).
2. A Google Gemini API key set as `GEMINI_API_KEY` in the backend's environment
   (see `backend/docker-compose.yml` / `.env` conventions already used for
   other secrets in this repo).
3. Mobile app pointed at that backend's `baseUrl` (see `ApiHandler.js` —
   update the active LAN IP as usual for this repo's current known limitation).

## Setup

```
cd backend/app
npm install            # picks up the new @google/genai dependency
npm run develop
```

Build/run the mobile app via Qt Creator (Desktop kit is fastest for manual
testing) against `AssistentTourPhone.pro`.

## Scenario 1 — Core Q&A across languages and the whole catalog (User Story 1, P1)

For each of PT, EN, ES, FR:

1. Set the app's active language to that language on the language-selection screen.
2. Open the HomePage, tap the chat button (bottom-left, gold-pulsing circle) to open the assistant panel.
3. Ask about an item or tour **you are not currently viewing**.
4. **Expect**: a text answer in the selected language, grounded in that catalog content, within ~10 seconds (SC-001).
5. Ask about content that has an official translation in the catalog for the active language.
6. **Expect**: no "Automatic translation" indicator on that reply (FR-005/SC-005).
7. Ask about content that only exists in Portuguese, with the active language set to EN/ES/FR.
8. **Expect**: the answer is translated, and the "Automatic translation" indicator is shown (FR-006/FR-015).

## Scenario 2 — Off-topic handling (User Story 2, P2)

1. Ask something with no connection to the museum (e.g. "What's the weather in Paris?").
2. **Expect**: a polite decline redirecting to museum topics, in the active language, and no attempt at a real answer (FR-003/SC-003).
3. Ask a mixed question ("What's the capital of France, and what time do you close?").
4. **Expect**: the museum-related part (closing time) is answered; the unrelated part is declined.

## Scenario 3 — Entry point, follow-ups, and reachability (User Story 3, P3)

1. From the HomePage, open the assistant and send a question; confirm you never left the HomePage flow.
2. Ask a follow-up that refers back to the previous answer ("how long does that one take?").
3. **Expect**: the assistant correctly resolves the reference using in-session history (FR-014).
4. Close the assistant panel (drag down or the "x"), then reopen it.
5. **Expect**: the prior messages are still shown (clarified reopen behavior).
6. Turn off the device's network connection, then try to send a question.
7. **Expect**: a clear "needs an internet connection" message within ~5 seconds (SC-006), not a silent hang.
8. With connectivity restored but the backend's `GEMINI_API_KEY` temporarily invalidated (or backend stopped), send a question.
9. **Expect**: a clear "service unavailable" message, and the app does not crash or hang (Edge Cases).

## Scenario 4 — Edge cases

1. Try to send an empty or whitespace-only message.
2. **Expect**: nothing is submitted; the visitor is prompted to type a question.
3. Ask about a topic that is museum-domain but genuinely absent from the catalog (e.g. an opening-hours question when no such content exists anywhere in the catalog).
4. **Expect**: the assistant says it doesn't have that information — it does not invent an answer (FR-012).
5. Mid-conversation, change the app's active language, then ask a new question.
6. **Expect**: the new answer uses the new language; earlier messages in the transcript are left as they were sent.

## Verifying analytics logging (FR-016) without inspecting message content

After running Scenarios 1–3, check the Strapi admin panel's `analytics-event`
collection (or the `analytics-dashboard` plugin) for new rows with
`eventType` of `assistant_question`, `assistant_decline`, and (if Scenario 3
step 8 was run) `assistant_error`. Confirm:

- Each row's `metadata` contains only `{ "source": "assistant" }` — never the
  visitor's question text or the assistant's answer text.
- `language` matches what was active when each message was sent.

## Done criteria

All eight numbered expectations above hold, across all four languages for
Scenario 1, and the analytics rows in the final check contain no message
content.
