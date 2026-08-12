# Quickstart: Validar Tours — Listagem e Visita Guiada

Sem suite de testes automatizados neste repositório (ver constitution — "Development Workflow & Quality Gates"). Validação end-to-end manual, seguindo os cenários de aceitação de `spec.md`.

## Pré-requisitos

1. No Strapi (`backend/app/`), confirmar que os três campos manuais já existem no content-type `tour` (ver `data-model.md`): `isMainTour` (boolean), `areas` (relation → Area), `audioTour` (media, i18n).
2. Configurar dados de teste numa entidade ativa (`config/museum.ts`):
   - Marcar **uma** tour como `isMainTour = true`.
   - Nessa tour (ou noutra), definir `audioTour` com um ficheiro de áudio curto.
   - Associar a essa tour pelo menos uma `area` (via `areas`) cujos `items` já estejam incluídos na relação `items` da mesma tour.
   - Ter pelo menos uma segunda tour sem `isMainTour` nem `audioTour`, para validar os caminhos "sem".
3. Arrancar o backend: `cd backend/app && npm run develop`.
4. Confirmar `ApiHandler.js`/`AnalyticsHandler.js` `baseUrl` apontam para o backend acima (mesma rede).
5. Compilar e correr a app mobile (Qt Creator, kit Desktop ou Android) apontando para essa configuração.

## Cenários de validação

### 1. Listagem de tours (US2 / FR-001, FR-002)

- Abrir a lista de tours.
- **Esperado**: a tour marcada `isMainTour` aparece em primeiro lugar, visualmente destacada; as restantes seguem por baixo no mesmo estilo de cartão já usado para a listagem de items em modo lista da TourPage.
- Repetir sem nenhuma tour marcada `isMainTour` → lista normal, sem destaque nem reordenação especial.

### 2. Introdução em áudio (US1 / FR-003, FR-004)

- Selecionar a tour com `audioTour` definido.
- **Esperado**: a TourPage abre já a reproduzir a introdução, ecrã no mesmo estilo do de um item; ao terminar/avançar, segue para o passo 1.
- Selecionar uma tour sem `audioTour`.
- **Esperado**: abre diretamente no passo 1, sem ecrã vazio.

### 3. Areas na sequência (US3 / FR-005, FR-006)

- Percorrer a tour configurada com area(s) associada(s).
- **Esperado**: antes do primeiro item de cada area associada, aparece um passo dedicado a essa area (imagem/áudio da area); items subsequentes da mesma area não repetem o passo.
- Remover a associação `tour.areas` para essa area (mantendo os items) e repetir.
- **Esperado**: a area deixa de aparecer na sequência.

### 4. Modo lista acompanha o item atual (US5 / FR-007)

- Numa tour com items suficientes para não caberem todos no ecrã, avançar repetidamente pelo botão "Próximo" com o modo lista ativo.
- **Esperado**: o item realçado permanece sempre visível, sem necessidade de arrastar manualmente a lista.

### 5. Botões não sobrepõem texto longo (US5 / FR-008)

- Em modo Guia, navegar até ao item/area com o texto descritivo mais longo do catálogo de teste.
- **Esperado**: com scroll até ao fim do texto, nenhuma parte fica coberta pelos botões "Anterior"/"Próximo".

### 6. Retomar progresso (US4 / FR-009 a FR-013)

- Abrir uma tour, avançar até um passo intermédio, fechar a TourPage (botão "x").
- Reabrir a mesma tour.
- **Esperado**: diálogo com "Continuar a partir de [passo]" / "Começar do início".
- Escolher "Continuar" → retoma exatamente nesse passo.
- Repetir, mas escolher "Começar do início" → reinicia (intro, se existir; senão passo 1) e o progresso anterior deixa de ser oferecido numa próxima reabertura.
- Concluir uma tour até ao fim, reabri-la → **não** deve ser oferecida a opção de continuar.
- (Opcional, edge case) Editar o item/area guardado como progresso no Strapi para outro documentId ou apagá-lo, reabrir a app → deve reiniciar do início sem erro.

## Critério de aceitação da fase

Todos os 6 cenários acima passam manualmente antes de `tasks.md` ser considerado concluído para esta feature.
