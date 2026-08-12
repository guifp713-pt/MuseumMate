# Phase 0 Research: Tours — Listagem e Visita Guiada

## 1. Como identificar a area de cada item de uma tour

**Decision**: Popular diretamente `item.area` dentro do ramo `tours.items` da query de populate do Strapi (`populate[tours][populate][items][populate][area]=true`), e propagar `areaDocumentId`/`nameArea` para cada item devolvido por `getTourItems()`.

**Rationale**: A alternativa óbvia — cruzar cada item da tour com a lista global de items (`getItems()`, que já conhece a area de cada item via a árvore `maps→areas→items`) por `documentId` — funciona, mas obriga a manter dois percursos de dados sincronizados e é mais frágil a mudanças futuras no catálogo. Popular `area` diretamente no ramo da tour dá o dado de forma direta, sem lookup cruzado, e seguindo o mesmo padrão defensivo (`data.attributes || data`) já usado em todo o `ApiHandler.js`.

**Alternatives considered**: Lookup cruzado via `getItems()` global — rejeitado por introduzir uma dependência implícita entre duas funções que hoje são independentes (viola a Constitution II — normalizar a um único ponto, não reinterpretar ad hoc).

## 2. Como decidir onde inserir cada "passo de area" na sequência

**Decision**: Construir a sequência da visita como uma função pura `buildTourSequence(tourAudioTour, tourItems, tourAreas)` que devolve um array de "passos" (`{type: 'intro'|'item'|'area', ...}`), percorrendo `tourItems` em ordem e inserindo um passo `area` sempre que `item.areaDocumentId` mudar em relação ao passo anterior **e** essa area constar em `tourAreas` (a relação `tour.areas`, populada com `documentId`).

**Rationale**: É a leitura direta do requisito confirmado com o utilizador ("a area entra automaticamente antes dos items que pertencem a essa area"). Isolar isto numa função pura (sem estado, sem side effects) permite testar a lógica de intercalação isoladamente do QML, e mantém uma única responsabilidade (Constitution IV).

**Alternatives considered**: Guardar a posição de cada area manualmente (dynamic zone) — já descartado com o utilizador por complexidade desnecessária face à necessidade real.

## 3. Numeração dos passos (Paragem 1, 2, 3…) face à introdução e às areas

**Decision**: A introdução da tour (`audioTour`) não conta para a numeração de paragens nem para os pontos/barra de progresso — é um passo `intro` antes do passo 1. Passos do tipo `area` **contam** como paragens normais na numeração e na barra de progresso, tal como os items.

**Rationale**: A introdução é conceptualmente "antes da visita começar" (o utilizador já validou o fluxo: intro → depois segue sequencialmente); tratar areas como paragens normais evita ter duas escalas de contagem diferentes e mantém a UI existente (barra de progresso, pontos) a funcionar sem alterações estruturais — só o array subjacente muda de "items" para "passos".

**Alternatives considered**: Não contar areas como paragens (mostrá-las "fora" da contagem) — rejeitado por complicar a UI de progresso sem benefício claro para o visitante.

## 4. Onde e como persistir o progresso da tour

**Decision**: Reutilizar a base de dados local já existente `AppDB` (QtQuick.LocalStorage), acedida a partir de `ApiHandler.js` (que já a abre para a tabela `cache`), acrescentando uma tabela `tour_progress(tourDocumentId TEXT PRIMARY KEY, stepType TEXT, stepDocumentId TEXT, updatedAt TEXT)`. Duas funções novas em `ApiHandler.js`: `saveTourProgress(tourDocumentId, stepType, stepDocumentId)` / `getTourProgress(tourDocumentId)` / `clearTourProgress(tourDocumentId)`.

**Rationale**: `ApiHandler.js` já é importado por `TourPage`/`Tours.qml` (reutilizado também por `AnalyticsHandler.js` e `AssistantHandler.js` para o `baseUrl`, por instrução explícita do `CLAUDE.md` de nunca duplicar uma terceira cópia de estado partilhado). Acrescentar a tabela ali, em vez de abrir uma quarta base de dados ou um quarto ficheiro com acesso a `LocalStorage`, seguindo o mesmo padrão do `app_settings` já usado pelo `AnalyticsHandler.js` para o ID do dispositivo.

**Alternatives considered**: Guardar o progresso num novo ficheiro/módulo dedicado — rejeitado por duplicar o padrão de acesso a `AppDB` já estabelecido (Constitution I/II).

## 5. Identificar a posição guardada em vez do índice numérico

**Decision**: Guardar o `documentId` (e tipo) do passo onde o visitante ficou, não o índice numérico (`contadorParagens`). Ao reabrir, procurar esse `documentId` na sequência recém-construída; se não existir mais (conteúdo removido/alterado), reiniciar do início (FR-013).

**Rationale**: O índice numérico depende da forma atual do catálogo (quantos items/areas existem e por que ordem); se o catálogo mudar entre visitas, o índice guardado pode apontar para um passo errado ou inexistente. O `documentId` é estável e permite validar explicitamente se o passo ainda existe.

**Alternatives considered**: Guardar o índice numérico — mais simples de implementar mas viola diretamente o requisito de robustez a conteúdo alterado (edge case já identificado na spec).

## 6. Modo lista: auto-scroll para o item atual

**Decision**: Substituir o `Flickable` + `Repeater` atual do modo lista (`scrollAreaLista`/`contentColumnList` em `TourPage.qml`) por um `ListView`, e usar `positionViewAtIndex(index, ListView.Contain)` sempre que `contadorParagens` mudar.

**Rationale**: `ListView` é o mecanismo nativo do Qt Quick para esta necessidade exata e já é o padrão usado na listagem de tours (`Tours.qml`) e seria o padrão a adotar também na listagem de items em modo lista (requisito de consistência visual, FR-002). Calcular manualmente o `contentY` a partir de alturas fixas (`height: 100`, `spacing: 15`) funcionaria mas duplicaria lógica que o `ListView` já resolve, e quebraria assim que o layout do cartão mudasse de altura (ex.: texto mais longo) — mais frágil e menos alinhado com o Constitution III (preferir a solução mais simples que garanta o comportamento esperado).

**Alternatives considered**: Cálculo manual de `contentY` sobre o `Flickable` existente — rejeitado por ser mais frágil a mudanças de layout e por duplicar funcionalidade nativa do `ListView`.

## 7. Modo Guia: botões de navegação a sobrepor texto longo

**Decision**: O `Flickable`/`Column` de conteúdo do modo Guia (`scrollArea`/`contentColumn`) já reserva espaço inferior via `anchors.bottomMargin` quando o `miniPlayer` está visível (`miniPlayer.height + 30`), mas não reserva espaço para os botões `backStopTrue`/`nextStop` quando estes estão visíveis (modo Guia com `miniPlayer` escondido). A correção é fazer esse `bottomMargin` refletir também a altura dos botões de navegação nesse modo (`nextStop.height + 40` ou equivalente), garantindo que o texto pode sempre fazer scroll até ficar totalmente acima dos botões.

**Rationale**: É a causa raiz identificada diretamente no código — não sobreposição visual acidental, mas uma margem que nunca contabilizou os botões de navegação porque foram adicionados depois. Corrigir a margem é a alteração mínima que resolve o requisito (Constitution III).

**Alternatives considered**: Reduzir o tamanho do texto ou truncar — rejeitado por a spec exigir que o texto completo permaneça legível independentemente do comprimento.

## Summary of unresolved NEEDS CLARIFICATION

Nenhum. Todas as decisões técnicas necessárias para o desenho desta feature foram resolvidas acima com base no código existente e nas confirmações já obtidas do utilizador durante a fase de especificação.
