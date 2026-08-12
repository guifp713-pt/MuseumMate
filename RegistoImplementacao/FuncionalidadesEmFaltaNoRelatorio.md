# Plano de Integração: Funcionalidades do Museum Mate por Documentar no Relatório

> **Estado: INTEGRADO no `RelatórioEstágio.docx` em 2026-07-28.** As 6 funcionalidades abaixo
> foram inseridas no documento real, seguindo exatamente a localização e o conteúdo descritos
> neste plano, através de automação via Word (com verificação de integridade — nenhuma imagem
> existente foi tocada). Backup do documento original antes da alteração:
> `RelatórioEstágio.docx.backup-20260728-163655`. Este ficheiro mantém-se como registo de
> auditoria do que foi decidido e porquê; ver notas de estado por secção abaixo.
>
> **Pendente de ação manual do autor:** dois marcadores de figura foram deixados no texto como
> `[Figura a inserir aqui: ...]` (em 4.6 e 4.9) — precisam de ser substituídos por capturas de
> ecrã reais e pela respetiva legenda/numeração de figura no Word. Rever também o tom das duas
> secções novas mais extensas (3.3.9 e 4.9) antes da entrega final.

Este documento resulta de uma comparação entre o `RelatórioEstágio.docx` (capítulos 1 a 4, com
foco nas secções 3.3 "Projeto Museum Mate" e 4 "Desenvolvimento do Frontend") e o estado atual
do sistema. Deixou de ser apenas uma lista de funcionalidades em falta e passa a ser um plano
de integração: para cada funcionalidade indica-se onde entra no relatório, o que deve e não
deve ser explicado, e os benefícios a fechar o texto — para que a fase de implementação da spec
`005-Relatorio` possa avançar com autonomia, seguindo sempre a skill `Relatorios`.

Não aborda secções administrativas do documento (agradecimentos, resumo, reuniões em falta,
etc.), apenas conteúdo relativo ao projeto em si.

---

## O que já está bem coberto (para referência, não precisa de alterações)

- Mapas, áreas, itens, circuitos/tours e dicionário multi-idioma no Strapi.
- Leitura de QR code e introdução manual de código, descritas a partir da HomePage.
- Áudio-guia com reprodução em segundo plano (Foreground Service).
- Cache offline e download automático de multimédia.
- Internacionalização dinâmica (PT/EN/ES/FR).
- CMS Strapi, Docker, backups e geração automática de QR ao criar um item.
- Dashboard de estatísticas no Strapi.

---

## Nota técnica encontrada na reanálise

A secção **"3.3.6 Contentorização e Infraestrutura com Docker"** repete o número já usado por
**"3.3.6 Planeamento da Solução"** — é um erro de numeração já existente no documento atual,
independente destas novas funcionalidades. Aproveitar a integração do ponto 6 (metodologia de
desenvolvimento) para corrigir esta numeração, já que é inserido exatamente a seguir ao Docker.

---

## Mapa de integração proposto (índice atualizado)

Para evitar contradições entre funcionalidades diferentes que tocam nas mesmas secções, este é
o índice-alvo depois de todas as integrações abaixo estarem feitas:

**Capítulo 3.3 (Projeto Museum Mate):**
`3.3.1` Introdução → `3.3.2` Problema Identificado → `3.3.3` Objetivo da aplicação → `3.3.4`
Requisitos do Sistema (expandida) → `3.3.5` Arquitetura Geral do Sistema (expandida com
Configuração de Museu Ativo) → `3.3.6` Planeamento da Solução → `3.3.7` Arquitetura Headless
CMS com Strapi (expandida com Map Pin Picker) → **`3.3.8` Contentorização e Infraestrutura com
Docker** (renumerada, corrige o erro acima) → **`3.3.9` Metodologia de Desenvolvimento:
Spec-Driven Development e Assistência de IA (NOVA)**.

**Capítulo 4 (Desenvolvimento do Frontend):**
`4.3` main.qml → `4.4` WelcomePage.qml → `4.5` HomePage.qml (4.5.4 simplificada, remete para
4.6) → **`4.6` Identificação de Obras: Scanner, Código Manual e NFC (NOVA)** → `4.7` Tours.qml
(renumerada de 4.6) → `4.8` TourPage.qml (renumerada de 4.7) → **`4.9` Assistente Virtual
(ChatIAPanel.qml) (NOVA)**.

---

## 1. Assistente Virtual com Inteligência Artificial (maior lacuna)

Esta é a funcionalidade mais significativa que falta no relatório — não é mencionada em
nenhum ponto do documento atual, apesar de ser uma componente central do projeto.

**Localização prevista**
- Capítulo: 4 — Desenvolvimento do Frontend
- Secção: nova `4.9 Assistente Virtual (ChatIAPanel.qml)`, a seguir a TourPage.qml (ver Mapa
  de integração acima)
- Criar nova secção? Sim — segue o padrão já usado em 4.3-4.8 ("um QML principal = uma secção")
- Expandir secção existente? Sim, pontualmente: 3.3.4 (novo bullet nos requisitos funcionais) e
  3.3.7 (nota sobre os novos `eventType` `assistant_*` na coleção AnalyticsEvent)
- Atualizar requisitos funcionais? Sim
- Atualizar índice? Sim
- Atualizar referências cruzadas? Sim — 4.4, 4.5 e 4.8 devem remeter para 4.9, já que o botão
  do chat está disponível em várias páginas, não só numa
- Necessita de figura? Sim
- Legenda sugerida: "Figura X - Painel do Assistente Virtual (ChatIAPanel.qml)"; opcionalmente
  uma segunda "Figura Y - Fluxo de decisão do Assistente"
- Local exato onde a figura deverá ser inserida: depois do parágrafo que descreve o fluxo de
  decisão (catálogo suficiente → resposta direta; sem catálogo mas dentro do tema → resposta de
  conhecimento geral sinalizada; fora do tema → recusa), antes da lista de vantagens

**Objetivo**: permitir que o visitante obtenha respostas imediatas sobre o museu, em linguagem
natural, sem ter de navegar manualmente pelo mapa ou pelos itens.

**Problema que resolveu**: nem todas as dúvidas de um visitante cabem num mapa ou numa ficha de
item fixa; procurar informação dispersa por vários ecrãs quebra a experiência da visita.

**Porque foi necessária**: a app já reunia todo o catálogo estruturado no backend, mas não
havia forma de o consultar de forma livre e conversacional.

**O que deve ser explicado**: onde o botão aparece (várias páginas), que tipo de perguntas
responde, como recusa educadamente perguntas fora do tema, a tradução automática de conteúdo
que só existe em português, a resposta de "conhecimento geral" sempre sinalizada como não
verificada, e o registo anónimo de estatísticas de utilização.

**O que não deve ser explicado**: nomes de ficheiros/funções internas, detalhes de prompts ou
de esquemas JSON, o nome exato do modelo de IA usado (referir apenas como nota lateral, se
necessário) — manter o foco no comportamento visível ao visitante (secção 6 da skill).

**Benefícios obtidos**: o visitante ganha autonomia para tirar dúvidas específicas sem procurar
manualmente; a administração ganha visibilidade sobre lacunas do catálogo através das
estatísticas de perguntas sem resposta.

---

## 2. Leitura de Tags NFC

**Localização prevista**
- Capítulo: 4
- Secção: integra a nova secção `4.6` (Scanner, ver funcionalidade 3) — não justifica secção
  própria, é uma funcionalidade irmã do QR
- Criar nova secção? Não
- Expandir secção existente? Sim — 3.3.4 (novo bullet "Leitura de Tags NFC")
- Atualizar requisitos funcionais? Sim
- Atualizar índice? Sim (por via da criação de 4.6, funcionalidade 3)
- Atualizar referências cruzadas? Sim
- Necessita de figura? Não em separado — pode partilhar a figura do Scanner (funcionalidade 3)
  com uma nota "ou por leitura NFC"
- Legenda sugerida: partilhada com a funcionalidade 3
- Local exato: dentro do parágrafo que descreve os métodos de identificação de obra, logo a
  seguir ao QR

**Objetivo**: dar ao visitante uma segunda forma, mais rápida, de identificar uma obra —
encostar o telemóvel em vez de apontar a câmara.

**Problema que resolveu**: em espaços com pouca luz, distância curta entre obras, ou para
visitantes com dificuldade em enquadrar a câmara, a leitura de QR pode ser lenta ou falhar.

**Porque foi necessária**: reforça a robustez do mecanismo de identificação de obras sem
depender de uma única tecnologia.

**O que deve ser explicado**: o gesto (encostar o telemóvel), o resultado (abre a informação do
item), e que é uma alternativa — não substitui o QR.

**O que não deve ser explicado**: a API JNI Android, o nome da classe `NfcManager`, o parsing
do payload NDEF.

**Benefícios obtidos**: leitura mais rápida e acessível para visitantes com destreza reduzida
ou em más condições de luz.

---

## 3. Ecrã de Scanner dedicado e acesso a partir de várias páginas

O relatório atual descreve a leitura de QR apenas como parte da HomePage (4.5.4), o que não
reflete que o mecanismo está disponível a partir de várias páginas e inclui alternativas ao QR.

**Localização prevista**
- Capítulo: 4
- Secção: nova `4.6 Identificação de Obras: Scanner (ScannerPage.qml)`, inserida entre a atual
  4.5 (HomePage) e a atual 4.6 (Tours.qml — passa a 4.7)
- Criar nova secção? Sim
- Expandir secção existente? Sim, em simultâneo — encurtar 4.5.4 (HomePage) para mencionar
  apenas o botão de acesso rápido, remetendo o funcionamento completo para 4.6
- Atualizar requisitos funcionais? Sim — clarificar que QR, NFC e código manual são três formas
  do mesmo mecanismo de identificação
- Atualizar índice? Sim
- Atualizar referências cruzadas? Sim — 4.4 (Welcome), 4.5 (Home) e 4.8 (TourPage, renumerada)
  passam a remeter para 4.6 em vez de repetir a explicação
- Necessita de figura? Sim
- Legenda sugerida: "Figura X - Ecrã de Scanner: leitura de QR, código manual e NFC"
- Local exato: depois do parágrafo que descreve o funcionamento conjunto dos três métodos,
  antes da lista de vantagens

**Objetivo**: oferecer um único ponto de entrada, acessível de qualquer página, para identificar
uma obra por QR, código manual de 4 dígitos ou NFC.

**Problema que resolveu**: o relatório atual dá a entender que a leitura de QR só existe dentro
do mapa; na realidade é um mecanismo transversal à aplicação.

**Porque foi necessária**: consistência de acesso — o visitante não deve ter de voltar ao mapa
só para identificar uma obra.

**O que deve ser explicado**: os três métodos de identificação, o pedido de permissão de
câmara e o que acontece se for recusada, e que o botão está acessível em várias páginas.

**O que não deve ser explicado**: a biblioteca QZXing ao nível de implementação (já referida em
4.5.4 no relatório atual, não repetir), nem o código Android de permissões.

**Benefícios obtidos**: identificação de obras mais rápida e flexível, com continuidade de
acesso independentemente do ecrã onde o visitante está.

---

## 4. Ferramenta de administração "Map Pin Picker"

**Localização prevista**
- Capítulo: 3
- Secção: expandir `3.3.7` — subsecção "Coleções criadas para armazenar os dados", junto da
  explicação dos campos `posX`/`posY` de Item e Area
- Criar nova secção? Não
- Expandir secção existente? Sim
- Atualizar requisitos funcionais? Não obrigatório — reforça o requisito não funcional
  "Interface Intuitiva" já existente, sem precisar de bullet novo
- Atualizar índice? Não
- Atualizar referências cruzadas? Não
- Necessita de figura? Recomendada, não obrigatória
- Legenda sugerida: "Figura X - Ferramenta de posicionamento visual de pins no painel do Strapi"
- Local exato: logo a seguir ao parágrafo que explica os campos `posX`/`posY`

**Objetivo**: simplificar a tarefa de posicionar visualmente cada item/área no mapa, para quem
gere o conteúdo.

**Problema que resolveu**: escrever coordenadas X/Y manualmente é propenso a erro e pouco
intuitivo para administradores sem formação técnica.

**Porque foi necessária**: reforça o argumento, já presente em 3.3.7, de que o Strapi foi
escolhido por ser acessível a pessoas sem conhecimentos técnicos — sem esta ferramenta essa
promessa ficava incompleta para o caso do posicionamento no mapa.

**O que deve ser explicado**: que o administrador clica diretamente na imagem do mapa e o
sistema calcula a posição automaticamente.

**O que não deve ser explicado**: o código React/TypeScript do plugin, nem o cálculo de
normalização das coordenadas.

**Benefícios obtidos**: redução de erros de posicionamento e menor curva de aprendizagem para a
equipa do museu.

---

## 5. Configuração de Museu Ativo / Troca de Fonte de Conteúdo

**Localização prevista**
- Capítulo: 3
- Secção: expandir `3.3.5 Arquitetura Geral do Sistema` (só criar subsecção própria se o texto
  não couber com naturalidade no parágrafo existente)
- Criar nova secção? Preferencialmente não
- Expandir secção existente? Sim
- Atualizar requisitos funcionais? Sim — reforçar (não duplicar) o requisito não funcional
  "Escalabilidade" já existente em 3.3.4
- Atualizar índice? Só se vier a ser subsecção própria
- Atualizar referências cruzadas? Sim — ligar ao caso de uso real (troca para o Museu de
  Portimão), que já está descrito fora do relatório em `EtapasImplementacao.txt` (Fase 2)
- Necessita de figura? Não essencial
- Legenda sugerida: —
- Local exato: —

**Objetivo**: permitir apontar toda a aplicação — incluindo o assistente — para um único museu
através de uma única configuração central.

**Problema que resolveu**: sem isto, trocar de museu implicaria alterações espalhadas por
vários ficheiros, com risco de o mapa e o assistente ficarem a apontar para museus diferentes.

**Porque foi necessária**: o projeto passou de um museu fictício de demonstração para conteúdo
real (Museu de Portimão) a meio do estágio — sem este mecanismo essa transição teria sido
manual e arriscada.

**O que deve ser explicado**: a ideia de um único ponto de configuração partilhado entre app e
assistente, e o caso de uso real (troca para o Museu de Portimão).

**O que não deve ser explicado**: o nome exato da constante/ficheiro de configuração no código.

**Benefícios obtidos**: capacidade de reutilizar o Museum Mate para outros museus ou clientes no
futuro sem duplicar trabalho de desenvolvimento.

---

## 6. Fluxo de Desenvolvimento com Claude Code e Metodologia Spec-Driven (Git-Spec) — NOVO

Ponto novo, ainda não considerado nas versões anteriores deste documento. Descreve o *processo*
de desenvolvimento, não uma funcionalidade da aplicação — por isso segue um enquadramento
ligeiramente diferente dos pontos 1-5, mas a mesma disciplina de "localização prevista".

Esta análise baseia-se em evidência real do projeto, não em descrições genéricas das
ferramentas:

- **5 features estruturadas em spec-kit** (`specs/001-004`), cada uma com `spec.md` (histórias
  de utilizador priorizadas P1/P2/P3, secção de Clarificações com perguntas e respostas
  datadas, cenários de aceitação no formato Given/When/Then), `plan.md`, `research.md`,
  `data-model.md` e `tasks.md` (tarefas com ID, agrupadas por história de utilizador, com
  marcação de paralelismo).
- `.specify/memory/constitution.md` — um documento de princípios do projeto (ex. "Environment
  Configuration Discipline", "Spec-Driven Development (NON-NEGOTIABLE)") que qualquer plano
  técnico tem de respeitar.
- Um **pivot documentado e justificado** na feature `003-assistant-web-fallback`: o fallback do
  assistente foi inicialmente desenhado com pesquisa Google real (Grounding do Gemini), mas foi
  alterado depois de testes diretos confirmarem que essa opção exigia ativar faturação na conta
  associada à chave de API — decisão consciente do autor de não o fazer, optando por manter a
  resposta a partir do conhecimento geral do modelo.
- `EtapasImplementacao.txt`, onde o autor planeou as fases seguintes mapeando-as diretamente a
  features do spec-kit, antes de qualquer implementação.
- `RegistoImplementacao/2026-07-27.md`, um registo real de diagnóstico com o Claude Code
  (sintoma reportado → causas identificadas → decisão consciente do autor).
- Um commit real (`8e2b1c0`) com o trailer `Co-Authored-By: Claude Sonnet 5`, prova concreta de
  uso da ferramenta no controlo de versões, não apenas hipotético.

**Localização prevista**
- Capítulo: 3
- Secção: nova `3.3.9 Metodologia de Desenvolvimento: Spec-Driven Development e Assistência de
  IA`, no final do bloco 3.3, depois da secção de Docker/infraestrutura (que passa a `3.3.8`,
  corrigindo o erro de numeração já existente) e antes do capítulo 4
- Criar nova secção? Sim — dimensão e natureza distinta (processo, não componente do sistema)
  justificam secção própria
- Expandir secção existente? Parcialmente — ligar ao parágrafo já existente em 3.3.6
  "Planeamento da Solução" que refere que "uma análise arquitetural robusta deve anteceder
  qualquer esforço de programação", reforçando essa ideia em vez de a repetir
- Atualizar requisitos funcionais? Não — é processo de desenvolvimento, não funcionalidade da
  aplicação
- Atualizar índice? Sim
- Atualizar referências cruzadas? Sim — remeter de volta para 3.3.6
- Necessita de figura? Opcional — poderia ilustrar o fluxo spec → plan → tasks → implementação,
  mas não é obrigatório
- Legenda sugerida (se aplicável): "Figura X - Fluxo de trabalho: da especificação à
  implementação"
- Local exato onde a figura deverá ser inserida (se aplicável): depois do parágrafo que descreve
  o ciclo spec→plan→tasks, antes da lista de vantagens/limitações

**Objetivo**: descrever como o desenvolvimento do Museum Mate passou a ser organizado, a partir
de certo ponto do estágio, através de especificações formais e de assistência de IA no código —
o processo, não apenas o resultado técnico.

**Problema que resolveu**: à medida que o projeto cresceu (múltiplas funcionalidades, dois
stacks tecnológicos, requisitos que mudam), tornou-se difícil manter decisões e requisitos
rastreáveis apenas de memória ou em notas soltas.

**Porque foi necessária**: um projeto individual, sem equipa a validar decisões em tempo real,
beneficia de um processo que obrigue a explicitar por escrito o problema antes de programar.

**O que deve ser explicado**:
- que cada funcionalidade nova passou a nascer como uma especificação, com histórias de
  utilizador priorizadas e critérios de aceitação, antes de qualquer código;
- que essa especificação era clarificada por perguntas e respostas datadas quando havia
  ambiguidade, e só depois convertida num plano técnico e numa lista de tarefas;
- que o Claude Code foi utilizado ao longo de todo este ciclo — na escrita e revisão de
  especificações, na implementação guiada pelas tarefas, na análise de código já existente e na
  documentação — sempre com o autor a validar e a decidir, nunca a aceitar sugestões às cegas;
- o exemplo concreto e honesto do pivot do fallback do assistente (pesquisa web → conhecimento
  interno do modelo, por decisão consciente de não ativar faturação);
- vantagens obtidas: rastreabilidade das decisões, requisitos explícitos antes de implementar,
  redução do risco de retrabalho;
- limitações encontradas: necessidade de validar sempre as sugestões geradas; risco de aceitar
  código ou texto sem espírito crítico se o processo não for seguido com disciplina.

**O que não deve ser explicado**: não é um texto promocional sobre Inteligência Artificial, nem
uma explicação genérica de como funcionam o Claude Code ou o "spec-kit" enquanto produto — o
foco é sempre o processo realmente seguido neste projeto, com exemplos concretos.

**Benefícios obtidos**: maior rigor na definição de requisitos, decisões tecnicamente
justificadas e documentadas, e redução de erros por ambiguidade — sem nunca substituir o
julgamento humano do autor.
