# Guia para a próxima sessão — Specs 006 e 009

> **Para quem (humano ou IA) abrir este ficheiro**: este documento existe porque o utilizador fecha e reabre o Claude Code entre specs, perdendo o histórico da conversa. Lê isto do início ao fim antes de tocares em código. Quando a spec 009 estiver implementada, validada pelo utilizador, e o `guiaLayout` atualizado, **apaga este ficheiro** — a sua função é só fazer a ponte até lá.

## Estado atual (à data de escrita deste guia)

- Repositório: monorepo Museum Mate, já usa spec-kit (`.specify/`, `specs/001-005`).
- **Spec 005 (Tours — listagem e visita guiada) está concluída, implementada e validada pelo utilizador**, incluindo uma ronda de polimento visual pós-teste (cartão da tour fixada com altura dinâmica, título no modo Guia movido para cima da imagem, título no modo lista e no cabeçalho da TourPage com quebra de linha em vez de overflow).
- `TourAssistent-main/guiaLayout` é a checklist original do utilizador; os itens já resolvidos pela spec 005 estão marcados `[x]`.
- **Decisão do utilizador**: as specs 007 (polimento de UI: cores da HomePage, botão flutuante do chat) e 008 (FAQ da Entity para a IA) **foram removidas de propósito** — não voltar a propô-las nem a mexer nelas. Os itens correspondentes já foram apagados do `guiaLayout`.
- **Ficam só duas specs por fazer: 006 e 009**, nesta ordem.

## Como trabalhar (segue o mesmo processo da spec 005)

Para cada spec (006 primeiro, depois 009), usar sempre o fluxo completo do spec-kit, na ordem:

1. `/speckit-specify` — escrever a spec com base no conteúdo descrito abaixo.
2. `/speckit-clarify` — o utilizador gosta de ser questionado sobre ambiguidades antes de avançar (ver histórico da spec 005: várias rondas de `AskUserQuestion` em português de Portugal, uma pergunta de cada vez, com opção recomendada destacada). Não saltar este passo.
3. `/speckit-plan` — plano técnico, com investigação real do código (ler os ficheiros relevantes antes de escrever o plano, não assumir).
4. `/speckit-tasks` — tasks.md organizado por user story.
5. `/speckit-implement` — implementar, marcando `[X]` no `tasks.md` à medida que cada tarefa fica pronta.
6. No fim de cada spec: atualizar `TourAssistent-main/guiaLayout`, marcando `[x]` os itens resolvidos.

Notas de estilo já validadas pelo utilizador:
- Comunicar sempre em português de Portugal.
- Preferir a solução mais simples que resolva o requisito (constitution — Simplicity/YAGNI), reutilizando padrões já existentes no código em vez de introduzir mecanismos novos.
- Ler `.specify/memory/constitution.md` antes do plano — tem 5 princípios (Environment Config, Cross-Stack Consistency, Simplicity/YAGNI, Maintainable Design, Spec-Driven Development) que os planos têm de respeitar.

---

## Spec 006 — Áudio: barra de progresso e mini-player (app + notificação)

**Fazer esta primeiro.**

### Âmbito (do `guiaLayout`, itens ainda por marcar)

1. A `ballProgressAudioItem` (bola de arrastar na barra de progresso do áudio) não é funcional; deve permitir controlar (fazer *seek*) o áudio em: modo Guia, modo lista, e no mini-player da notificação em tempo real.
2. Os ficheiros Java que comunicam com o `.cpp` só permitem pausar/ouvir áudio em segundo plano; falta implementar **next** (próximo) e **previous** (anterior) na notificação/MediaSession Android.
3. O mini-player da notificação em tempo real deve mostrar o mesmo conteúdo do mini-player dentro da app (atualmente só mostra "Museum Mate" + 3 botões). **Já foi confirmado com o utilizador**: deve mostrar capa + título do item/passo + nome da tour, igual ao mini-player em modo lista da `TourPage.qml`.

### Pista técnica já identificada (verificar primeiro, antes de assumir mais nada)

Em `TourAssistent-main/TourPage.qml`, os `MouseArea` de arrastar/tocar na barra de progresso chamam `AudioBridge.seek(newPos)` — mas `TourAssistent-main/AudioBridge.h` só expõe `Q_INVOKABLE void seekTo(int msec)`. **Este nome não bate certo** e é a suspeita mais forte para a `ballProgressAudioItem` não fazer nada hoje. Confirmar isto lendo `AudioBridge.cpp` e `AudioBridge.h` no início do research da spec, e decidir se a correção é renomear a chamada QML para `seekTo` ou adicionar um método `seek` em C++ que delegue para `seekTo`.

### Ficheiros a investigar antes de escrever a spec/plano

- `TourAssistent-main/AudioBridge.h` / `AudioBridge.cpp` — interface C++↔QML do áudio (`startAudio`, `setPlaylist`, `goToNext/Previous`, `seekTo`, `pauseAudio`, `resumeAudio`).
- `TourAssistent-main/android/src/org/qtproject/example/TourAudioService.java` — o `Foreground Service` Android que mantém o áudio a tocar em segundo plano; é aqui que a notificação/MediaSession é construída e onde falta next/previous.
- `TourAssistent-main/android/src/org/qtproject/example/MuseumActivity.java` — ponte JNI entre o Java e o `main.cpp`.
- `TourAssistent-main/TourPage.qml` — já usa `steps` (array intro/item/area, da spec 005) em vez de uma lista simples de items; qualquer lógica de "faixa atual" deve trabalhar sobre `steps`/`contadorParagens`, que já existem.
- Miniplayer dentro da app já implementado em `TourPage.qml` (`id: miniPlayer`) — é o "look" que a notificação deve replicar (capa, título, tempo, play/pause, next/prev).

### O que já está fora de dúvida (não repetir perguntas sobre isto)

- Conteúdo da notificação: capa + título do passo + nome da tour (confirmado com o utilizador na spec 005).
- A barra de progresso deve funcionar nos 3 sítios (Guia, lista, notificação) — não só num deles.

---

## Spec 009 — Dashboard: correções de analytics e modo escuro

**Fazer depois da 006.**

### Âmbito (do `guiaLayout`, secção "Mudancas no Dashboard")

1. **Modo escuro** no dashboard (plugin `analytics-dashboard`).
2. **Contagem de visitantes**: hoje incrementa a cada troca de idioma; deve validar por `sessionId` — uma visita = uma sessão, não um evento.
3. **Percentagem de idiomas**: hoje calculada mal; deve determinar o **idioma dominante por `sessionId`** (o mais frequente nos eventos dessa sessão — **já confirmado com o utilizador**) e só depois calcular a percentagem sobre esses idiomas dominantes por sessão.
4. **Tabela de "visitas por período comparativo"**: hoje só compara um período com o anterior (dia vs dia anterior, 7 dias vs 7 dias anteriores, etc.); deve passar a mostrar uma **lista dos últimos N períodos, cada um comparado com o anterior** (não só uma comparação isolada) — **já confirmado com o utilizador**, falta definir o valor de N por filtro na fase de clarify.

### Ficheiros a investigar antes de escrever a spec/plano

- `backend/app/src/plugins/analytics-dashboard/admin/src/pages/HomePage.jsx` — UI do dashboard, incluindo os KPIs e a tabela de período comparativo.
- `backend/app/src/plugins/analytics-dashboard/server/src/controllers/controller.js` — lógica dos endpoints que calculam contagens/percentagens.
- `backend/app/src/plugins/analytics-dashboard/server/src/services/service.js` — provavelmente onde vive a lógica de agregação por `sessionId`/idioma/período.
- `backend/app/src/plugins/analytics-dashboard/server/src/routes/admin/index.js` — rotas admin do plugin.
- `backend/app/src/api/analytics-event/` — schema e controller do content-type `analytics-event` (para perceber que campos já existem por evento: `sessionId`, idioma, `entidadeDocumentId`, etc.).

### O que já está fora de dúvida (não repetir perguntas sobre isto)

- Sessão = idioma mais frequente entre os seus eventos, não o primeiro nem o último.
- Tabela comparativa = lista de vários períodos, cada um com a sua própria variação face ao anterior, não uma única comparação fixa.

### Por decidir no `/speckit-clarify` desta spec

- Valor exato de N por filtro (quantos dias/semanas/meses/anos mostrar na lista).
- Lembrar que o plugin `analytics-dashboard` precisa de rebuild (`npm run build`/`npm run watch`) e reinício completo do Strapi para alterações em `server/src` — não é hot-reload.

---

## No fim da spec 009

1. Marcar em `TourAssistent-main/guiaLayout` todos os itens resolvidos.
2. Confirmar com o utilizador que testou e validou.
3. **Apagar este ficheiro (`GuiaProximasSpecs.md`)** — já não há mais specs pendentes documentadas aqui, e o `CLAUDE.md` + `specs/` passam a ser suficientes para qualquer sessão futura.
