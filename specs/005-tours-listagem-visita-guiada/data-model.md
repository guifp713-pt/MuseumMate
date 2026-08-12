# Phase 1 Data Model: Tours — Listagem e Visita Guiada

## Entidades de conteúdo (Strapi, já existentes ou criadas manualmente como pré-requisito)

### Tour (existente + 3 campos novos, criados manualmente no Strapi)

| Campo | Tipo | Novo? | Notas |
|---|---|---|---|
| `nameTour`, `timeTour`, `descriptionTour`, `imageTour` | — | não | já existentes |
| `items` | relation → Item (oneToMany) | não | já existente; ordem preservada tal como hoje |
| `isMainTour` | boolean, default `false` | **sim** | identifica a tour "museu completo"; no máximo uma `true` em simultâneo (não validado pelo sistema, ver Assumptions da spec) |
| `areas` | relation → Area (oneToMany) | **sim** | areas que podem ser mencionadas nesta tour |
| `audioTour` | media (files, audios), i18n | **sim** | áudio de introdução à tour |

### Area (existente, sem alterações de schema)

Campos relevantes já existentes e reutilizados sem alteração: `nameArea`, `subtitleArea`, `descriptionArea`, `imageArea`, `audioArea`, `documentId`. Este spec passa a **expor `documentId`** nas funções do cliente que já leem `Area` (`getAreas`), que hoje não o devolvem.

### Item (existente, sem alterações de schema)

Campo relevante já existente e reutilizado: a relação `area` (manyToOne, inversa de `Area.items`). Este spec passa a **popular e propagar** essa relação no ramo `tour.items` da query (hoje não populado ali).

## Populate chain (ApiHandler.js `fetchFromNetwork`)

Acrescentos à query existente (ver research.md §1):

```
&populate[tours][populate][isMainTour]=true          (escalar, não requer populate explícito — incluído por omissão)
&populate[tours][populate][audioTour]=true
&populate[tours][populate][areas][populate][imageArea]=true
&populate[tours][populate][areas][populate][audioArea]=true
&populate[tours][populate][items][populate][area]=true
```

## Entidades lógicas (apenas em runtime, não persistidas no Strapi)

### Passo de visita (`TourStep`)

Unidade produzida por `buildTourSequence()` a partir dos dados já carregados; nunca é gravada em Strapi.

| Campo | Tipo | Descrição |
|---|---|---|
| `type` | `"intro" \| "item" \| "area"` | discrimina o conteúdo do passo |
| `documentId` | string | do `Tour` (passo intro), do `Item` ou da `Area` conforme `type` |
| `title`, `description`, `imageUrl`, `audioUrl` | string | conteúdo a apresentar, extraído do item/area/tour subjacente |
| `code` | string \| null | apenas para `type: "item"` — usado pela deteção QR/NFC existente; `null` para `intro`/`area` |
| `stopNumber` | int \| null | posição na numeração "Paragem N" visível ao utilizador; `null` para `intro` (ver research.md §3) |

Construção: `buildTourSequence(tour, tourItems, tourAreas)` →
1. Se `tour.audioTour` definido, `steps[0] = {type:'intro', documentId: tour.documentId, audioUrl: tour.audioTour, ...}`.
2. Para cada item em `tourItems` (ordem preservada): se `item.areaDocumentId` for diferente da area do passo anterior **e** `item.areaDocumentId` estiver em `tourAreas`, inserir primeiro `{type:'area', documentId: area.documentId, ...}`; depois inserir `{type:'item', documentId: item.documentId, code: item.code, ...}`.
3. Atribuir `stopNumber` sequencialmente (1, 2, 3…) a todos os passos exceto o `intro`.

### Progresso de tour (`tour_progress`, tabela local SQLite em `AppDB`)

| Coluna | Tipo | Descrição |
|---|---|---|
| `tourDocumentId` | TEXT (chave primária) | tour a que este progresso pertence |
| `stepType` | TEXT | `"item"` ou `"area"` (nunca `"intro"` — concluir a intro já avança para o passo 1) |
| `stepDocumentId` | TEXT | identifica o passo dentro da sequência atual (ver research.md §5) |
| `updatedAt` | TEXT (ISO 8601) | apenas informativo/depuração |

Ciclo de vida:
- **Escrita**: ao fechar a `TourPage` a meio de uma visita (`back()` sem ter chegado ao último passo).
- **Leitura**: ao abrir uma tour, antes de construir o ecrã inicial.
- **Remoção**: ao escolher "começar do início" (FR-011) ou ao concluir a tour até ao último passo (FR-012).
- **Validação**: se `stepDocumentId` não corresponder a nenhum passo da sequência recém-construída, tratar como inexistente (FR-013) — reiniciar do início e limpar a linha.

## Diagrama de fluxo (alto nível)

```
Tours.qml (lista)
  └─ isMainTour === true → fixa no topo, estilo igual ao dos items em modo lista
  └─ seleciona tour → TourPage

TourPage.qml (abertura)
  ├─ getTourProgress(tour.documentId)
  │    ├─ encontrado e válido → diálogo: Continuar (passo guardado) | Começar do início
  │    └─ não encontrado/ inválido → segue para "Começar do início"
  └─ "Começar do início" → steps[0] (intro, se existir; senão o primeiro item/area)

Navegação (Guia e Lista)
  ├─ avançar/recuar → steps[currentIndex]
  ├─ modo lista → ListView.positionViewAtIndex(currentIndex)
  ├─ ao sair a meio → saveTourProgress(...)
  └─ ao concluir o último passo → clearTourProgress(...)
```
