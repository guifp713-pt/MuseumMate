# Tasks: Áudio — Barra de Progresso e Mini-Player

**Input**: Design documents from `/specs/006-audio-progresso-notificacao/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/audio-bridge-contract.md, quickstart.md — todos presentes.

**Tests**: Sem tarefas de teste automatizado — este repositório não tem suite de testes configurada em nenhum dos dois stacks (ver constitution, "Development Workflow & Quality Gates"). A validação é manual, via `quickstart.md` (tarefa de Polish no fim), e exige um dispositivo/emulador Android para as partes de notificação (US2/US3).

**Organization**: Tarefas agrupadas por user story (spec.md), em ordem de prioridade (P1 → P2 → P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode correr em paralelo (ficheiro diferente, sem dependências)
- **[Story]**: A que user story pertence (US1..US3)

## Path Conventions

Projeto mobile Qt/QML/Android existente — todos os caminhos são relativos a `TourAssistent-main/`. Nenhuma alteração de código no backend nesta feature (ver plan.md § Constitution Check).

---

## Phase 1: Setup

**Purpose**: Garantir que os dados de teste necessários existem antes de qualquer implementação.

- [ ] T001 Preparar/confirmar no Strapi uma tour de teste com pelo menos um passo (item ou area) **sem** áudio definido, além dos passos normais com áudio — necessário para validar FR-009b (quickstart.md § Pré-requisitos, ponto 2).

**Checkpoint**: Dados de teste prontos; nenhuma alteração de build/dependências é necessária (feature usa apenas QML/C++/Java já presentes no projeto).

---

## Phase 2: Foundational

Não há pré-requisito bloqueador partilhado entre as três user stories desta feature — cada uma corrige uma causa-raiz distinta e independente (ver research.md), embora todas toquem parcialmente os mesmos três ficheiros (`AudioBridge.h/.cpp`, `TourAudioService.java`, `TourPage.qml`). Por isso não há tarefas nesta fase; a ordem de implementação segue apenas a prioridade da spec (P1 → P2 → P3) para evitar conflitos de edição sequencial no mesmo ficheiro.

---

## Phase 3: User Story 1 - Avançar ou recuar o áudio arrastando a barra de progresso (Priority: P1) 🎯 MVP

**Goal**: Arrastar/tocar na barra de progresso salta a reprodução para o ponto indicado, em modo Guia, modo lista e notificação — hoje não faz nada em nenhum dos três.

**Independent Test**: Reproduzir um áudio, arrastar a bola da barra de progresso em modo Guia, modo lista e (com a app em segundo plano) na notificação, confirmando em cada caso que a reprodução salta para o novo ponto (quickstart.md cenário 1).

### Implementation for User Story 1

- [X] T002 [US1] Corrigidas as 4 chamadas `AudioBridge.seek(newPos)` → `AudioBridge.seekTo(Math.round(newPos))` em `TourAssistent-main/TourPage.qml` (modo Guia + mini-player em modo lista). **Bug adicional encontrado e corrigido**: no mini-player, o `MouseArea` de arrastar chamava uma função `updateMiniAudioPosition()` que nunca existia — a função definida tinha outro nome (`updateAudioPosition`) e lia as variáveis erradas (`ballProgressAudioItem`/`progressBarBackgroundItem`, do modo Guia). Renomeada para `updateMiniAudioPosition()` e corrigida para usar `miniProgressBall`/`miniProgressBg`, o par de elementos correto do mini-player.
- [X] T003 [US1] `seekToPosition(int msec)` em `TourAssistent-main/android/.../TourAudioService.java` passou a chamar `player.start()` + `updateForegroundNotification(true)` + reiniciar o `progressRunnable` quando o player não está a tocar (FR-004a), cobrindo tanto `AudioBridge.seekTo` (app) como `MediaSessionCompat.Callback.onSeekTo` (slider do sistema/notificação), que já chamava este mesmo método.
- [X] T004 [US1] Confirmado por leitura de código: `AudioBridge::seekTo` (C++) já encaminhava corretamente para `seekToPosition` via JNI antes desta feature; `root.fakePosition`/`root.fakeDuration` já refletem `audioPositionChanged`. Validação em dispositivo real fica a cargo de T013.

**Checkpoint**: User Story 1 funcional e testável de forma independente (quickstart.md cenário 1).

---

## Phase 4: User Story 2 - Avançar ou recuar de passo diretamente pela notificação (Priority: P2)

**Goal**: Next/previous na notificação — já implementados mecanicamente — deixam de derrubar todo o serviço/notificação quando o passo de destino não tem áudio, e retomam a reprodução automaticamente se estava em pausa.

**Independent Test**: Com a app em segundo plano, tocar em "próximo"/"anterior" na notificação, incluindo até um passo sem áudio (preparado em T001), confirmando que a navegação muda de passo sem nunca fazer a notificação desaparecer (quickstart.md cenário 2).

### Implementation for User Story 2

- [X] T005 [US2] `handleAction(ACTION_NEXT/ACTION_PREVIOUS)` em `TourAudioService.java` passa a verificar se o URL do novo `currentIndex` é vazio; se vazio, chama o novo método `silenceCurrentStep()` (pausa o player existente sem o libertar, atualiza a notificação) em vez de `playAudio("")`, evitando o crash que caía no `catch` → `ACTION_STOP` e derrubava o serviço inteiro (FR-009b). `nativeTrackChanged` continua a ser chamado em ambos os casos, com `""` quando não há áudio. **Bug adicional encontrado e corrigido nesta mesma tarefa**: `setServicePlaylist` (T009) filtrava URLs vazias da lista, o que desalinhava `currentIndex` de tudo o resto sempre que havia um passo sem áudio — sem essa correção, o guard desta tarefa nunca seria alcançado.
- [X] T006 [US2] `onCurrentTrackChanged(index, url)` em `TourAssistent-main/TourPage.qml` só atribui `isAudioPlaying = true` quando `url` não é vazio, para o passo silencioso não mostrar a animação de "a tocar".
- [ ] T007 [US2] Validar manualmente em dispositivo real que, nos limites da sequência (primeiro/último passo), "anterior"/"próximo" na notificação continuam inertes (sem erro, sem dar a volta) após as alterações de T005 — comportamento já implementado em `handleAction`, apenas confirmar que não regride.

**Checkpoint**: User Stories 1 e 2 funcionam de forma independente uma da outra (quickstart.md cenários 1 e 2).

---

## Phase 5: User Story 3 - Reconhecer o que está a ouvir sem abrir a aplicação (Priority: P3)

**Goal**: A notificação mostra capa, título do passo atual e nome da tour, em vez de "Museum Mate" + texto genérico.

**Independent Test**: Com a app em segundo plano a reproduzir um passo, consultar a notificação e confirmar que a capa/título/tour correspondem ao mesmo passo mostrado no mini-player em modo lista dentro da app; repetir após mudar de passo (quickstart.md cenário 3).

### Implementation for User Story 3

- [X] T008 [US3] `AudioBridge::setPlaylist` (C++) estendido em `AudioBridge.h`/`AudioBridge.cpp` para `setPlaylist(urls, currentIndex, titles = {}, covers = {}, tourName = "")`, com os 3 novos parâmetros por omissão (as 2 chamadas isoladas de item avulso via QR/NFC continuam a passar só `urls`/`currentIndex`, sem alteração). `titles`/`covers` encaminhados para Java com o mesmo padrão JNI de `urls` (helper `toJavaStringArray` local); `tourName` como `jstring` simples.
- [X] T009 [US3] `setServicePlaylist(...)` em `TourAudioService.java` estendido para receber `String[] titles`, `String[] covers`, `String tourName`, guardados em `playlistTitles`/`playlistCovers`/`playlistTourName` (campos estáticos paralelos a `playlist`/`currentIndex`, limpos a cada nova chamada). **Correção crítica incluída**: a versão anterior filtrava URLs vazias da lista (`if (!url.isEmpty()) playlist.add(url)`), o que desalinhava `currentIndex` de `titles`/`covers` e do próprio índice usado pela app sempre que havia um passo sem áudio antes do passo atual — agora todas as entradas (incluindo `""`) são preservadas, mantendo o alinhamento de índice.
- [X] T010 [US3] `playCurrentAudio()` em `TourAssistent-main/TourPage.qml` passa a construir também `titles`/`covers` (a partir de `steps[i].title`/`steps[i].imageUrl`) e a ler `tourInfo.nameTour`, chamando `AudioBridge.setPlaylist(urls, contadorParagens - 1, titles, covers, tourName)`.
- [X] T011 [US3] `createNotification(...)` em `TourAudioService.java` usa `titles[currentIndex]` como título e `tourName` como texto secundário (com fallback "Museum Mate" quando vazios, via novo helper `safeGet`). Capa carregada em bitmap (`setLargeIcon`) numa thread de fundo nova (`requestCoverLoad`), com cache por índice (`cachedCoverBitmap`/`cachedCoverIndex`, limpa a cada `setServicePlaylist`): `BitmapFactory.decodeFile` para caminhos locais, `HttpURLConnection`+`BitmapFactory.decodeStream` como fallback para URLs remotas; falha a carregar não bloqueia nem impede a atualização do título/texto — a notificação é reconstruída (via `updateForegroundNotification`) só quando o bitmap chega e o passo ainda é o atual.
- [ ] T012 [US3] Validar manualmente em dispositivo real que passos do tipo `intro`/`area` (não só `item`) mostram corretamente o seu próprio título/capa na notificação — por construção já vêm genericamente de `steps[i].title`/`steps[i].imageUrl` (T010), sem lógica condicional extra; falta só a confirmação em runtime.
- [X] T016 [US3] Adicionado `.setContentIntent(...)` em `createNotification(...)` (`TourAudioService.java`) — `PendingIntent` para `MuseumActivity` (`FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_REORDER_TO_FRONT`), para tocar no corpo da notificação reabrir/trazer a app para primeiro plano (FR-015 — pedido pelo utilizador após a primeira ronda de implementação, não coberto pela versão inicial da tarefa T011).
- [X] T017 [US3] Bola/barra de progresso na notificação (FR-016) — resolvido à terceira tentativa, após dois testes reais no Galaxy A14 (Android 13+): (1ª) `builder.setProgress(...)` — sem efeito, é ignorado quando combinado com `MediaStyle`; (2ª) `DecoratedMediaCustomViewStyle` + `RemoteViews` próprio — também sem efeito, o Android 13+ descarta vistas personalizadas em notificações de media; (3ª, **a que funciona**) novo método `updateMediaMetadata()` que publica `MediaMetadataCompat` na `MediaSession` com `METADATA_KEY_DURATION` (o requisito em falta — `setMetadata` nunca era chamado em lado nenhum), mais título, nome da tour e capa (`METADATA_KEY_ALBUM_ART`), chamado a partir de `updateForegroundNotification()`. O sistema passa a desenhar a bola **arrastável**, já ligada a `onSeekTo` → `seekToPosition`. Removidos o `notification_progress.xml`, o `DecoratedMediaCustomViewStyle` e o contador `notificationProgressTick` (a notificação já não precisa de ser reconstruída periodicamente). Ver research.md §6.3.
- [X] T018 [US3] **Bug encontrado no mesmo teste real**: a capa nunca aparecia porque `requestCoverLoad` (T011) passava o caminho local diretamente a `BitmapFactory.decodeFile`, mas `FileHelper::getLocalMediaFolder` (C++) devolve os caminhos locais como URI `file://...` (não um caminho de sistema de ficheiros simples) — `decodeFile` falha silenciosamente com esse prefixo. Corrigido removendo o prefixo `file://` (via `Uri.parse(...).getPath()`) antes de `decodeFile`, apenas para caminhos locais (URLs remotas `http(s)://` não são afetadas) (ver research.md §6.2). **Validado pelo utilizador**: a capa passou a aparecer na notificação.
- [X] T019 [US3] Layout da notificação: confirmado com o utilizador que **não** é possível replicar o mini-player da app (imagem à esquerda, informação à direita) mantendo a bola arrastável — em Android 13+ o layout de notificações de media é imposto pelo sistema, e é precisamente por o sistema o desenhar que a bola pode ser arrastável. O utilizador escolheu a bola funcional em detrimento do layout (FR-017); nenhuma alteração de código necessária além de T017.

**Checkpoint**: As três user stories funcionam de forma independente (quickstart.md completo).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validação final e sincronização da documentação.

- [ ] T013 [P] **Pendente — requer o utilizador**: executar manualmente todos os cenários de `specs/006-audio-progresso-notificacao/quickstart.md` num dispositivo/emulador Android real.
- [X] T014 [P] `TourAssistent-main/guiaLayout` atualizado: marcados `[x]` os 3 itens desta spec, com nota "(spec 006)".
- [X] T015 [P] `CLAUDE.md` atualizado: secção "Architecture: C++ bridges exposed to QML" descreve a assinatura estendida de `setPlaylist` (metadados por omissão), a preservação de URLs vazias em `TourAudioService` e o novo tratamento de passos sem áudio em `handleAction`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências.
- **Foundational (Phase 2)**: sem tarefas — nada bloqueia as user stories além do Setup.
- **User Stories (Phase 3-5)**: todas podem começar após o Setup; seguem a ordem de prioridade da spec (P1 → P2 → P3) para evitar edições concorrentes aos mesmos ficheiros (`TourAudioService.java` é tocado pelas três).
- **Polish (Phase 6)**: depende das três user stories estarem implementadas.

### User Story Dependencies

- **US1**: Independente — só toca `TourPage.qml` (chamadas de seek) e `seekToPosition` em `TourAudioService.java`.
- **US2**: Independente de US1 — toca `handleAction(ACTION_NEXT/PREVIOUS)` em `TourAudioService.java` (método diferente do tocado por US1) e `onCurrentTrackChanged` em `TourPage.qml`.
- **US3**: Independente de US1/US2 nos requisitos, mas partilha `TourAudioService.java` (`setServicePlaylist`, `createNotification`) e `TourPage.qml` (`playCurrentAudio`) — implementar depois das outras duas evita conflitos de edição sequencial no mesmo ficheiro, não por dependência funcional real.

### Parallel Opportunities

- T002 (QML) e T003 (Java) dentro de US1 podem ser feitos em paralelo por serem ficheiros diferentes, mas dependem um do outro para o teste end-to-end (T004) fazer sentido.
- T013, T014, T015 (Polish) são independentes entre si — podem correr em paralelo.
- Não há paralelismo real entre user stories diferentes: todas tocam `TourAudioService.java`, pelo que a implementação sequencial por prioridade é a mais segura para um único agente/dev.

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (Setup).
2. Completar Phase 3 (US1 — seek funcional nos 3 sítios).
3. **PARAR e VALIDAR**: cenário 1 do `quickstart.md`.
4. Demonstrável como MVP: a barra de progresso deixa de ser decorativa.

### Incremental Delivery

1. Setup → dados de teste prontos (incl. passo sem áudio).
2. US1 → seek funcional → validar → demo.
3. US2 → next/previous pela notificação sem derrubar o serviço → validar → demo.
4. US3 → conteúdo rico da notificação → validar → demo.
5. Polish → validação completa do quickstart + atualização de `guiaLayout`/`CLAUDE.md`.

---

## Notes

- Sem tarefas de teste automatizado (repositório sem suite configurada) — cada checkpoint é validado manualmente contra `quickstart.md`, com especial atenção a exigir um dispositivo/emulador Android real para US2/US3 (a notificação não existe em Desktop).
- Fazer commit após cada tarefa ou grupo lógico de tarefas.
- Parar em qualquer checkpoint para validar a story de forma independente antes de avançar.
