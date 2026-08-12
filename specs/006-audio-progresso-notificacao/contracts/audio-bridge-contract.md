# Contrato: AudioBridge (C++) ↔ TourAudioService (Java, Android) ↔ QML

Este contrato não existia de forma explícita antes desta feature — a falta dele foi exatamente a causa do bug de seek (`AudioBridge.seek` vs `AudioBridge.seekTo`). Documenta-se aqui a interface completa após esta feature, para evitar recorrência.

## Métodos QML → C++ (`Q_INVOKABLE` em `AudioBridge`)

| Método | Assinatura (após esta feature) | Chamado por | Efeito |
|---|---|---|---|
| `setPlaylist` | `setPlaylist(QStringList urls, QStringList titles, QStringList covers, QString tourName, int currentIndex)` | `playCurrentAudio()` em `TourPage.qml`, sempre que `contadorParagens` muda ou a tour (re)inicia | Substitui o playlist ativo em Java (`TourAudioService.setServicePlaylist`), incluindo os metadados usados na notificação |
| `startAudio` | `startAudio(QString url)` | `playCurrentAudio()`, e pontos de reprodução isolada (QR/NFC de item fora da tour) | Arranca a reprodução desse URL no `TourAudioService` (Android) |
| `stopAudio` | `stopAudio()` | Fim de tour, troca de item isolado | Para e liberta o `MediaPlayer`/notificação |
| `pauseAudio` / `resumeAudio` | sem parâmetros | Botão play/pause em modo Guia/lista | Pausa/retoma sem perder o `currentIndex` |
| `seekTo` | `seekTo(int msec)` | Arrastar/tocar na barra de progresso (modo Guia e modo lista) — **antes desta feature era chamado incorretamente como `seek`** | Move a posição de reprodução no `MediaPlayer` Java; se estava em pausa, retoma (FR-004a) |
| `goToNext` / `goToPrevious` | sem parâmetros | **Não usados pelo QML** (confirmado na investigação) — mantidos por compatibilidade, mas a navegação real da app passa sempre por `setPlaylist`+`startAudio` via `playCurrentAudio()` | N/A nesta feature |

## Sinais C++ → QML

| Sinal | Quando dispara | Consumido por |
|---|---|---|
| `currentTrackChanged(int index, QString url)` | Sempre que o Java muda de faixa por iniciativa própria — i.e., `ACTION_NEXT`/`ACTION_PREVIOUS` disparado pela notificação — via JNI `nativeTrackChanged` | `Connections { target: AudioBridge }` em `TourPage.qml`: atualiza `contadorParagens` e `isAudioPlaying` (esta feature corrige para só marcar `isAudioPlaying = true` quando `url` não é vazio) |
| `audioPositionChanged(int position, int duration)` | A cada ~250ms enquanto o `MediaPlayer` Java está a tocar, via JNI `nativePositionChanged` | Atualiza `root.fakePosition`/`root.fakeDuration`, usados pela barra de progresso em modo Guia e pelo mini-player em modo lista |

## Métodos C++ → Java (estáticos, via JNI, em `TourAudioService`)

| Método Java | Assinatura (após esta feature) | Chamado a partir de |
|---|---|---|
| `setServicePlaylist` | `setServicePlaylist(Context, String[] urls, String[] titles, String[] covers, String tourName, int index)` | `AudioBridge::setPlaylist` |
| `seekToPosition` | `seekToPosition(int msec)` | `AudioBridge::seekTo` |
| `startService` / `stopService` / `pauseAudio` / `resumeAudio` | inalterados | `AudioBridge::startAudio/stopAudio/pauseAudio/resumeAudio` |

## Métodos Java → C++ (JNI, declarados `native` em `TourAudioService`)

| Método nativo | Quando é chamado |
|---|---|
| `nativeTrackChanged(int index, String url)` | Após `ACTION_NEXT`/`ACTION_PREVIOUS` mudar de faixa (com ou sem áudio — ver regra abaixo) |
| `nativePositionChanged(int position, int duration)` | A cada ciclo do `progressRunnable` (~250ms) enquanto a tocar |

## Regra de comportamento em `handleAction(ACTION_NEXT / ACTION_PREVIOUS)` (nova nesta feature)

Antes de chamar `playAudio(url)`, `handleAction` passa a verificar se `url` (o URL do novo `currentIndex`) é vazio:

- **Se vazio** (passo sem áudio, FR-009b): atualiza `currentIndex`/`currentUrl`, chama `nativeTrackChanged(currentIndex, "")` (para a app saber em que passo está e mostrar `title`/`imageUrl` corretos), atualiza a notificação com o novo título/capa mas **sem** iniciar reprodução — nunca chama `playAudio()` nem `handleAction(ACTION_STOP)`.
- **Se não vazio**: comportamento atual mantido — `playAudio(url)` e, ao preparar, retoma a reprodução mesmo que o estado anterior fosse pausa (FR-009a).

Esta é a correção da regressão identificada em `research.md` §3 (hoje um passo sem áudio alcançado por next/previous derruba todo o serviço).

## Conteúdo da notificação (`createNotification`, novo nesta feature)

- **Título**: `titles[currentIndex]` (título do passo atual).
- **Texto secundário**: `tourName` (nome da tour em curso) — substitui "Audio Tour ativo"/"Áudio em pausa" como texto principal; o estado play/pause continua visível pelo ícone/ação do botão central.
- **Capa (`setLargeIcon` + `METADATA_KEY_ALBUM_ART`)**: bitmap carregado a partir de `covers[currentIndex]`, preferindo sempre um caminho de ficheiro local já cacheado (mesmo padrão de `resolveUrl` do resto da app) antes de qualquer pedido de rede; carregamento nunca corre na thread principal do `Service`; falha a carregar não bloqueia nem impede o resto da notificação de atualizar. **Atenção**: os caminhos locais chegam como URI `file://...` (`FileHelper::getLocalMediaFolder` usa `QUrl::fromLocalFile`) e o prefixo tem de ser removido antes de `BitmapFactory.decodeFile`, que falha silenciosamente com ele (research.md §6.2).
- **Progresso (bola arrastável)**: **não** é definido no `NotificationCompat.Builder`. É o sistema operativo que o desenha, a partir de dois inputs da `MediaSession`: `updateMediaMetadata()` publica `METADATA_KEY_DURATION` (obrigatório — sem ele não aparece nada) e `updatePlaybackState()` publica a posição + `ACTION_SEEK_TO` a cada 250ms. O arrastar do utilizador chega de volta por `MediaSessionCompat.Callback.onSeekTo` → `seekToPosition`. Tentativas descartadas (ver research.md §6.1): `setProgress()` é ignorado com `MediaStyle`, e vistas personalizadas (`RemoteViews`/`DecoratedMediaCustomViewStyle`) são descartadas pelo sistema em Android 13+.
- **Tocar no corpo da notificação (`setContentIntent`)**: abre/traz `MuseumActivity` para primeiro plano (`FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_REORDER_TO_FRONT`), sem interferir com os botões de ação (que continuam a disparar os seus próprios `PendingIntent` de serviço).
