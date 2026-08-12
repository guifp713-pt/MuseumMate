# Phase 0 Research: Áudio — Barra de Progresso e Mini-Player

## 1. Porque é que a barra de progresso (seek) não funciona em nenhum dos 3 sítios

**Decision**: Corrigir as 4 chamadas em `TourPage.qml` (linhas ~908, ~920, ~1150, ~1162) de `AudioBridge.seek(newPos)` para `AudioBridge.seekTo(Math.round(newPos))`, o método que já existe e já está corretamente ligado a `TourAudioService.seekToPosition(int)` (Java) → `player.seekTo(msec)`, e ao `MediaSessionCompat.Callback.onSeekTo(long)` que já trata o seek vindo do sistema (ex.: slider automático da notificação em Android moderno).

**Rationale**: `AudioBridge.h`/`AudioBridge.cpp` só expõem `seekTo(int msec)` como `Q_INVOKABLE`; `seek` não existe como método, por isso a chamada QML falha silenciosamente (sem crash, sem efeito) em todos os 4 sítios onde aparece — os dois no modo Guia (`ballProgressAudioItem` + tap na barra) e os dois no mini-player em modo lista (`miniProgressBall` + tap). É uma correção de nome, não uma funcionalidade nova; reutiliza o método já implementado e já ligado corretamente ao Java (Constitution III).

**Alternatives considered**: Adicionar um novo método `seek(int)` em C++ que apenas delega para `seekTo` — rejeitado por introduzir um segundo nome para a mesma operação sem necessidade (mais superfície de API para manter sincronizada, contra Constitution III/IV).

## 2. Estado real do next/previous na notificação (Android)

**Decision**: Não é preciso implementar next/previous de raiz — já existem de ponta a ponta: `TourAudioService.onCreate()` regista `onSkipToNext`/`onSkipToPrevious` no `MediaSessionCompat.Callback`, `handleAction(ACTION_NEXT/ACTION_PREVIOUS)` já avança/recua `currentIndex` e chama `nativeTrackChanged(...)`, que por JNI chega a `AudioBridge::handleTrackChangedFromJava` e emite `currentTrackChanged(index, url)`, já ouvido em `TourPage.qml` (`Connections { target: AudioBridge; function onCurrentTrackChanged(...) { contadorParagens = index + 1; ... } }`). O que falta corrigir é o comportamento em passos sem áudio (ver ponto 3) e a falta de metadados na notificação (ver ponto 4) — não o mecanismo de navegação em si.

**Rationale**: Confirmado lendo `TourAudioService.java` (métodos `onSkipToNext`/`onSkipToPrevious`/`handleAction`), `AudioBridge.cpp` (`Java_..._nativeTrackChanged`) e `TourPage.qml` (`Connections` a `AudioBridge`). O `guiaLayout`/`GuiaProximasSpecs.md` descrevia isto como "por implementar", mas o código já existia; a experiência de "não funciona" do utilizador é explicada pelos pontos 3 e 4 (o serviço morre em passos sem áudio, e mesmo quando muda de faixa a notificação nunca mostra o quê mudou).

**Alternatives considered**: Reescrever o mecanismo de next/previous do zero — rejeitado por já existir e funcionar mecanicamente; a correção mínima e correta é nos dois problemas reais identificados abaixo.

## 3. Passo sem áudio alcançado por next/previous na notificação derruba o serviço

**Decision**: `playCurrentAudio()` em `TourPage.qml` já constrói o playlist com `steps[i].audioUrl || ""` (string vazia para passos sem áudio) e passa isso a `AudioBridge.setPlaylist(...)`. Do lado Java, `handleAction(ACTION_NEXT/ACTION_PREVIOUS)` chama sempre `playAudio(url)` incondicionalmente; `playAudio("")` falha em `player.setDataSource("")`, cai no `catch`, e chama `handleAction(ACTION_STOP)` — que liberta o `MediaPlayer`, a `MediaSession` e cancela a notificação por completo. A correção é adicionar uma verificação explícita: se o `url` do novo índice for vazio, `handleAction` atualiza `currentIndex`/`currentUrl`, chama `nativeTrackChanged(...)` (para a app saber em que passo está) e atualiza a notificação (novo título/capa, sem áudio a tocar), **sem** chamar `playAudio()` nem `ACTION_STOP`.

**Rationale**: É a leitura direta da resposta de clarificação já obtida ("fica nesse passo, em silêncio, sem saltar automaticamente") — e evita que um único passo sem áudio destrua toda a sessão de reprodução em segundo plano, o que seria uma regressão grave face ao comportamento atual (pausar/retomar já funciona hoje). A app (QML) já trata o caso equivalente localmente em `playCurrentAudio()` (`else { isAudioPlaying = false; ... }` sem chamar `stopAudio()`) — esta correção alinha o Java com o mesmo padrão já validado.

**Alternatives considered**: Ignorar next/previous quando o passo de destino não tem áudio (não avançar) — rejeitado por spec (FR-009b exige que o passo mude mesmo sem áudio, só não toca som).

## 4. Como levar título, capa e nome da tour até à notificação

**Decision**: Estender `setPlaylist` (QML → C++ → Java) para transportar, em paralelo às URLs de áudio já existentes, um array de títulos e um array de capas (mesma ordem/índice), mais o nome da tour (string única, não muda durante a visita). Assinatura resultante:
- QML: `AudioBridge.setPlaylist(urls, titles, covers, tourName, currentIndex)`
- C++ (`AudioBridge::setPlaylist`): recebe os 3 `QStringList` + `QString` + `int`, guarda-os, e encaminha para Java via JNI (mesmo padrão já usado para `urls`, replicado para `titles`/`covers`, mais um `jstring` para `tourName`).
- Java (`TourAudioService.setServicePlaylist`): guarda `titles`/`covers`/`tourName` em arrays/campos estáticos paralelos a `playlist`/`currentIndex`.
- `createNotification()` passa a usar `titles.get(currentIndex)` como título, `tourName` como texto secundário, e `covers.get(currentIndex)` para `setLargeIcon(bitmap)`.

Carregamento da capa: os valores de `imageUrl` já chegam de `ApiHandler.resolveUrl()` como caminho local absoluto (quando já descarregado/cacheado) ou URL remota (`baseUrl + path`) quando ainda não. Em Java, decidir pelo prefixo (`http`/`https` vs caminho de ficheiro): se for caminho local, `BitmapFactory.decodeFile(path)` numa thread de fundo (reaproveitando o mesmo `Handler`/thread pattern já usado para `progressRunnable`, ou uma `Thread` simples); se for URL remota, um pedido de rede simples (`HttpURLConnection` + `BitmapFactory.decodeStream`) na mesma thread de fundo — nunca na thread principal do `Service`. Se a capa falhar a carregar (rede indisponível, ficheiro corrompido), a notificação mantém-se sem `setLargeIcon` (ícone por omissão), nunca bloqueando nem falhando a atualização do resto do conteúdo (mesmo espírito de "nunca bloquear, nunca mostrar erro" já adotado no resto da app).

**Rationale**: Reutiliza exatamente o mecanismo de transporte já existente (arrays paralelos por índice, JNI `QStringList`→`jobjectArray`), só acrescentando dois arrays e uma string em vez de inventar um canal novo (ex.: JSON serializado, ou um novo par de métodos JNI) — Constitution III/IV. Os campos `title`/`imageUrl` já existem em cada passo (`buildTourSequence` em `ApiHandler.js`, spec 005), e `tourInfo.nameTour` já está disponível em `TourPage.qml`; não é preciso nenhum campo novo no Strapi.

**Alternatives considered**:
- Passar um único JSON serializado por passo em vez de arrays paralelos — rejeitado por ser mais código de (de)serialização dos dois lados da JNI para o mesmo resultado, sem benefício concreto no tamanho do problema (poucos passos por tour).
- Buscar o `currentStep`/`tourInfo` do lado Java através de uma nova chamada HTTP direta ao Strapi — rejeitado por duplicar a lógica de rede/cache já centralizada em `ApiHandler.js` (violaria Constitution I/II mesmo não havendo aqui fronteira Strapi↔mobile direta: introduziria uma segunda fonte de verdade para os mesmos dados).

## 5. Sincronização de posição entre modo Guia, modo lista e notificação (FR-004)

**Decision**: Nenhuma alteração adicional é necessária além da correção do ponto 1 — `handlePositionChangedFromJava`/`audioPositionChanged` já emitem posição/duração para o QML a cada 250ms (`progressRunnable` em `TourAudioService.java`), e `TourPage.qml` já atualiza `root.fakePosition`/`root.fakeDuration` a partir daí (usados tanto pela barra em modo Guia como pelo mini-player em modo lista). A única peça em falta era o próprio `seekTo` disparar a mudança real de posição no `MediaPlayer` — resolvido no ponto 1. A notificação, por usar `MediaSessionCompat`/`PlaybackStateCompat` com a posição atual (`updatePlaybackState`), já reflete a mesma posição automaticamente através do slider nativo do Android.

**Rationale**: Evita construir um mecanismo de sincronização novo quando o existente (polling a 250ms + sinal Qt) já cobre o requisito assim que o seek passar a ter efeito real no `MediaPlayer`.

**Alternatives considered**: Reduzir o intervalo de polling para maior "instantaneidade" — rejeitado por não haver requisito de latência mais apertado do que o já implementado, e por aumentar o custo de bateria/CPU sem benefício percebido.

## 6. Barra de progresso visual na notificação (versões anteriores ao Android 13) e abrir a app ao tocar

**Decision**: Duas adições pedidas pelo utilizador após a primeira ronda de implementação:

1. **Tocar no corpo da notificação abre a app**: `createNotification()` passa a definir `.setContentIntent(...)` com um `PendingIntent` para `MuseumActivity` (`FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_REORDER_TO_FRONT`) — em falta na implementação original (nenhum `setContentIntent` existia antes desta feature).
2. **Barra de progresso na notificação**: ver correção abaixo (§6.1) — a primeira tentativa (`setProgress`) não funcionava.

**Alternatives considered para o scrubber arrastável em todas as versões**:
- Subir `minSdkVersion` para 33 para garantir sempre o scrubber nativo — rejeitado por eliminar suporte a todos os aparelhos Android 6–12, uma alteração de âmbito muito maior do que o pedido.

### 6.1 Tentativa falhada: `setProgress()` é ignorado com `MediaStyle` (bug encontrado em teste real, Galaxy A14/Android 13+)

> **Superseded por §6.3** — esta tentativa também não funcionou no dispositivo real. Fica registada porque documenta duas limitações da plataforma que condicionam a solução final.

**Contexto**: testado num Samsung Galaxy A14 (SM-A146P, Android 13+) depois da primeira implementação — nem a capa nem a barra de progresso apareciam na notificação (título/tour/next/previous continuavam corretos).

**O que se aprendeu**: `Notification.Builder.setProgress()` **não tem efeito quando combinado com `MediaStyle`** — o layout de notificação de media do sistema não inclui o elemento de progresso genérico que `setProgress()` teria de preencher. A tentativa de contornar isto com `DecoratedMediaCustomViewStyle` + `RemoteViews` próprio (`notification_progress.xml`) **também falhou**, porque em Android 13+ o sistema descarta vistas personalizadas em notificações de media e impõe o seu próprio layout derivado da `MediaSession`. Esse ficheiro de layout foi entretanto removido do projeto.

### 6.2 Correção: capa não aparece — caminho local é um URI `file://`, não um caminho de sistema de ficheiros (bug encontrado no mesmo teste)

**Decision**: Em `requestCoverLoad`, antes de chamar `BitmapFactory.decodeFile(...)`, remover o prefixo `file://` do caminho (via `Uri.parse(coverPath).getPath()`) quando presente.

**Rationale**: `FileHelper::getLocalMediaFolder` (C++) devolve `QUrl::fromLocalFile(path).toString() + "/"` — ou seja, os caminhos locais já descarregados (usados em todo o resto da app, incluindo `resolveUrl` em `ApiHandler.js`) são strings `file:///...`, não caminhos de sistema de ficheiros simples. `BitmapFactory.decodeFile` espera um caminho simples e falha silenciosamente (devolve `null`, sem lançar exceção) quando recebe o prefixo `file://` por engano — exatamente o sintoma observado (capa nunca aparecia, sem erro visível). **Confirmado pelo utilizador**: após este fix, a capa passou a aparecer na notificação no Galaxy A14.

### 6.3 Solução final para a bola de progresso: `MediaSession.setMetadata()` com `METADATA_KEY_DURATION`

**Contexto**: no segundo teste real (Galaxy A14, Android 13+), a capa já aparecia (§6.2 resolvido) mas continuava sem qualquer barra ou bola de progresso.

**Decision**: Voltar a `MediaStyle` puro (sem vistas personalizadas) e publicar `MediaMetadataCompat` na `MediaSession` através de um novo método `updateMediaMetadata()`, chamado a partir de `updateForegroundNotification()` (o único ponto por onde passam todas as mudanças de estado):
- `METADATA_KEY_DURATION` — a duração do áudio atual (**o requisito em falta**);
- `METADATA_KEY_TITLE` — título do passo atual;
- `METADATA_KEY_ARTIST`/`METADATA_KEY_ALBUM` — nome da tour;
- `METADATA_KEY_ALBUM_ART` — a capa já carregada em cache (§6.2).

Removidos: o `RemoteViews`/`notification_progress.xml`, o `DecoratedMediaCustomViewStyle` e o contador `notificationProgressTick` (a notificação já não precisa de ser reconstruída periodicamente — o sistema desenha a bola a partir do `PlaybackState`, que já era atualizado a cada 250ms).

**Rationale**: O Android só desenha a barra/bola de progresso numa notificação de media quando **ambas** as condições se verificam: (a) o `PlaybackState` declara `ACTION_SEEK_TO` — já estava feito desde antes desta feature; e (b) a `MediaSession` publica metadados com `METADATA_KEY_DURATION` — **nunca era chamado** (`setMetadata` não existia em lado nenhum do ficheiro). Sem a duração, o sistema não sabe qual é a escala da barra e simplesmente não a desenha — daí o sintoma. Esta é também a única via que produz uma bola **arrastável**, porque quem a desenha e trata o gesto é o próprio sistema (que já encaminha o arrastar para `MediaSessionCompat.Callback.onSeekTo` → `seekToPosition`, ambos já implementados). Como efeito secundário, os metadados alimentam também os controlos de media do ecrã de bloqueio, do Bluetooth do carro e dos auscultadores, sem código adicional.

**Trade-off aceite pelo utilizador**: em Android 13+ o layout da notificação de media é imposto pelo sistema (capa de um lado, título/tour do outro, botões em baixo), não sendo possível replicar exatamente o mini-player da app (imagem à esquerda, informação à direita). O utilizador escolheu explicitamente a bola arrastável funcional em detrimento do controlo do layout — ver spec.md § Clarifications, sessão de revisão pós-teste.

**Alternatives considered**: Notificação totalmente personalizada com `RemoteViews` (layout igual ao mini-player da app) — rejeitada pelo utilizador por implicar perder a bola arrastável (o Android não entrega gestos de arrastar a vistas personalizadas de notificações em nenhuma versão; `SeekBar` nem sequer é uma vista suportada em `RemoteViews`) e ainda a integração com ecrã de bloqueio/Bluetooth.

## Summary of unresolved NEEDS CLARIFICATION

Nenhum. As duas ambiguidades comportamentais foram resolvidas na fase de `/speckit-clarify` (auto-play em seek/next/previous durante pausa; passo sem áudio fica em silêncio) e todas as decisões técnicas foram confirmadas diretamente no código existente.
