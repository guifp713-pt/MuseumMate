# Contract: Dashboard Data Queries (Museum-Scoped)

Queries 1, 2 and 4 (Content API, `auth: false`) are issued from `HomePage.jsx` via the local
`fetchContentApi(path)` helper — plain `fetch()` against `window.strapi.backendURL`. Query 3
(the plugin's own admin route) is issued via Strapi's `useFetchClient()`. Neither hardcodes a
host (research.md §6) — but they are **not interchangeable**: `useFetchClient` always attaches
the admin session's JWT, which the Content API routes reject with `401` (caught during manual
testing, see research.md §6's Update note). Every path below is relative to wherever the
Strapi backend is actually served from, either way.

## 1. Events (`useAnalytics`)

**Before**:
```
GET http://localhost:1337/api/analytics-events?publicationState=preview&pagination[page]={n}&pagination[pageSize]=100&sort=id:desc
```

**After**:
```
GET /api/analytics-events?publicationState=preview&pagination[page]={n}&pagination[pageSize]=100&sort=id:desc&filters[entidadeDocumentId][$eq]={museuAtivo.documentId}
```

- Paging loop (`do { ... } while (paginaAtual <= totalDePaginas)`) is unchanged —
  only the filter is added; `meta.pagination.pageCount` now reflects the
  selected museum's own event count, which is smaller than the global count
  (this is what keeps SC-005 true: adding a second museum's events does not
  slow down reading the first museum's dashboard).
- Re-fetches whenever `museuAtivo` changes, exactly like it already re-fetches
  whenever `periodoAtivo`/`dataLimiteISO` change (`useEffect` dependency array
  gains `museuAtivo.documentId`).
- The 10-second polling interval (`isBackgroundRefreshing`) is unchanged; each
  poll re-issues the same museum-scoped request (FR-015).

## 2. Item names (`carregarNomesDoStrapi`)

**Before**:
```
GET http://localhost:1337/api/items?pagination[pageSize]=100
```

**After** (single page, per-museum catalogues are small — but see pagination
note below):
```
GET /api/items?filters[area][map][entidade][documentId][$eq]={museuAtivo.documentId}&pagination[pageSize]=100&fields[0]=nameItem
```

- Loops over `pagination[page]` the same way `useAnalytics` already does,
  driven by `meta.pagination.pageCount`, instead of assuming one page is
  always enough (research.md §5) — this is the actual fix for today's
  incomplete-names bug, with the entity filter as the scoping half of FR-009.
- Re-fetches whenever `museuAtivo` changes.
- `fields[0]=nameItem` narrows the response to just what the lookup needs
  (Constitution Principle III) — `id` is always returned by Strapi regardless.

## 3. Active museum (new — for FR-017's default selection)

```
GET /analytics-dashboard/active-entity
```

- New route, `type: 'admin'`, added to the plugin's own
  `server/src/routes/admin/index.js` (currently `routes: []`).
- Response: `{ documentId: string }` — the backend's current
  `ACTIVE_ENTITY_DOCUMENT_ID` (`config/museum.ts`), read at request time (no
  caching needed; this value only changes on a backend redeploy).
- Called once, on `HomePage.jsx` mount, to seed `museuAtivo` before the
  administrator makes any explicit selection.
- Auth: implicit via the admin session (`useFetchClient` carries it
  automatically) — no separate token handling needed. This is the one call of
  the four that genuinely needs `useFetchClient`'s admin JWT.

## 4. Museum selector list

```
GET /api/entidades?locale=pt&fields[0]=nameEntity&fields[1]=documentId
```

- Fetched once, alongside query 3, on mount.
- Populates the selector's options (`{ documentId, nameEntity }` per museum).
- Not filtered by anything — every museum is listed (Assumptions: no
  per-museum access control in this feature).

## Removed: language-stats (FR-010)

```
GET /analytics-events/language-stats
```

is deleted — the controller method (`getLanguageStats`) and its route file
(`analytics-event/routes/01-custom-analytics-event.ts`) are removed. Any
request to this path after this feature ships returns Strapi's normal 404,
same as any other unregistered route.
