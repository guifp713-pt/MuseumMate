/**
 * Single source of truth (backend side) for whether the assistant's
 * general-knowledge fallback (specs/003-assistant-web-fallback) is active.
 *
 * When a question is on-topic for the museum but the catalog has nothing
 * relevant, this switch decides whether the assistant is allowed to attempt a
 * second, general-knowledge answer from the model itself (see
 * `answerFromKnowledge` in assistant-ai.ts) — the catalog always stays the
 * authoritative source and wins any conflict. With this off, the assistant
 * behaves exactly as feature 001 did: it simply says it doesn't have that
 * information.
 *
 * Backend-only: the mobile app never decides whether the fallback runs, it only
 * ever renders whatever `usedGeneralKnowledge` flag the backend's response
 * already carries, so no mirrored mobile constant is needed (see research.md §8).
 *
 * NOTE (why this is a plain model call, not Google Search grounding): the
 * original design used Gemini's Google Search grounding tool, but that requires
 * an active billing account on the API key — without it every grounded call
 * returns 429 RESOURCE_EXHAUSTED. This deployment deliberately avoids billing
 * (academic project), so the fallback answers from the model's own trained
 * knowledge instead, accepting the hallucination risk in exchange for not
 * blocking answers behind grounding quota (see research.md §1/§2). Set back to
 * false to hard-disable the fallback entirely.
 */
export const KNOWLEDGE_FALLBACK_ENABLED = true;
