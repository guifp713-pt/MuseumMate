# Implementation Plan: Áudio — Barra de Progresso e Mini-Player

**Branch**: `006-audio-progresso-notificacao` | **Date**: 2026-07-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-audio-progresso-notificacao/spec.md`

## Summary

Corrigir o controlo de reprodução de áudio da visita guiada nos três sítios onde é apresentado (modo Guia, modo lista, notificação em tempo real do Android) e enriquecer o conteúdo dessa notificação. A investigação do código existente confirma três causas-raiz distintas, todas de correção local (sem novas dependências nem novos endpoints):

1. **Seek não funciona em lado nenhum**: `TourPage.qml` chama `AudioBridge.seek(newPos)` em 4 sítios, mas `AudioBridge` (C++) só expõe `seekTo(int msec)` — o nome não bate certo, por isso a chamada falha silenciosamente sempre.
2. **Next/previous na notificação já estão implementados de ponta a ponta** (`MediaSessionCompat.Callback`, `ACTION_NEXT`/`ACTION_PREVIOUS` em `TourAudioService.java`, ponte JNI de volta a `AudioBridge::handleTrackChangedFromJava`, e `Connections { target: AudioBridge; onCurrentTrackChanged }` em `TourPage.qml` que já atualiza `contadorParagens`) — **mas** têm um bug real por trás: quando o passo alcançado não tem áudio (`url` vazio), `TourAudioService.playAudio("")` lança exceção, é apanhada, e chama `handleAction(ACTION_STOP)`, **derrubando todo o serviço e a notificação** em vez de ficar em silêncio nesse passo (viola o comportamento clarificado em FR-009b).
3. **Conteúdo da notificação é genérico** ("Museum Mate" + texto de estado): `setPlaylist`/`setServicePlaylist` só transportam URLs de áudio, nunca título, capa ou nome da tour — por isso `createNotification()` não tem de onde os tirar.

A abordagem é: (a) corrigir a chamada de seek para o nome certo; (b) blindar `TourAudioService` contra passos sem áudio (não parar o serviço, só ficar em silêncio nesse passo); (c) estender `setPlaylist`/`setServicePlaylist` para transportar também títulos, capas e o nome da tour (paralelo às URLs já transportadas), e usar essa informação em `createNotification()` (incluindo carregar a capa em bitmap, com o mesmo mecanismo de preferência por ficheiro local já cacheado que o resto da app usa).

## Technical Context

**Language/Version**: C++17 (Qt 6, `AudioBridge`), QML/JS (`TourPage.qml`), Java (Android, `TourAudioService`/`MuseumActivity`, via JNI)

**Primary Dependencies**: Qt Quick (mobile UI), `QMediaPlayer`/Android `MediaPlayer` já usados, `MediaSessionCompat`/`NotificationCompat`/`androidx.media` (já presentes em `TourAudioService.java`), sem novas bibliotecas

**Storage**: N/A — esta feature não introduz nem altera persistência (o progresso de tour da spec 005 não é tocado)

**Testing**: Validação manual end-to-end (`quickstart.md`) — não há suite automatizada configurada em nenhum dos dois stacks (ver constitution)

**Target Platform**: App Qt Quick para Android (arm64-v8a, armeabi-v7a) — a notificação/MediaSession é exclusiva do Android; Desktop só é afetado pela correção do seek em modo Guia/lista

**Project Type**: Mobile app (QML/C++/Java) — sem alterações ao backend Strapi

**Performance Goals**: Seek e mudança de passo devem refletir-se na UI/notificação sem atraso percetível (mesma cadência de atualização de posição já existente, 250ms); carregamento da capa na notificação não pode bloquear a thread principal do `Service`

**Constraints**: Não pode alterar a sequência guiada (intro/areas/items) nem a persistência de progresso já implementadas na spec 005; deve continuar a respeitar passos sem áudio sem travar a app nem o serviço em segundo plano; deve preferir sempre o ficheiro local já descarregado (mesmo mecanismo de `resolveUrl`/cache offline já usado no resto da app) antes de qualquer pedido de rede a partir do Java

**Scale/Scope**: Sequências guiadas com dezenas de passos; um único áudio ativo de cada vez, um dispositivo por visitante

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Avaliação |
|---|---|
| I. Environment Configuration Discipline | **Pass** — nenhum novo endpoint, URL ou configuração de ambiente introduzida; as capas continuam a ser resolvidas pelo mesmo `resolveUrl`/cache local já usado no resto da app, sem nova cópia de `baseUrl`. |
| II. Cross-Stack Consistency | **N/A nesta feature** — não há fronteira Strapi↔mobile envolvida; a única "fronteira" tocada é interna ao mobile (C++↔QML↔Java), tratada no ponto seguinte. |
| III. Simplicity / YAGNI | **Pass** — a correção do seek é uma renomeação da chamada QML para o método C++ já existente (sem novo método); o transporte de metadados na notificação estende o mecanismo de playlist já existente (arrays paralelos), em vez de introduzir um novo canal de comunicação C++↔Java; a blindagem contra passos sem áudio reutiliza o mesmo padrão de "não bloquear, não mostrar erro" já validado na spec 005 para os mesmos casos dentro da app. |
| IV. Maintainable Design | **Pass** — o contrato entre `AudioBridge` (C++) e `TourAudioService` (Java) fica documentado explicitamente em `contracts/audio-bridge-contract.md` (não existia antes, e foi exatamente a falta de um contrato explícito — `seek` vs `seekTo` — que causou o bug nº1); cada camada mantém a sua responsabilidade única (QML decide *o quê* tocar, C++ é só ponte, Java é a única fonte de verdade da reprodução em segundo plano). |
| V. Spec-Driven Development | **Pass** — este plano segue `spec.md` já clarificada; a implementação só decorre após `/speckit-tasks`. |

Nenhuma violação identificada — tabela de Complexity Tracking fica vazia.

## Project Structure

### Documentation (this feature)

```text
specs/006-audio-progresso-notificacao/
├── plan.md                          # este ficheiro
├── research.md                      # decisões técnicas (Phase 0)
├── data-model.md                    # estado de reprodução partilhado entre camadas (Phase 1)
├── contracts/
│   └── audio-bridge-contract.md     # contrato C++ (AudioBridge) ↔ Java (TourAudioService) ↔ QML
├── quickstart.md                    # guia de validação manual (Phase 1)
└── tasks.md                         # gerado por /speckit-tasks (Phase 2, ainda não criado)
```

### Source Code (repository root)

```text
TourAssistent-main/
├── AudioBridge.h                    # + parâmetros de metadados em setPlaylist(...)
├── AudioBridge.cpp                  # + encaminhar metadados para setServicePlaylist via JNI;
│                                    #   goToNext()/goToPrevious() ficam confirmados como não usados
│                                    #   pelo QML (só a notificação os aciona via ACTION_NEXT/PREVIOUS)
├── TourPage.qml                     # 4 chamadas AudioBridge.seek(...) → AudioBridge.seekTo(...);
│                                    #   playCurrentAudio() passa título/capa/nome da tour a setPlaylist();
│                                    #   onCurrentTrackChanged só marca isAudioPlaying quando há url
└── android/src/org/qtproject/example/
    └── TourAudioService.java        # setServicePlaylist(...) recebe arrays paralelos de título/capa +
                                     #   nome da tour; handleAction(NEXT/PREVIOUS) já não chama playAudio()
                                     #   quando o url do passo é vazio (fica em silêncio, sem parar o serviço);
                                     #   createNotification() usa título/capa/tour em vez do texto fixo,
                                     #   carregando a capa em background thread preferindo ficheiro local
```

**Structure Decision**: Toda a implementação fica no lado mobile (`TourAssistent-main/`), tocando as três camadas já existentes da ponte de áudio (QML → C++ `AudioBridge` → Java `TourAudioService`, e o caminho de volta via JNI `nativeTrackChanged`/`nativePositionChanged`). Não há alterações ao backend Strapi nem a outras páginas da app.

## Complexity Tracking

*Sem violações da Constitution Check — tabela não aplicável nesta feature.*
