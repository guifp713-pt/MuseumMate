# Phase 1 Data Model: Áudio — Barra de Progresso e Mini-Player

Esta feature não introduz nenhuma entidade persistida (nem no Strapi, nem em SQLite local) — apenas estado em memória, partilhado entre as três camadas da ponte de áudio já existente. Documenta-se aqui esse estado partilhado e a extensão ao "playlist" já transportado entre QML, C++ e Java.

## Estado de reprodução partilhado

Um único estado lógico, espelhado (não duplicado com fontes independentes) nas três camadas:

| Campo | Fonte de verdade | Espelhado em |
|---|---|---|
| `currentIndex` (posição na sequência de passos) | `TourAudioService` (Java) — atualizado por `ACTION_NEXT`/`ACTION_PREVIOUS` ou por `setServicePlaylist` a cada navegação vinda da app | `AudioBridge::m_currentIndex` (C++, via `handleTrackChangedFromJava`) → `contadorParagens` (QML, via `onCurrentTrackChanged`) |
| `position`/`duration` (ms) | `MediaPlayer` (Java), amostrado a cada 250ms | `AudioBridge::audioPositionChanged` (C++) → `root.fakePosition`/`root.fakeDuration` (QML, modo Guia + mini-player) → `PlaybackStateCompat` (notificação, via `updatePlaybackState`) |
| `isPlaying` | `MediaPlayer.isPlaying()` (Java) | `PlaybackStateCompat.STATE_PLAYING/PAUSED` (notificação); `root.isAudioPlaying` (QML, atualizado nas ações que o próprio QML já dispara — play/pause/next/previous/seek) |

Esta feature não move a fonte de verdade de sítio — apenas corrige a ligação (`seek`→`seekTo`) e acrescenta os campos abaixo ao mesmo mecanismo de propagação já existente.

## Extensão ao "playlist" transportado (QML → C++ → Java)

Hoje o playlist é apenas uma lista de URLs de áudio, uma por passo da sequência guiada. Passa a incluir, em paralelo (mesmo índice), o necessário para a notificação mostrar conteúdo rico:

| Campo | Tipo | Origem (já existente) | Uso |
|---|---|---|---|
| `audioUrl` | string (URL local ou remota) | `steps[i].audioUrl` (`buildTourSequence`, spec 005) | URL a reproduzir (já existia) |
| `title` | string | `steps[i].title` (`buildTourSequence`, spec 005) | Título do passo mostrado na notificação (novo) |
| `imageUrl` | string (URL local ou remota) | `steps[i].imageUrl` (`buildTourSequence`, spec 005) | Capa mostrada na notificação, via `setLargeIcon` (novo) |
| `tourName` | string (não indexado — um valor por visita) | `tourInfo.nameTour` (já existente em `TourPage.qml`) | Texto secundário da notificação (novo) |

Nenhum destes campos precisa de novo conteúdo no Strapi — todos já existem no catálogo consumido pela app desde a spec 005.

## Regras de estado (derivadas dos Functional Requirements da spec)

- Um passo com `audioUrl` vazio ("") é um estado válido: `currentIndex` avança/recua normalmente, `title`/`imageUrl`/`tourName` atualizam-se, mas nenhum áudio é carregado nem reproduzido, e o serviço em segundo plano permanece ativo (FR-009b).
- Um seek (em qualquer um dos 3 sítios) ou um next/previous pela notificação, quando `isPlaying` é falso, transita `isPlaying` para verdadeiro na mesma ação (FR-004a/FR-009a) — nunca fica pausado numa posição/passo novo sem o utilizador pedir play de novo.
- `currentIndex` nunca sai do intervalo `[0, playlist.length - 1]`; próximo no último passo e anterior no primeiro passo são no-ops (FR-008/FR-009, já implementados em `handleAction`).
