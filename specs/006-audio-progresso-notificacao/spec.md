# Feature Specification: Áudio — Barra de Progresso e Mini-Player

**Feature Branch**: `006-audio-progresso-notificacao`

**Created**: 2026-07-29

**Status**: Draft

**Input**: User description: "Spec 006 — Áudio: barra de progresso e mini-player (app + notificação). Âmbito: (1) a ballProgressAudioItem (bola de arrastar na barra de progresso do áudio) não é funcional em nenhum dos 3 sítios onde existe — modo Guia, modo lista, e mini-player da notificação em tempo real — deve permitir controlar (seek) o áudio nos 3; (2) a notificação/MediaSession Android deve permitir next (próximo) e previous (anterior) além de play/pause já existentes; (3) o mini-player da notificação em tempo real deve mostrar o mesmo conteúdo que o mini-player dentro da app em modo lista (TourPage.qml) — capa + título do item/passo + nome da tour — em vez de apenas "Museum Mate" + 3 botões."

## Context

Este é o segundo de dois specs combinados com o utilizador para o conjunto de "Melhorias finais do Sistema" (o primeiro, spec 005, já está concluído e validado). Cobre exclusivamente o controlo e a apresentação do áudio durante uma visita guiada: a barra de progresso (arrastar/tocar para avançar a posição do áudio) e o mini-player que aparece na notificação em tempo real quando a aplicação está em segundo plano no Android. Não inclui alterações ao dashboard de analytics nem a outras páginas da app (tratado em specs seguintes fora deste âmbito).

## Clarifications

### Session 2026-07-29

- Q: Ao arrastar/tocar na barra de progresso ou usar next/previous pela notificação enquanto o áudio está em pausa, o sistema deve retomar automaticamente a reprodução na nova posição/passo, ou manter-se em pausa? → A: Retoma automaticamente a reprodução na nova posição/passo, mesmo que estivesse em pausa antes da ação.
- Q: Quando o next/previous pela notificação leva a um passo (item ou area) sem áudio associado, o que deve acontecer? → A: Fica nesse passo, em silêncio — mesmo comportamento já existente quando se navega manualmente dentro da app para um passo sem áudio (spec 005), sem saltar automaticamente para o próximo passo com áudio.

### Session 2026-07-29 (revisão pós-implementação)

- Q: A app tem `minSdkVersion` 23; o scrubber arrastável nativo do Android só é desenhado pelo próprio sistema a partir do Android 13 (API 33) — não é possível construir uma barra arrastável dentro de uma notificação personalizada em nenhuma versão do Android. Como deve ser tratada a barra de progresso na notificação nos aparelhos anteriores ao Android 13? → A: Mostrar uma barra de progresso visual (não arrastável, `NotificationCompat.setProgress`) em todas as versões do Android; nos aparelhos com Android 13+, o sistema substitui-a automaticamente pelo scrubber arrastável nativo, sem trabalho adicional. *(Nota pós-teste: a via `setProgress` revelou-se inviável — ver a clarificação seguinte.)*

### Session 2026-07-29 (revisão pós-teste em dispositivo real)

Contexto: testado num Samsung Galaxy A14 (SM-A146P, Android 13+). A capa passou a aparecer, mas nenhuma barra/bola de progresso era desenhada. Investigação revelou que (a) `setProgress()` é ignorado pelo Android quando combinado com um estilo de notificação de media, e (b) em Android 13+ o sistema descarta layouts personalizados em notificações de media, impondo o seu próprio a partir da `MediaSession`. A bola arrastável só é obtenível deixando o sistema desenhar a notificação — o que torna mutuamente exclusivos o controlo do layout e a existência de uma bola arrastável.

- Q: O mini-player da notificação deve replicar o layout do mini-player da app (imagem à esquerda, informação à direita) — sabendo que isso implica uma barra apenas visual, sem controlo do áudio — ou deve ter a bola arrastável funcional, aceitando o layout imposto pelo sistema? → A: Bola arrastável funcional, com o layout do sistema. O controlo real do áudio pela notificação (objetivo original do `guiaLayout`) tem prioridade sobre a disposição visual dos elementos.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Avançar ou recuar o áudio arrastando a barra de progresso (Priority: P1)

Como visitante a ouvir o áudio de um passo da visita, quero poder arrastar ou tocar na barra de progresso para saltar para outro ponto do áudio, tal como já consigo fazer em qualquer leitor de áudio comum.

**Why this priority**: É a funcionalidade central pedida e atualmente não funciona em nenhum dos três sítios onde é apresentada — sem isto, a bola de progresso é apenas decorativa e engana o visitante.

**Independent Test**: Reproduzir o áudio de um item em modo Guia, arrastar a bola da barra de progresso para um ponto diferente e confirmar que a reprodução salta para esse ponto; repetir o mesmo teste em modo lista e a partir da notificação em tempo real com a aplicação em segundo plano.

**Acceptance Scenarios**:

1. **Given** um áudio a reproduzir em modo Guia, **When** o visitante arrasta a bola da barra de progresso para um novo ponto e solta, **Then** a reprodução salta imediatamente para esse ponto e a barra reflete a nova posição.
2. **Given** um áudio a reproduzir em modo lista, **When** o visitante arrasta ou toca na barra de progresso do mini-player, **Then** a reprodução salta para o ponto indicado.
3. **Given** a aplicação em segundo plano com áudio a reproduzir, **When** o visitante arrasta a bola de progresso apresentada na notificação em tempo real, **Then** a reprodução salta para o ponto indicado sem ser necessário reabrir a aplicação.
4. **Given** o visitante arrasta a barra de progresso num dos três sítios, **When** volta a olhar para os outros dois sítios (dentro da app ou na notificação), **Then** todos mostram a mesma posição atualizada de reprodução.
5. **Given** a aplicação em segundo plano com áudio a reproduzir num aparelho antigo cujo sistema operativo não desenha barra de progresso em notificações de media, **When** o visitante consulta a notificação, **Then** vê os controlos de anterior/reproduzir/próximo a funcionar normalmente, mantendo o controlo de posição disponível dentro da aplicação.

---

### User Story 2 - Avançar ou recuar de passo diretamente pela notificação (Priority: P2)

Como visitante com a aplicação em segundo plano (ecrã bloqueado ou noutra aplicação), quero conseguir avançar para o próximo passo da visita ou voltar ao anterior diretamente pela notificação, sem ter de reabrir a aplicação.

**Why this priority**: Completa o controlo do áudio em segundo plano que hoje só permite pausar/retomar; depende da barra de progresso (US1) estar correta para que a posição mostrada continue fiável após um salto de passo.

**Independent Test**: Com a aplicação em segundo plano e um áudio de um item intermédio da visita a reproduzir, tocar no botão de "próximo" da notificação e confirmar que a reprodução passa para o áudio do passo seguinte da sequência guiada; repetir com "anterior".

**Acceptance Scenarios**:

1. **Given** a aplicação em segundo plano a reproduzir o áudio de um passo que não é o último da visita, **When** o visitante toca em "próximo" na notificação, **Then** a reprodução avança para o áudio do passo seguinte da sequência guiada (introdução/area/item, pela mesma ordem já usada dentro da app).
2. **Given** a aplicação em segundo plano a reproduzir o áudio de um passo que não é o primeiro da visita, **When** o visitante toca em "anterior" na notificação, **Then** a reprodução recua para o áudio do passo anterior da sequência guiada.
3. **Given** o passo atual é o primeiro da sequência guiada, **When** o visitante toca em "anterior" na notificação, **Then** nada acontece (o controlo não recua além do início).
4. **Given** o passo atual é o último da sequência guiada, **When** o visitante toca em "próximo" na notificação, **Then** nada acontece (o controlo não avança além do fim).
5. **Given** o visitante avança ou recua de passo pela notificação, **When** reabre a aplicação, **Then** o modo Guia e o modo lista mostram o mesmo passo atualmente selecionado pela notificação.

---

### User Story 3 - Reconhecer o que está a ouvir sem abrir a aplicação (Priority: P3)

Como visitante com a aplicação em segundo plano, quero ver na notificação a capa, o título do que estou a ouvir e o nome da tour, tal como vejo no mini-player dentro da aplicação, para saber de imediato onde vou na visita sem ter de a reabrir.

**Why this priority**: É uma melhoria de clareza/orientação sobre uma funcionalidade que já existe (pausar/retomar em segundo plano já funciona); não bloqueia o controlo do áudio em si, por isso fica com prioridade mais baixa que US1 e US2.

**Independent Test**: Iniciar uma visita guiada, colocar a aplicação em segundo plano, e confirmar que a notificação mostra a capa do passo atual, o título desse passo e o nome da tour, atualizando-se sempre que o passo muda (manualmente ou por fim natural do áudio).

**Acceptance Scenarios**:

1. **Given** a aplicação em segundo plano a reproduzir o áudio de um item, **When** o visitante consulta a notificação, **Then** vê a capa, o título desse item e o nome da tour em curso, tal como aparecem no mini-player em modo lista dentro da app.
2. **Given** a sequência guiada avança para um passo diferente (por fim natural do áudio ou por next/previous na notificação), **When** o visitante consulta novamente a notificação, **Then** a capa, o título e o nome da tour mostrados refletem o novo passo atual.
3. **Given** o passo atual é uma introdução de tour ou uma area (não um item), **When** o visitante consulta a notificação, **Then** a capa e o título mostrados correspondem ao conteúdo próprio desse tipo de passo (mesma lógica já usada pelo mini-player da app), mantendo sempre visível o nome da tour.
4. **Given** a aplicação em segundo plano (fora da app, mas a ouvir a tour), **When** o visitante toca no corpo da notificação (fora dos botões de controlo), **Then** a aplicação reabre/volta para primeiro plano, mostrando a tour em curso.

---

### Edge Cases

- Passo atual sem capa definida (ex.: introdução de tour sem imagem própria): a notificação apresenta um estado por omissão em vez de espaço vazio ou erro, coerente com o que a app já faz no mini-player para o mesmo caso.
- Arrastar a barra de progresso para o próprio fim do áudio: a reprodução avança automaticamente para o passo seguinte, tal como já acontece hoje quando um áudio termina naturalmente.
- Arrastar a barra de progresso enquanto o áudio ainda está a carregar/em buffer: o gesto é ignorado ou aplicado assim que o áudio estiver pronto, nunca bloqueando nem rebentando a aplicação.
- Arrastar a barra de progresso, ou usar next/previous na notificação, com o áudio em pausa: a reprodução retoma automaticamente na nova posição/passo, mesmo que estivesse em pausa antes da ação.
- Next/previous pela notificação leva a um passo (item ou area) sem áudio associado: a notificação atualiza para esse passo (capa/título/tour) e fica em silêncio, sem saltar automaticamente para o passo seguinte com áudio — mesmo comportamento já existente na navegação manual dentro da app (spec 005).
- Visitante troca de idioma com a aplicação em segundo plano: o título e o nome da tour na notificação atualizam para o novo idioma na próxima vez que a notificação for atualizada (mesmo comportamento de idioma já existente no resto da app).
- Serviço de áudio em segundo plano é terminado pelo sistema operativo (pouca memória, etc.): a notificação desaparece de forma limpa, sem next/previous/seek deixarem a aplicação num estado inconsistente ao ser reaberta.
- Build de Desktop (sem notificação de sistema operativo): a barra de progresso continua funcional em modo Guia e modo lista; o mini-player de notificação em tempo real não se aplica, por ser uma funcionalidade exclusiva do Android.
- Aparelho antigo cujo sistema operativo não desenha barra de progresso em notificações de media: a notificação mostra apenas capa, título, nome da tour e botões de controlo; o seek continua disponível dentro da app (modo Guia/lista).
- Passo sem áudio alcançado por next/previous: como não há áudio, a duração publicada refere-se ao passo anterior — a bola de progresso não é acionável até o visitante voltar a um passo com áudio, mas a capa/título/tour atualizam-se normalmente.
- Visitante toca no corpo da notificação enquanto um dos botões de controlo (anterior/play-pause/próximo/parar) está a ser tocado: a ação do botão tem prioridade (o toque no corpo só reabre a app quando não atinge nenhum botão), tal como em qualquer notificação de media padrão do Android.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST permitir ao visitante alterar a posição de reprodução do áudio atual arrastando ou tocando na barra de progresso em modo Guia.
- **FR-002**: O sistema MUST permitir ao visitante alterar a posição de reprodução do áudio atual arrastando ou tocando na barra de progresso em modo lista.
- **FR-003**: O sistema MUST permitir ao visitante alterar a posição de reprodução do áudio atual através da barra de progresso apresentada na notificação em tempo real, com a aplicação em segundo plano.
- **FR-004**: O sistema MUST manter a posição de reprodução consistente entre modo Guia, modo lista e notificação, refletindo em todos o resultado de um salto de posição feito em qualquer um deles.
- **FR-004a**: Se o áudio estiver em pausa, o sistema MUST retomar automaticamente a reprodução ao efetuar um seek (arrastar/tocar na barra de progresso) em qualquer um dos três sítios.
- **FR-005**: O sistema MUST permitir ao visitante avançar para o passo seguinte da sequência guiada diretamente a partir da notificação em tempo real, sem reabrir a aplicação.
- **FR-006**: O sistema MUST permitir ao visitante recuar para o passo anterior da sequência guiada diretamente a partir da notificação em tempo real, sem reabrir a aplicação.
- **FR-007**: O avanço/recuo de passo pela notificação MUST seguir a mesma sequência guiada (introdução, areas e items, pela mesma ordem) já usada dentro da aplicação, nunca a saltando ou divergindo dela.
- **FR-008**: Quando o passo atual for o primeiro da sequência guiada, o sistema MUST tornar inofensivo o controlo de "anterior" na notificação (sem efeito), em vez de dar erro ou dar a volta ao fim da sequência.
- **FR-009**: Quando o passo atual for o último da sequência guiada, o sistema MUST tornar inofensivo o controlo de "próximo" na notificação (sem efeito), em vez de dar erro ou dar a volta ao início da sequência.
- **FR-009a**: Se o áudio estiver em pausa, o sistema MUST retomar automaticamente a reprodução ao avançar/recuar de passo (next/previous) pela notificação.
- **FR-009b**: Se o passo alcançado por next/previous na notificação não tiver áudio associado, o sistema MUST apresentar esse passo (capa/título/tour) sem reproduzir áudio, sem saltar automaticamente para outro passo — mesmo comportamento já existente na navegação manual dentro da app para um passo sem áudio.
- **FR-010**: O sistema MUST apresentar na notificação em tempo real a capa do passo atual da visita.
- **FR-011**: O sistema MUST apresentar na notificação em tempo real o título do passo atual da visita.
- **FR-012**: O sistema MUST apresentar na notificação em tempo real o nome da tour em curso.
- **FR-013**: O conteúdo da notificação (capa, título, nome da tour) MUST atualizar-se sempre que o passo atual mudar, seja por avanço natural do áudio, seja por ação do visitante (arrastar, next, previous).
- **FR-014**: Ao reabrir a aplicação depois de ações feitas pela notificação (seek, next, previous), o sistema MUST mostrar em modo Guia e modo lista o mesmo passo e a mesma posição de reprodução refletidos na notificação.
- **FR-015**: O sistema MUST reabrir/trazer a aplicação para primeiro plano quando o visitante tocar no corpo da notificação em tempo real (fora dos botões de controlo).
- **FR-016**: O sistema MUST publicar na sessão de media do dispositivo os metadados do passo atual (duração, título, nome da tour e capa), de modo a que o sistema operativo desenhe a barra/bola de progresso na notificação. A duração é obrigatória — sem ela nenhum indicador de progresso é apresentado.
- **FR-017**: A disposição visual dos elementos da notificação (posição da capa face ao texto) é determinada pelo sistema operativo e MUST NOT ser imposta pela aplicação, por ser condição necessária para que a bola de progresso seja arrastável e para manter a integração com o ecrã de bloqueio e dispositivos de media externos.

### Key Entities *(include if feature involves data)*

- **Passo de visita**: unidade lógica já existente da sequência guiada (introdução, area ou item); esta funcionalidade não introduz novos tipos, apenas consome o passo atual para decidir o que mostrar e para onde navegar.
- **Estado de reprodução de áudio**: posição atual, duração e passo associado ao áudio em curso; passa a ser a fonte única de verdade partilhada entre modo Guia, modo lista e notificação.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% das tentativas de arrastar a barra de progresso, em qualquer um dos três sítios (Guia, lista, notificação), a reprodução salta para o ponto indicado.
- **SC-002**: Um visitante consegue avançar ou recuar de passo a partir da notificação, com o ecrã bloqueado, sem nunca precisar de desbloquear ou reabrir a aplicação.
- **SC-003**: Em 100% dos passos da visita, o conteúdo mostrado na notificação (capa, título, nome da tour) corresponde ao mesmo conteúdo mostrado no mini-player em modo lista dentro da app para esse mesmo passo.
- **SC-004**: Depois de qualquer ação feita pela notificação (seek, next, previous), reabrir a aplicação mostra sempre o mesmo passo e posição em modo Guia e modo lista, sem exigir qualquer correção manual do visitante.
- **SC-005**: Em 100% dos toques no corpo da notificação (fora dos botões de controlo), a aplicação reabre/volta para primeiro plano.
- **SC-006**: Em 100% das visitas com áudio a reproduzir em segundo plano num aparelho cujo sistema operativo suporta progresso em notificações de media, a notificação mostra a bola de progresso e arrastá-la altera a posição de reprodução.

## Assumptions

- A sequência guiada (introdução, areas, items) já definida e ordenada pela spec 005 é reutilizada tal e qual como fonte da ordem de navegação por next/previous; esta spec não altera essa ordem, só o controlo sobre ela.
- O mini-player de notificação em tempo real é uma funcionalidade exclusiva da build Android (Foreground Service); a build Desktop mantém o controlo de progresso apenas em modo Guia e modo lista.
- Não são necessárias alterações ao Strapi/backend — toda a funcionalidade descrita é local à aplicação móvel (reprodução, notificação e sincronização de estado entre os três sítios).
- A guardagem/retoma de progresso de visita entre sessões (já implementada na spec 005) não é alterada por esta spec; seek/next/previous pela notificação são navegação normal dentro da visita já em curso, não uma nova forma de retomar uma visita fechada.
- O "nome da tour" e o "título do passo" mostrados na notificação usam o mesmo texto e lógica por tipo de passo (introdução/area/item) já usados no mini-player em modo lista, sem necessidade de novos campos de conteúdo no Strapi.
- A app suporta Android 6 (API 23) até à versão mais recente (`minSdkVersion`/`targetSdkVersion` do projeto). A barra/bola de progresso dentro de uma notificação é sempre desenhada pelo sistema operativo a partir dos metadados da sessão de media — não é tecnicamente possível construir uma barra arrastável numa notificação personalizada em nenhuma versão do Android. Em aparelhos antigos cujo sistema não suporta progresso em notificações de media, a notificação funciona na mesma, apenas sem esse indicador.
- Aceitar o layout imposto pelo sistema na notificação (em vez de replicar o mini-player da app) é uma condição técnica para a bola ser arrastável, não uma preferência estética — decisão confirmada com o utilizador após teste em dispositivo real.
