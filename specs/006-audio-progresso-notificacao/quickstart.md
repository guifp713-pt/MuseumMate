# Quickstart: Validar Áudio — Barra de Progresso e Mini-Player

Sem suite de testes automatizados neste repositório (ver constitution — "Development Workflow & Quality Gates"). Validação end-to-end manual, seguindo os cenários de aceitação de `spec.md`. Esta feature exige um dispositivo/emulador **Android** para os cenários de notificação (US2/US3) — a build Desktop só permite validar o seek em modo Guia/lista (US1, parcial).

## Pré-requisitos

1. Backend Strapi já a correr (`cd backend/app && npm run develop`), com uma tour de teste que tenha pelo menos 4-5 passos (idealmente incluindo introdução, uma area e vários items) — reutilizar os dados de teste já preparados para a spec 005.
2. Ter pelo menos um passo **sem** áudio definido na tour de teste (para validar FR-009b / o passo silencioso).
3. Compilar e instalar a app no Android (arm64-v8a ou armeabi-v7a) apontando para esse backend.
4. Ter acesso ao ecrã de notificações do Android (arrastar a barra de notificações, ou bloquear o ecrã) durante os testes.

## Cenários de validação

### 1. Seek funciona nos 3 sítios (US1 / FR-001 a FR-004, FR-004a)

- Em modo Guia, com áudio a tocar, arrastar `ballProgressAudioItem` para um novo ponto e soltar.
  - **Esperado**: a reprodução salta para esse ponto (confirmar pelo tempo apresentado e pelo conteúdo ouvido).
- Repetir tocando (sem arrastar) num ponto qualquer da barra.
  - **Esperado**: mesmo salto imediato.
- Repetir os dois gestos acima no mini-player em modo lista.
  - **Esperado**: mesmo comportamento.
- Colocar a app em segundo plano (botão home, sem fechar) e arrastar o slider de progresso da notificação.
  - **Esperado**: a reprodução salta para esse ponto sem reabrir a app.
- Pausar o áudio, depois fazer seek em qualquer um dos 3 sítios.
  - **Esperado**: a reprodução retoma automaticamente na nova posição (FR-004a) em vez de ficar parada.
- Depois de um seek num sítio, verificar os outros dois (reabrindo a app se o seek foi feito na notificação).
  - **Esperado**: todos mostram a mesma posição.

### 2. Next/previous pela notificação (US2 / FR-005 a FR-009, FR-009a)

- Com a app em segundo plano e um item intermédio a tocar, tocar em "próximo" na notificação.
  - **Esperado**: avança para o áudio do passo seguinte da sequência guiada (mesma ordem intro/area/item já usada dentro da app).
- Tocar em "anterior" na notificação.
  - **Esperado**: recua para o passo anterior.
- Navegar até ao primeiro passo da visita e tocar em "anterior".
  - **Esperado**: nada acontece (sem erro, sem dar a volta ao fim).
- Navegar até ao último passo e tocar em "próximo".
  - **Esperado**: nada acontece.
- Pausar o áudio, depois tocar em "próximo"/"anterior" na notificação.
  - **Esperado**: retoma a reprodução automaticamente no novo passo (FR-009a).
- Navegar por next/previous até ao passo sem áudio preparado no pré-requisito 2.
  - **Esperado**: a notificação atualiza para esse passo (capa/título/tour) e fica em silêncio — **o serviço e a notificação não desaparecem** (esta é a regressão que esta feature corrige; antes desta correção, o serviço parava por completo neste caso).
- A partir desse passo silencioso, tocar em "próximo"/"anterior" outra vez para um passo com áudio.
  - **Esperado**: volta a tocar normalmente.
- Depois de navegar pela notificação, reabrir a app.
  - **Esperado**: modo Guia e modo lista mostram o mesmo passo/posição que a notificação tinha (FR-014).

### 3. Conteúdo da notificação (US3 / FR-010 a FR-013)

- Com a app em segundo plano a tocar um item, consultar a notificação.
  - **Esperado**: mostra a capa do item, o título do item e o nome da tour em curso — mesmo conteúdo do mini-player em modo lista dentro da app para esse mesmo passo.
- Avançar/recuar de passo (pela notificação ou reabrindo a app e usando os botões, depois voltando a segundo plano).
  - **Esperado**: capa/título atualizam-se para o novo passo; nome da tour mantém-se.
- Chegar a um passo de introdução de tour ou a um passo de area (não um item).
  - **Esperado**: capa e título mostrados correspondem ao conteúdo próprio desse passo (imagem/título da tour para a introdução, imagem/nome da area para o passo de area), mantendo o nome da tour visível.
- (Edge case) Com ligação de rede desligada e uma capa ainda não descarregada localmente para o dispositivo.
  - **Esperado**: a notificação continua a mostrar título/tour normalmente; a capa fica com o ícone por omissão em vez de falhar a atualizar o resto do conteúdo.

### 4. Abrir a app pela notificação e barra de progresso visual (US3 / FR-015, FR-016)

- Com a app em segundo plano, tocar no corpo da notificação (fora dos botões de anterior/play-pause/próximo/parar).
  - **Esperado**: a app reabre/volta para primeiro plano, mostrando a tour em curso.
- Tocar especificamente em cada um dos botões de controlo.
  - **Esperado**: cada botão continua a executar a sua própria ação (pausar/reproduzir/avançar/recuar/parar) sem abrir a app.
- Com áudio a reproduzir em segundo plano, expandir a notificação.
  - **Esperado**: a notificação mostra a bola/barra de progresso desenhada pelo sistema, que avança sozinha com a reprodução.
- Arrastar essa bola para outro ponto.
  - **Esperado**: a reprodução salta para o ponto indicado; ao reabrir a app, o modo Guia/lista mostram a mesma posição.
- (Só em aparelhos antigos cujo sistema não suporta progresso em notificações de media) Consultar a notificação.
  - **Esperado**: sem bola de progresso, mas capa, título, nome da tour e botões anterior/reproduzir/próximo continuam a funcionar normalmente.
- (Bónus, mesma origem técnica) Bloquear o ecrã com áudio a tocar.
  - **Esperado**: os controlos de media do ecrã de bloqueio mostram capa, título e nome da tour, com a mesma bola de progresso.

## Critério de aceitação da fase

Todos os cenários acima passam manualmente num dispositivo/emulador Android antes de `tasks.md` ser considerado concluído para esta feature.
