# Tasks: Tours — Listagem e Visita Guiada

**Input**: Design documents from `/specs/005-tours-listagem-visita-guiada/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md — todos presentes.

**Tests**: Sem tarefas de teste automatizado — este repositório não tem suite de testes configurada em nenhum dos dois stacks (ver constitution, "Development Workflow & Quality Gates"). A validação é manual, via `quickstart.md` (tarefa de Polish no fim).

**Organization**: Tarefas agrupadas por user story (spec.md), em ordem de prioridade (P1 → P2 → P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode correr em paralelo (ficheiro diferente, sem dependências)
- **[Story]**: A que user story pertence (US1..US5)

## Path Conventions

Projeto mobile Qt/QML existente — todos os caminhos são relativos a `TourAssistent-main/`. Nenhuma alteração de código no backend nesta feature (os 3 campos de schema são criados manualmente no Strapi, ver spec.md § Assumptions).

---

## Phase 1: Setup

**Purpose**: Garantir que os pré-requisitos de conteúdo existem antes de qualquer implementação.

- [ ] T001 Confirmar manualmente no Strapi (Content Manager) que a tour de teste tem `isMainTour`, `audioTour` e `areas` preenchidos conforme `quickstart.md` § Pré-requisitos, e que pelo menos uma area associada tem items dessa mesma area na relação `items` da tour.

**Checkpoint**: Dados de teste prontos; nenhuma alteração de build/dependências é necessária (feature usa apenas QML/JS já presentes no projeto).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Substituir a base de dados/lógica de sequência de "lista de items" por "lista de passos" (intro/item/area), sem alterar o comportamento visível da app. Nenhuma user story pode ser implementada antes disto.

**⚠️ CRITICAL**: Esta fase é um refactor de risco — o checkpoint final desta fase é "a app funciona exatamente como antes", não uma funcionalidade nova.

- [X] T002 Estender a query de populate em `TourAssistent-main/ApiHandler.js` (`fetchFromNetwork`) para incluir `tours.audioTour`, `tours.areas` (com `imageArea`/`audioArea`), e `tours.items.area`, conforme `data-model.md` § Populate chain.
- [X] T003 Estender `getAreas()` em `TourAssistent-main/ApiHandler.js` para devolver também `id`/`documentId` de cada area (hoje ausente).
- [X] T004 Estender `getTourItems()` em `TourAssistent-main/ApiHandler.js` para extrair e devolver `areaDocumentId` (a partir do `item.area` agora populado), preservando os campos já devolvidos.
- [X] T005 Adicionar `getTourAreas(dados, tourRef, localPath)` em `TourAssistent-main/ApiHandler.js`, espelhando `getTourItems()`, devolvendo `{documentId, nameArea, subtitleArea, descriptionArea, imageAreaUrl, audioArea}` por area da relação `tour.areas`.
- [X] T006 Implementado `buildTourSequence(tour, tourItems, tourAreas)` em `TourAssistent-main/ApiHandler.js` conforme `data-model.md`. *Nota de implementação*: também foi adicionada `getAllTourSteps()` (pré-calcula a sequência de todos os tours de uma vez, no mesmo padrão de `getAllTourItems()`), e `main.qml` passou a expor `appData.tourSteps`, para manter o padrão existente de um único ponto de normalização de dados (Constitution II) em vez de a `TourPage.qml` chamar `ApiHandler.js` diretamente.
- [X] T007 Refactor de `TourAssistent-main/TourPage.qml`: `tourInfoItem`/`currentItem`-sobre-items substituído por `steps` (lido de `appDataTourPage.tourSteps`) e `currentStep` computado a partir de `contadorParagens` (mantido como posição 1-indexed, agora sobre `steps`); todos os pontos que liam `currentItem`/`tourInfoItem` (ecrã Guia, delegate do modo lista, miniPlayer, botões anterior/próximo, `playCurrentAudio()`) foram atualizados para `currentStep`/`steps`; a deteção por código QR/NFC/manual passou a filtrar `type === 'item'`.
- [ ] T008 Validação manual de regressão (pendente — requer correr a app com dados reais do Strapi).

**Checkpoint**: Base de "passos" pronta e sem regressões — as user stories seguintes já podem ser implementadas.

---

## Phase 3: User Story 1 - Visita guiada sem esforço (Priority: P1) 🎯 MVP

**Goal**: Ao selecionar uma tour com áudio de introdução, a `TourPage` mostra e reproduz essa introdução antes de qualquer item, com o mesmo tipo de ecrã de um item.

**Independent Test**: Selecionar uma tour com `audioTour` definido e confirmar que a introdução aparece/toca antes do passo 1; selecionar uma tour sem `audioTour` e confirmar que começa direto no passo 1 (quickstart.md cenário 2).

### Implementation for User Story 1

- [X] T009 [US1] Exposto `audioTour` e `isMainTour` (via `resolveUrl`) em `getTours()` de `TourAssistent-main/ApiHandler.js`.
- [X] T010 [US1] `getAllTourSteps()` (T006) já passa o `tour` completo (incluindo `audioTour`) a `buildTourSequence()`, pelo que o passo `intro` é inserido automaticamente assim que `audioTour` está definido — sem necessidade de wiring adicional em `TourPage.qml`.
- [X] T011 [US1] O ecrã do modo Guia em `TourAssistent-main/TourPage.qml` já lê `currentStep.imageUrl/title/description/audioUrl` de forma genérica (T007), pelo que o passo `intro` é apresentado com o mesmo layout de um item sem ramo condicional extra; adicionado apenas o rótulo "Introdução" no cabeçalho (`txtParagemContador`).
- [X] T012 [US1] Adicionada `totalDisplaySteps` (conta só passos com `stopNumber`) e a barra/pontos de progresso (`recProgressBar`/`rowrecProgressBar`) passaram a usar `currentStep.stopNumber`/`totalDisplaySteps` em vez de `contadorParagens`/`valorEstaticoStop` — a intro fica com progresso 0 e sem ponto destacado.
- [X] T013 [US1] Comportamento já correto sem alterações adicionais: o botão "Próximo" incrementa `contadorParagens` sobre `steps` independentemente do tipo do passo atual, pelo que avança de "intro" (posição 1) para o passo 1 normalmente; "Anterior" já fica desativado na posição 1 (intro incluída).

**Checkpoint**: User Story 1 funcional e testável de forma independente.

---

## Phase 4: User Story 2 - Encontrar rapidamente a visita completa ao museu (Priority: P1)

**Goal**: A tour marcada `isMainTour` aparece sempre fixa no topo da listagem, destacada, e a listagem de tours usa o mesmo estilo visual da listagem de items em modo lista.

**Independent Test**: Com uma tour marcada `isMainTour` e outras normais, abrir a lista de tours e confirmar posição fixa + destaque + estilo consistente (quickstart.md cenário 1).

### Implementation for User Story 2

- [X] T014 [US2] Adicionada `orderedTours` em `TourAssistent-main/Tours.qml`: encontra a primeira tour `isMainTour === true` e move-a para o topo; sem nenhuma marcada, a ordem original é preservada.
- [X] T015 [US2] Delegate da `ListView` de tours redesenhado para o mesmo estilo horizontal (imagem 80×80 à esquerda, título+descrição à direita) da listagem de items em modo lista da `TourPage`; a tour `isMainTour` ganha borda dourada mais grossa e um selo "Visita completa ao museu". *Nota*: corrigido também um bug pré-existente (`appDatatour` com "t" minúsculo, causaria erro de referência ao mostrar o número de paragens).

**Checkpoint**: User Stories 1 e 2 funcionam de forma independente uma da outra.

---

## Phase 5: User Story 3 - Contexto de deslocação entre areas (Priority: P2)

**Goal**: Antes do primeiro item de cada area associada à tour, é apresentado um passo dedicado a essa area (imagem/áudio próprios), repetindo sempre que o percurso volta a essa area.

**Independent Test**: Tour com items de duas areas associadas — confirmar passo de area antes de cada mudança de area, e ausência de repetição entre items consecutivos da mesma area (quickstart.md cenário 3).

### Implementation for User Story 3

- [X] T016 [US3] `getAllTourSteps()` (T006) já chama `getTourAreas()` e passa o resultado a `buildTourSequence()` para todos os tours — os passos `area` são inseridos automaticamente sem wiring adicional em `TourPage.qml`.
- [X] T017 [US3] O ecrã do modo Guia já apresenta qualquer `currentStep` de forma genérica (T007/T011), pelo que o passo `area` é mostrado com o mesmo layout, usando `imageAreaUrl`/`nameArea`+`subtitleArea`+`descriptionArea`/`audioArea` (combinados em `buildTourSequence`).
- [X] T018 [US3] Cartão do modo lista (agora `ListView`, ver T024) mostra um selo "Area"/"Introdução" para passos que não são `item`, distinguindo-os visualmente do cartão de item normal.

**Checkpoint**: User Stories 1, 2 e 3 funcionam de forma independente.

---

## Phase 6: User Story 4 - Retomar uma visita interrompida (Priority: P2)

**Goal**: Fechar a `TourPage` a meio de uma visita guarda o passo atual; reabrir a mesma tour oferece continuar desse passo (com áudio automático) ou recomeçar.

**Independent Test**: Avançar até um passo intermédio, fechar, reabrir a mesma tour e confirmar o diálogo de escolha e o comportamento de cada opção; concluir uma tour e confirmar que não é oferecida a opção de continuar (quickstart.md cenário 6).

### Implementation for User Story 4

- [X] T019 [US4] Tabela `tour_progress` acrescentada dentro de `openDb()` em `TourAssistent-main/ApiHandler.js`, mais `saveTourProgress()`, `getTourProgress()` e `clearTourProgress()`.
- [X] T020 [US4] Diálogo modal `resumeDialogOverlay` criado em `TourAssistent-main/TourPage.qml`, no mesmo estilo dos overlays existentes (fundo escurecido + cartão branco centrado), com os dois botões.
- [X] T021 [US4] `Component.onCompleted` consulta `Api.getTourProgress(...)`; se o `stepDocumentId` corresponder a um passo de `steps`, mostra o diálogo; caso contrário limpa o progresso obsoleto (FR-013) e segue o fluxo normal.
- [X] T022 [US4] `resumeSavedProgress()`/`restartTourFromBeginning()` ligados aos botões do diálogo; ambos chamam `playCurrentAudio()` no fim (autoplay conforme Clarifications).
- [X] T023 [US4] Botão "x" (`closePage`) grava progresso via `Api.saveTourProgress(...)` quando o passo atual não é o último (e não é a intro); botão "Terminar" (`nextStop` no último passo) chama `Api.clearTourProgress(...)`.

**Checkpoint**: User Stories 1 a 4 funcionam de forma independente.

---

## Phase 7: User Story 5 - Acompanhar a visita sem se perder (Priority: P3)

**Goal**: O modo lista acompanha automaticamente o passo atual; os botões de navegação nunca cobrem texto longo no modo Guia.

**Independent Test**: Navegar numa tour longa em modo lista e confirmar que o passo atual está sempre visível sem scroll manual; abrir em modo Guia o passo com o texto mais longo do catálogo de teste e confirmar que os botões não o cobrem (quickstart.md cenários 4 e 5).

### Implementation for User Story 5

- [X] T024 [US5] `scrollAreaLista` convertido de `Flickable`+`Repeater` para `ListView` sobre `steps`; `onContadorParagensChanged` chama `positionViewAtIndex(contadorParagens - 1, ListView.Contain)` (via `Qt.callLater` para garantir que o `ListView` já tem o modelo aplicado).
- [X] T025 [US5] `scrollArea.anchors.bottomMargin` agora reserva `nextStop.height + 40` no modo Guia (antes só reservava para o `miniPlayer`), evitando a sobreposição do texto pelos botões Anterior/Próximo.

**Checkpoint**: Todas as 5 user stories funcionam de forma independente.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Validação final e sincronização da documentação.

- [ ] T026 [P] **Pendente — requer o utilizador**: executar manualmente todos os cenários de `specs/005-tours-listagem-visita-guiada/quickstart.md` em build Desktop e Android, depois de criar os 3 campos de schema no Strapi (`isMainTour`, `areas`, `audioTour`).
- [X] T027 [P] `CLAUDE.md` atualizado: bullet do content-type `tour` menciona os 3 campos novos; secção "Architecture: QML/JS data layer" descreve `buildTourSequence`/`getAllTourSteps`/`appData.tourSteps` e a tabela `tour_progress`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências.
- **Foundational (Phase 2)**: depende do Setup; **bloqueia todas as user stories**.
- **User Stories (Phase 3-7)**: todas dependem da Foundational.
- **Polish (Phase 8)**: depende de todas as user stories que se pretenda validar/documentar.

### User Story Dependencies

- **US2** (`Tours.qml`) é totalmente independente das restantes (ficheiro próprio) — pode ser feita em paralelo com a cadeia US1→US3→US4→US5.
- **US1, US3, US4, US5** editam todas `TourPage.qml` sobre a mesma base de `steps` — para evitar conflitos no mesmo ficheiro, seguem a ordem de prioridade da spec (P1 → P2 → P2 → P3): US1 antes de US3, US3 antes de US4, US4 antes de US5. Cada uma é, ainda assim, independentemente testável ao seu próprio checkpoint.

### Parallel Opportunities

- T003, T004, T005 (extensões de leitura em `ApiHandler.js`) podem ser feitas pela mesma pessoa em sequência rápida, mas não em paralelo por dois agentes (mesmo ficheiro).
- **US2** (T014-T015, em `Tours.qml`) pode avançar em paralelo com a cadeia **US1→US3→US4→US5** (em `TourPage.qml`), por serem ficheiros diferentes sem dependência mútua.
- T026 e T027 (Polish) são independentes entre si — podem correr em paralelo.

---

## Parallel Example: Após a Foundational

```bash
# Um developer segue a cadeia principal (mesmo ficheiro, ordem de prioridade):
Task: "US1 → US3 → US4 → US5 em TourAssistent-main/TourPage.qml"

# Outro developer, em paralelo, trata a listagem (ficheiro independente):
Task: "US2 em TourAssistent-main/Tours.qml"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (Setup) e Phase 2 (Foundational — refactor de risco, validar regressão em T008).
2. Completar Phase 3 (US1 — introdução em áudio).
3. **PARAR e VALIDAR**: cenário 2 do `quickstart.md`.
4. Demonstrável como MVP: a TourPage já não abre "a meio".

### Incremental Delivery

1. Setup + Foundational → base de passos pronta, sem regressões.
2. US1 → introdução em áudio → validar → demo.
3. US2 → listagem redesenhada + tour principal fixa → validar → demo (pode ter sido feito em paralelo com US1).
4. US3 → areas na sequência → validar → demo.
5. US4 → retomar progresso → validar → demo.
6. US5 → auto-scroll + correção de sobreposição → validar → demo.
7. Polish → validação completa do quickstart + atualização do CLAUDE.md.

---

## Notes

- Sem tarefas de teste automatizado (repositório sem suite configurada) — cada checkpoint é validado manualmente contra `quickstart.md`.
- [P] usado apenas onde os ficheiros são realmente diferentes e sem dependência — dado que 4 das 5 user stories partilham `TourPage.qml`, a maior parte das tarefas é sequencial por desenho, não por limitação artificial.
- Fazer commit após cada tarefa ou grupo lógico de tarefas.
- Parar em qualquer checkpoint para validar a story de forma independente antes de avançar.
