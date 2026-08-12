# Implementation Plan: Tours — Listagem e Visita Guiada

**Branch**: `005-tours-listagem-visita-guiada` | **Date**: 2026-07-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-tours-listagem-visita-guiada/spec.md`

## Summary

Redesenhar a listagem de tours (tour "museu completo" fixa no topo, layout igual ao da listagem de items em modo lista) e transformar a `TourPage` numa visita guiada de ponta a ponta: introdução em áudio da tour antes de qualquer item, areas intercaladas automaticamente na sequência com base na relação `item.area` já existente, modo lista que acompanha o passo atual, correção da sobreposição dos botões de navegação com texto longo, e persistência local do progresso com opção de retomar. A abordagem técnica assenta em três pontos: (1) estender a query de populate do Strapi já usada em `ApiHandler.js` para trazer `isMainTour`, `audioTour`, `tour.areas` e `item.area` (todos campos criados manualmente pelo utilizador como pré-requisito); (2) introduzir uma função pura `buildTourSequence()` que transforma items+areas+intro num único array ordenado de "passos", sobre o qual a `TourPage` passa a iterar (em vez de iterar diretamente `tourInfoItem`); (3) reutilizar a base de dados local `AppDB` já usada por `ApiHandler.js`/`AnalyticsHandler.js` para uma nova tabela `tour_progress`.

## Technical Context

**Language/Version**: QML/JS + C++17 (Qt 6, mobile app); TypeScript (Strapi 5, consumido apenas em leitura — sem novo código de backend nesta feature, os 3 campos de schema são criados manualmente)

**Primary Dependencies**: Qt Quick Controls 2 / Qt Quick Layouts (mobile UI), `QtQuick.LocalStorage` (SQLite embutido, persistência local), Strapi REST API existente (`/api/entidades` com populate)

**Storage**: SQLite local via `QtQuick.LocalStorage`, base de dados `AppDB` já existente (nova tabela `tour_progress`); nenhuma alteração ao Strapi além dos 3 campos manuais já combinados

**Testing**: Validação manual end-to-end (`quickstart.md`) — não há suite automatizada configurada em nenhum dos dois stacks (ver constitution)

**Target Platform**: App Qt Quick para Android (arm64-v8a, armeabi-v7a) e Desktop; backend Strapi inalterado nesta feature

**Project Type**: Mobile app (QML/C++) consumindo uma API Strapi já existente — sem novo serviço/endpoint

**Performance Goals**: Scroll da lista e transições de passo a 60fps percebidos; início da reprodução de áudio de introdução/passo sem atraso percetível (mesmo comportamento do `AudioBridge` já existente, não otimizado nesta feature)

**Constraints**: Não pode quebrar a deteção de items por código (QR/NFC/manual) já existente, que continua a operar apenas sobre passos do tipo `item`; deve continuar a funcionar offline para conteúdo já descarregado (mesmo mecanismo de cache/`FileHelper` existente)

**Scale/Scope**: Tours com dezenas de items e um pequeno número de areas associadas; um utilizador ativo por dispositivo (progresso guardado é local, não multi-utilizador)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Avaliação |
|---|---|
| I. Environment Configuration Discipline | **Pass** — nenhum novo endpoint/base URL introduzido; a query de populate estende a já existente em `ApiHandler.js`, que continua a ser o único ponto que lê `baseUrl`. |
| II. Cross-Stack Consistency | **Pass** — as novas funções de leitura (`getTourAreas`, extensão de `getTourItems`) seguem o mesmo padrão defensivo (`data.attributes \|\| data`) já usado em todas as funções de `ApiHandler.js`; nenhuma reinterpretação ad hoc da forma da resposta fora desse módulo. |
| III. Simplicity / YAGNI | **Pass** — reutiliza a tabela/base de dados local já existente em vez de criar um novo mecanismo de persistência; reutiliza o conteúdo já existente de `Area` (imagem/áudio) em vez de campos novos por combinação tour+area; substitui `Flickable`+`Repeater` por `ListView` apenas porque resolve nativamente o auto-scroll pedido, não por preferência estética. |
| IV. Maintainable Design | **Pass** — a lógica de intercalação items/areas/intro fica isolada numa única função pura (`buildTourSequence`), testável e com responsabilidade única, em vez de espalhada por condições no QML. |
| V. Spec-Driven Development | **Pass** — este plano segue spec.md já aprovada; a implementação só decorrerá após `/speckit-tasks`. |

Nenhuma violação identificada — tabela de Complexity Tracking fica vazia.

## Project Structure

### Documentation (this feature)

```text
specs/005-tours-listagem-visita-guiada/
├── plan.md              # este ficheiro
├── research.md          # decisões técnicas (Phase 0)
├── data-model.md         # entidades e fluxo de dados (Phase 1)
├── quickstart.md         # guia de validação manual (Phase 1)
└── tasks.md              # gerado por /speckit-tasks (Phase 2, ainda não criado)
```

### Source Code (repository root)

Não há contracts/ (nenhum novo endpoint/serviço — apenas a query de populate existente, já documentada em `data-model.md`).

```text
TourAssistent-main/
├── ApiHandler.js         # + getTourAreas(), extensão de getTourItems() (area por item),
│                         #   extensão de getTours() (isMainTour, audioTour),
│                         #   buildTourSequence(), saveTourProgress()/getTourProgress()/clearTourProgress()
│                         #   (nova tabela tour_progress na mesma AppDB), extensão do populate em fetchFromNetwork()
├── Tours.qml             # listagem: tour isMainTour fixa no topo + layout alinhado com o modo lista de items
├── TourPage.qml          # passa a iterar sobre "passos" (intro/item/area) em vez de só items;
│                         #   ListView com positionViewAtIndex no modo lista; correção do bottomMargin
│                         #   do modo Guia; diálogo de retomar progresso ao abrir; grava progresso ao sair/concluir
└── main.qml               # sem alterações estruturais esperadas (appData continua a expor tours/items/areas)

backend/app/
└── (sem alterações de código nesta feature — os 3 campos de schema são criados manualmente no Strapi
    pelo utilizador antes da implementação, conforme documentado em spec.md § Assumptions)
```

**Structure Decision**: Toda a implementação fica no lado mobile (`TourAssistent-main/`), concentrada em `ApiHandler.js` (dados/lógica de sequência/persistência) e `Tours.qml`/`TourPage.qml` (UI). O backend não é tocado por código nesta feature — apenas consome os 3 campos criados manualmente no Strapi, através de uma extensão da query de populate já existente.

## Complexity Tracking

*Sem violações da Constitution Check — tabela não aplicável nesta feature.*
