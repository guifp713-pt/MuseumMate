# Contract: Active Museum Configuration & Filtered Entity Queries

This isn't a new HTTP endpoint — it's the contract both stacks must follow so
they always resolve the same single `entidade` document.

## The constant

Both stacks MUST declare a constant named `ACTIVE_ENTITY_DOCUMENT_ID` holding
the Strapi `documentId` of the museum entity to serve:

- Backend: `backend/app/src/config/museum.ts`
  ```ts
  export const ACTIVE_ENTITY_DOCUMENT_ID = 'gqag59gr2pvu95qawb4dq1ol';
  ```
- Mobile: top of `TourAssistent-main/ApiHandler.js`
  ```js
  var ACTIVE_ENTITY_DOCUMENT_ID = "gqag59gr2pvu95qawb4dq1ol"
  ```

**Switching museums** = changing both values to the same new documentId, then
rebuilding/reinstalling the app and redeploying the backend. The two values
MUST always match; nothing in the system enforces this automatically (see
`research.md` §1) — it is an operator responsibility, documented here as the
single authoritative statement of the convention.

## Mobile → Strapi REST call (`ApiHandler.js`, `getData`)

**Before**:
```
GET {baseUrl}/api/entidades?locale={lang}&populate[...]=...
```

**After**:
```
GET {baseUrl}/api/entidades?filters[documentId][$eq]={ACTIVE_ENTITY_DOCUMENT_ID}&locale={lang}&populate[...]=...
```

- `response.data` MUST now contain either exactly 1 entity (match found) or 0
  (misconfiguration — no entity with that documentId, for that locale).
- On 0 entities: the caller (`main.qml`) MUST treat this as the "not found"
  state (`entityConfigError = true`), not proceed to build `appData` from an
  empty array.

## Backend → Strapi Document Service query (`assistant-catalog.ts`, `getCatalog`)

**Before**:
```ts
await strapi.documents('api::entidade.entidade').findMany({
  locale,
  status: 'published',
  populate: CATALOG_POPULATE,
});
```

**After**:
```ts
await strapi.documents('api::entidade.entidade').findMany({
  filters: { documentId: { $eq: ACTIVE_ENTITY_DOCUMENT_ID } },
  locale,
  status: 'published',
  populate: CATALOG_POPULATE,
});
```

Applies to both the base-locale (`pt`) fetch and the localized-overlay fetch
inside `getCatalog`.

- If the base-locale fetch returns 0 entities, `getCatalog` MUST throw a
  distinguishable error (e.g. a dedicated `EntityNotFoundError`) rather than
  building a `Catalog` with an empty `entities` array. The existing controller
  (`assistant.ts`) already wraps `getCatalog` in a `try/catch` that maps any
  thrown error to the existing `502 assistant_unavailable` response — no
  controller change is required, the new error type simply flows through the
  existing catch block.

## Invariant

At any point in time, both stacks configured with the same
`ACTIVE_ENTITY_DOCUMENT_ID` value MUST resolve to the same single `entidade`
document. There is no scenario in this feature where the mobile app and the
assistant answer from different entities while correctly configured.
