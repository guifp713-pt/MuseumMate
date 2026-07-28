# Phase 1 Data Model: Assistant General-Knowledge Fallback

> **Pivot note (2026-07-27):** the second step is now a plain general-knowledge
> model call (no Google Search grounding — see `research.md §1/§2`), so the
> "Web Search Call Result" below became a "Knowledge Call Result", and the
> web-named fields were renamed. This file reflects the **shipped** names.

This feature extends existing entities from feature 001 (`AI Museum Assistant`) and feature 002 (`Active Museum Entity Selection`); it introduces no new Strapi content type.

## Question Classification (internal, per-request — not persisted)

Produced by the primary `assistant-ai.ts` call (extended, not replaced) for every request.

| Field | Type | Notes |
|---|---|---|
| `answer` | string | Unchanged from feature 001 — the catalog-grounded answer, the polite off-topic decline, or the "I don't have that information" text, depending on the other flags. |
| `autoTranslated` | boolean | Unchanged from feature 001 (FR-005/FR-006 of `001-ai-museum-assistant`). |
| `onTopic` | boolean | Unchanged field name; underlying prompt definition reworded per Clarifications session 2026-07-27 — false only when the question has no plausible connection to the museum. |
| `catalogSufficient` | boolean | **New.** True when `answer` is fully grounded in catalog content; false when the question is on-topic but the catalog had nothing relevant (the case that used to always end in "I don't have that information" and now becomes a general-knowledge-fallback candidate). Meaningless when `onTopic` is false. |
| `searchTopic` | string | **New.** Short (≈≤8 words) restricted topic phrase, populated only when `onTopic && !catalogSufficient`; empty string otherwise. Focuses the fallback call's scoping instruction (research.md §4/§5). Never the visitor's raw message text. |

## Knowledge Call Result (internal, per-request — not persisted)

Produced by the new `assistant-ai.ts` function (`answerFromKnowledge`), only invoked when Question Classification yields `onTopic && !catalogSufficient` and the Fallback Configuration (below) is enabled.

| Field | Type | Notes |
|---|---|---|
| `answer` | string | The general-knowledge answer text, already in the visitor's active language; present only when `confident` is true. |
| `confident` | boolean | False when the model is not confident enough to give a specific, reliable answer (FR-009) — in that case the controller keeps the primary call's "I don't have that information" text instead. |

This result is transient: the controller consumes it to build the final `AssistantAskResponse` and to decide the analytics event outcome, then discards it. No answer text is stored anywhere.

## Assistant Message (extended — client-side only, per feature 001's in-memory model)

`ChatIAPanel.qml`'s `messagesModel` gains one column alongside the existing `autoTranslated`:

| Field | Type | Notes |
|---|---|---|
| `usedGeneralKnowledge` | boolean | **New.** Drives the new general-knowledge indicator (FR-007). Defaults to `false` for the visitor's own messages and the local welcome message, exactly like `autoTranslated` does today. |

Still in-memory only; still never written to `QtQuick.LocalStorage` (feature 001, FR-009 — unaffected by this feature).

## Fallback Configuration (new, backend-only)

A single exported constant, following the same pattern as feature 002's `ACTIVE_ENTITY_DOCUMENT_ID`:

| Constant | Location | Value | Notes |
|---|---|---|---|
| `KNOWLEDGE_FALLBACK_ENABLED` | `backend/app/src/config/assistant.ts` (new file) | `true` | FR-011's central on/off switch. No mobile-side counterpart — see research.md §8. |

## AssistantAskResponse (extended contract)

The existing custom-action response body (feature 001, `contracts/assistant-api.md`) gains one additive field:

| Field | Type | Notes |
|---|---|---|
| `answer` | string | Unchanged. |
| `autoTranslated` | boolean | Unchanged. |
| `onTopic` | boolean | Unchanged in shape; classification boundary behavior changed per Clarifications (spec.md). |
| `usedGeneralKnowledge` | boolean | **New.** True only when the final answer came from the general-knowledge fallback call and the model was confident. `AssistantHandler.js` reads it defensively (`data.usedGeneralKnowledge === true`), so an old client build simply ignores it — no breaking change (NFR-3.4). |

## AnalyticsEvent (schema.json — additive enum extension)

`backend/app/src/api/analytics-event/content-types/analytics-event/schema.json`'s `eventType` enum gains one value:

```
"assistant_knowledge_fallback"
```

Written instead of `assistant_question` for any interaction that reaches the general-knowledge-fallback branch (research.md §9); `success` reflects the knowledge call's `confident` flag. No schema field is removed or repurposed — existing `assistant_question`/`assistant_decline`/`assistant_error` rows and their meaning are untouched.

## Relationships / flow summary

```
visitor question
   │
   ▼
Question Classification (call 1, extended existing structured call)
   │
   ├─ onTopic = false ─────────────────────────────► decline (unchanged, FR-004/FR-012)
   │
   ├─ onTopic = true, catalogSufficient = true ─────► catalog answer (unchanged, FR-001)
   │
   └─ onTopic = true, catalogSufficient = false
          │
          ├─ KNOWLEDGE_FALLBACK_ENABLED = false ────► "I don't have that information" (unchanged
          │                                            behavior vs. pre-feature; no analytics change)
          │
          └─ KNOWLEDGE_FALLBACK_ENABLED = true
                 │
                 ▼
             Knowledge Call Result (call 2, answerFromKnowledge)
                 │
                 ├─ confident = true  ────────────────► answer + usedGeneralKnowledge=true
                 │                                      + assistant_knowledge_fallback (success=true)
                 │
                 └─ confident = false / error/timeout ► "I don't have that information"
                                                          + assistant_knowledge_fallback (success=false)
```
