# Feature Specification: Tours — Listagem e Visita Guiada

**Feature Branch**: `005-tours-listagem-visita-guiada`

**Created**: 2026-07-29

**Status**: Draft

**Input**: User description: "005-tours-listagem-e-visita-guiada — Contexto: continuação do 'Melhorias finais do Sistema' da app Museum Mate (TourAssistent-main + backend Strapi). Este spec cobre a listagem de Tours e a experiência de visita guiada na TourPage: tour 'museu completo' fixa no topo com layout renovado; introdução em áudio da tour tocada antes dos items; areas incluídas na sequência guiada com posicionamento automático; auto-scroll da lista para o item atual; correção da sobreposição dos botões de navegação com texto longo; guardar e retomar progresso da visita."

## Context

Este é o primeiro de vários specs combinados com o utilizador para o conjunto de "Melhorias finais do Sistema" (os restantes — áudio/mini-player, polimento de UI, FAQ do assistente, dashboard — ficam para specs seguintes e estão fora de âmbito aqui).

Três campos de conteúdo são pré-requisito desta feature e são criados manualmente pelo utilizador no Strapi antes da implementação (fora do âmbito deste spec, tratados como dados de entrada já disponíveis):
- `tour.isMainTour` — sinalizador da tour que representa a visita completa ao museu.
- `tour.areas` — associação da tour a areas do museu.
- `tour.audioTour` — áudio de introdução da tour.

A relação já existente entre um item e a sua area (`item.area`) é reutilizada para decidir automaticamente onde inserir cada area na sequência da visita.

## Clarifications

### Session 2026-07-29

- Q: Se a sequência de items da tour voltar a uma area já visitada (percurso não contíguo, ex.: Area A → Area B → Area A outra vez), o passo dedicado dessa area deve repetir-se? → A: Sim — repete sempre que a area mudar em relação ao passo anterior, mesmo que já tenha aparecido antes na mesma visita.
- Q: Se o áudio de um passo (introdução, area ou item) não estiver disponível em runtime (falha de download, ainda não sincronizado offline), o que deve acontecer? → A: Mostrar o passo normalmente (texto/imagem) sem reproduzir áudio, sem bloquear nem mostrar erro — mesmo comportamento já existente hoje para items sem áudio definido.
- Q: Ao escolher "Continuar a partir de [passo X]" no diálogo de retomar, o áudio desse passo deve tocar automaticamente? → A: Sim — arranca automaticamente, igual a qualquer navegação normal dentro da tour.
- Q: Se, por engano de configuração, mais do que uma tour estiver marcada `isMainTour` em simultâneo, o que a app deve fazer? → A: Fixar apenas a primeira encontrada na resposta da API; as restantes aparecem como tours normais (sem critério de desempate adicional).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Visita guiada sem esforço (Priority: P1)

Como visitante, ao selecionar uma tour quero ser conduzido passo a passo — primeiro uma introdução que me diz do que se trata a visita, depois cada paragem em sequência — sem ter de decidir por onde começar ou o que vem a seguir.

**Why this priority**: É o núcleo da mudança pedida: a TourPage deixa de abrir "a meio" (no primeiro item) e passa a ter um início claro. Sem isto, nenhuma das restantes melhorias (areas, retomar progresso) faz sentido.

**Independent Test**: Selecionar uma tour com áudio de introdução definido; confirmar que a introdução é mostrada e reproduzida antes de qualquer item, e que ao terminar a introdução a visita avança automaticamente para o primeiro passo da sequência.

**Acceptance Scenarios**:

1. **Given** uma tour com áudio de introdução configurado, **When** o visitante a seleciona, **Then** a TourPage abre mostrando e a reproduzir a introdução, com o mesmo tipo de ecrã usado para um item.
2. **Given** o visitante está a ouvir/ver a introdução, **When** avança manualmente ou a reprodução termina, **Then** a visita segue para o primeiro item (ou area, se aplicável) da sequência.
3. **Given** uma tour sem áudio de introdução configurado, **When** o visitante a seleciona, **Then** a visita começa diretamente no primeiro passo da sequência, sem ecrã vazio nem bloqueio.

---

### User Story 2 - Encontrar rapidamente a visita completa ao museu (Priority: P1)

Como visitante, quero identificar de imediato, na lista de tours, qual delas percorre o museu inteiro, e quero que a lista de tours seja tão clara de ler como a lista de items que já conheço da TourPage.

**Why this priority**: É a primeira decisão que o visitante toma (qual tour escolher) e a atual listagem é pouco clara; corrigir isto tem impacto imediato e não depende de nenhuma outra história.

**Independent Test**: Com uma tour marcada como "museu completo" e várias outras tours normais, abrir a lista de tours e confirmar que a tour marcada aparece sempre em primeiro lugar, visualmente destacada, e que todas as tours usam o layout de lista já usado para items.

**Acceptance Scenarios**:

1. **Given** existe uma tour marcada como "museu completo", **When** o visitante abre a lista de tours, **Then** essa tour aparece fixa na primeira posição, distinguível das restantes.
2. **Given** nenhuma tour está marcada como "museu completo", **When** o visitante abre a lista de tours, **Then** a lista é apresentada normalmente, sem nenhuma posição fixa nem destaque.
3. **Given** a lista de tours é apresentada, **When** o visitante a compara com a listagem de items em modo lista da TourPage, **Then** ambas seguem o mesmo estilo visual (mesmo tipo de cartão/linha, imagem, título e informação secundária).

---

### User Story 3 - Contexto de deslocação entre areas (Priority: P2)

Como visitante numa tour que atravessa várias zonas do museu, quero ser avisado e contextualizado antes de chegar a uma nova zona, para saber que me devo deslocar e para onde.

**Why this priority**: Acrescenta valor real à visita guiada mas só faz sentido depois de existir uma sequência guiada (User Story 1); tours sem areas associadas continuam a funcionar sem esta história.

**Independent Test**: Construir uma tour cujos items pertencem a duas areas diferentes, com ambas as areas associadas à tour; percorrer a visita e confirmar que, mesmo antes do primeiro item da segunda area, é apresentado um passo dedicado a essa area (imagem/áudio da area).

**Acceptance Scenarios**:

1. **Given** uma tour associada a uma area, **When** a sequência da visita chega ao primeiro item dessa area (sendo diferente da area do passo anterior), **Then** é apresentado antes um passo dedicado a essa area, com o seu conteúdo (imagem/áudio) próprio.
2. **Given** uma area está associada à tour mas nenhum item da sequência pertence a essa area, **When** a visita é percorrida do início ao fim, **Then** essa area nunca é apresentada.
3. **Given** dois items consecutivos pertencem à mesma area, **When** a visita avança de um para o outro, **Then** não é repetido nenhum passo de area entre eles.

---

### User Story 4 - Retomar uma visita interrompida (Priority: P2)

Como visitante que fecha a aplicação a meio de uma visita (por exemplo, para atender uma chamada), quero poder continuar depois exatamente de onde fiquei, sem ter de encontrar manualmente o item onde estava.

**Why this priority**: Resolve uma frustração real em visitas longas, mas é independente da introdução e das areas — pode ser testada e entregue por si só.

**Independent Test**: Abrir uma tour, avançar até um item intermédio, fechar a TourPage, reabrir a mesma tour e confirmar que é oferecida a opção de continuar a partir desse item ou recomeçar.

**Acceptance Scenarios**:

1. **Given** o visitante fecha a TourPage a meio de uma tour, **When** reabre essa mesma tour mais tarde, **Then** é apresentada uma escolha entre "continuar a partir de [ponto guardado]" e "começar do início".
2. **Given** essa escolha é apresentada, **When** o visitante escolhe continuar, **Then** a visita retoma exatamente no item/area guardado e o respetivo áudio começa a tocar automaticamente, tal como aconteceria ao navegar normalmente para esse passo.
3. **Given** essa escolha é apresentada, **When** o visitante escolhe começar do início, **Then** o progresso guardado é apagado e a visita segue o fluxo normal de introdução/primeiro passo.
4. **Given** o visitante conclui uma tour até ao último passo, **When** volta a abrir essa tour mais tarde, **Then** não lhe é oferecida a opção de continuar (o progresso concluído não conta como interrompido).

---

### User Story 5 - Acompanhar a visita sem se perder (Priority: P3)

Como visitante numa tour com muitos items, quero que a lista acompanhe automaticamente o ponto onde estou, e quero que o texto de cada paragem seja sempre legível, sem botões a tapá-lo.

**Why this priority**: São correções de conforto/usabilidade que melhoram a experiência mas não bloqueiam o uso da funcionalidade principal mesmo que cheguem depois.

**Independent Test**: Numa tour com muitos items, avançar repetidamente pelo botão de navegação em modo lista e confirmar que o item atual está sempre visível sem scroll manual; separadamente, abrir em modo Guia um item com texto muito longo e confirmar que os botões de navegação nunca cobrem o texto.

**Acceptance Scenarios**:

1. **Given** uma tour com mais items do que cabem no ecrã em modo lista, **When** o visitante avança ou recua pela visita, **Then** a lista desloca-se automaticamente para manter o item atual visível.
2. **Given** um item ou area com texto descritivo longo, **When** apresentado em modo Guia, **Then** os botões de anterior/próximo nunca se sobrepõem ao texto, independentemente do comprimento.

---

### Edge Cases

- Tour sem `audioTour` definido: a visita começa diretamente no primeiro passo, sem ecrã de introdução vazio (coberto em US1).
- Nenhuma tour marcada como `isMainTour`: a listagem funciona normalmente, sem nenhuma posição fixa (coberto em US2).
- Mais do que uma tour marcada como `isMainTour` em simultâneo: apenas a primeira encontrada na resposta da API é fixa no topo; as restantes aparecem como tours normais.
- Area associada à tour sem nenhum item correspondente na sequência: nunca é apresentada (coberto em US3).
- Progresso guardado aponta para um item/area entretanto removido ou alterado no catálogo: a visita recomeça do início em vez de falhar ou bloquear.
- Visitante conclui a tour até ao fim: o progresso guardado é limpo, não sendo oferecida a opção de "continuar" numa visita já terminada.
- Visitante muda de idioma a meio de uma visita guardada: o progresso mantém-se válido (identifica o passo, não o texto/idioma apresentado).
- Áudio de um passo (introdução, area ou item) indisponível em runtime (falha de download, conteúdo ainda não sincronizado offline): o passo é apresentado normalmente (texto/imagem), sem áudio e sem erro visível — mesmo comportamento já existente hoje para items sem áudio definido.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST apresentar, na listagem de tours, a tour marcada como "tour do museu completo" sempre fixa na primeira posição, visualmente destacada das restantes. Se mais do que uma tour estiver marcada em simultâneo, apenas a primeira encontrada na resposta da API é fixa; as restantes marcadas aparecem como tours normais.
- **FR-002**: O sistema MUST apresentar a listagem de tours (destacada ou não) usando o mesmo estilo visual já usado na listagem de items em modo lista da TourPage.
- **FR-003**: Ao abrir uma tour sem progresso guardado, o sistema MUST apresentar primeiro o áudio de introdução da tour (quando definido), com o mesmo tipo de ecrã usado para um item, antes de avançar para o primeiro passo da sequência.
- **FR-004**: Se a tour não tiver áudio de introdução definido, o sistema MUST avançar diretamente para o primeiro passo da sequência, sem ecrã vazio nem bloqueio.
- **FR-005**: O sistema MUST inserir automaticamente, na sequência da visita, um passo dedicado a cada area associada à tour, imediatamente antes do item seguinte, sempre que a area desse item for diferente da area do passo imediatamente anterior — incluindo repetições da mesma area quando o percurso não é contíguo (ex.: Area A → Area B → Area A outra vez insere o passo da Area A nas duas ocasiões).
- **FR-006**: O sistema MUST NOT apresentar areas associadas à tour que não tenham nenhum item correspondente na sequência da visita.
- **FR-007**: Em modo lista, o sistema MUST manter o item/area atual visível na lista ao avançar ou recuar na visita, deslocando a lista automaticamente quando necessário.
- **FR-008**: Em modo Guia, o sistema MUST garantir que os controlos de navegação (anterior/próximo) nunca se sobrepõem ao texto descritivo do passo atual, independentemente do comprimento desse texto.
- **FR-009**: Ao sair da TourPage a meio de uma visita, o sistema MUST guardar localmente, por tour e por dispositivo, o passo (item ou area) onde o visitante ficou.
- **FR-010**: Ao reabrir uma tour com progresso guardado e não concluído, o sistema MUST apresentar uma escolha explícita entre continuar a partir do passo guardado ou começar do início.
- **FR-011**: Escolher "começar do início" MUST apagar o progresso previamente guardado dessa tour.
- **FR-012**: Ao concluir uma tour até ao último passo, o sistema MUST apagar o progresso guardado dessa tour.
- **FR-013**: Se o passo guardado já não corresponder a nenhum item/area existente no catálogo atual, o sistema MUST reiniciar a visita a partir do início em vez de falhar.
- **FR-014**: Se o áudio de um passo não estiver disponível em runtime, o sistema MUST apresentar esse passo normalmente (texto/imagem) sem áudio, sem bloquear a navegação nem mostrar um erro ao visitante.

### Key Entities *(include if feature involves data)*

- **Tour**: passa a distinguir-se por um sinalizador de "tour principal" (museu completo), um áudio de introdução, e uma associação a areas — além dos items que já tinha.
- **Passo de visita**: unidade lógica da sequência guiada; pode ser um item ou uma area, apresentado com conteúdo próprio (texto/imagem/áudio).
- **Progresso de tour**: registo local, por dispositivo e por tour, que identifica o último passo visitado; é apagado ao concluir a tour ou ao escolher recomeçar.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ao abrir a lista de tours, o visitante identifica a visita completa ao museu de imediato — está sempre na primeira posição, em 100% das configurações com uma tour principal definida.
- **SC-002**: Em 100% das visitas a tours com áudio de introdução configurado, esse áudio é apresentado e reproduzido antes de qualquer item.
- **SC-003**: Numa visita com pelo menos 20 items, o item atual permanece visível na lista em 100% dos avanços/recuos, sem necessidade de scroll manual.
- **SC-004**: Em modo Guia, para o texto mais longo existente no catálogo, os botões de navegação não cobrem nenhuma parte do texto.
- **SC-005**: Um visitante que feche a aplicação a meio de uma tour e a reabra no mesmo dispositivo consegue retomar exatamente no último passo em 100% dos casos testados.

## Assumptions

- Os campos `tour.isMainTour`, `tour.areas` e `tour.audioTour` já existem no Strapi antes da implementação desta feature (criados manualmente); este spec trata-os como dados de entrada disponíveis, não como trabalho a implementar.
- O progresso da visita é guardado apenas localmente no dispositivo, usando o mesmo mecanismo de persistência local já existente na app — não é sincronizado entre dispositivos nem enviado ao backend.
- Espera-se no máximo uma tour marcada como "museu completo" de cada vez; garantir essa unicidade na configuração do Strapi está fora do âmbito deste spec, mas o comportamento da app nesse cenário de configuração incorreta está definido (FR-001).
- O passo dedicado a uma area reutiliza o conteúdo (imagem/áudio) já existente nessa area, sem necessidade de texto ou áudio adicional específico da combinação tour+area.
- Novos conteúdos (áudio de introdução da tour) seguem o mesmo mecanismo de tradução/idioma já usado no resto do catálogo.
- Fora de âmbito deste spec: controlo funcional da barra de progresso de áudio e do mini-player (app e notificação em tempo real), cores/contraste da HomePage, botão flutuante do chat IA noutras páginas, campo de FAQ da Entity para a IA, e correções do dashboard de analytics — tratados em specs seguintes já combinados com o utilizador.
