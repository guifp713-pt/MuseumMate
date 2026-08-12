---
name: "relatorios"
description: "Guia de estilo e de processo para alterar o Relatório de Estágio (Museum Mate, IPCA/Edigma). Usar sempre que se escrever, expandir, integrar ou rever conteúdo do relatório, para manter a narrativa de engenharia, o registo académico em português de Portugal e a ilusão de que o documento foi escrito numa única fase."
metadata:
  author: "guilherme"
  source: "análise de RelatórioEstágio.docx (capítulos 1-4)"
user-invocable: true
disable-model-invocation: false
---

# Estilo e processo de escrita do Relatório de Estágio

Esta skill descreve o registo de escrita que Guilherme já usa no `RelatórioEstágio.docx` e o
processo pelo qual conteúdo novo deve ser integrado nele, para que qualquer alteração (secções,
parágrafos, revisões) soe como se tivesse sido escrita pela mesma pessoa, no mesmo documento,
na mesma altura. Foi construída por análise direta do texto existente — não é um guia de estilo
genérico, são os padrões reais encontrados no relatório.

---

## 0. Objetivo da skill

O objetivo desta skill **não é apenas gerar texto correto**. É preservar a ilusão de que todo o
relatório foi escrito numa única fase, por uma única pessoa, com um ritmo constante do
princípio ao fim. Qualquer conteúdo novo deve:

- integrar-se naturalmente no capítulo onde entra, sem parecer "colado";
- manter continuidade narrativa com o parágrafo anterior e o seguinte;
- respeitar a terminologia já usada para os mesmos conceitos (não introduzir sinónimos novos
  para coisas já nomeadas, ex. não passar a chamar "aplicação" a algo que o resto do texto
  chama sempre "app", ou vice-versa);
- respeitar o tamanho médio das secções vizinhas (nem um parágrafo solto, nem o dobro do
  comprimento habitual);
- respeitar o ritmo do documento (alternância entre parágrafos de contexto, listas e figuras,
  ver secções 6 a 8);
- evitar que seja percetível, a um leitor externo, quais as partes que foram escritas depois
  das outras.

Todas as regras seguintes servem este objetivo único.

---

## 1. Princípio central: narrativa de engenharia, não manual técnico

O relatório **não deve nunca ler-se como documentação técnica ou um manual de utilizador**.
Todas as secções — mini-projetos, decisões de arquitetura, funcionalidades individuais — seguem
a mesma sequência narrativa de fundo, ainda que com títulos diferentes consoante o caso:

> **Problema identificado → Necessidade → Solução adotada → Funcionamento → Benefícios obtidos**

Isto tem três consequências práticas para qualquer texto novo:

1. **Justificar sempre antes de implementar.** Nunca apresentar uma funcionalidade como uma
   simples lista de capacidades ("a app permite X, Y, Z"). Explicar sempre, por esta ordem:
   por que motivo surgiu a necessidade; que problema concreto resolveu; por que foi escolhida
   aquela abordagem (e não outra); só depois, como funciona.
2. **Fechar sempre com o benefício.** Nenhuma secção deve terminar numa explicação puramente
   técnica. A última frase (ou o último bloco) deve religar a solução ao benefício concreto
   para o visitante, para o administrador do museu, ou para a manutenção futura do sistema —
   à semelhança de "Em suma, esta automação transforma o telemóvel num assistente invisível e
   inteligente..." ou de "Vantagens obtidas:" / "Vantagens da Solução".
3. **Duas variantes do mesmo esqueleto, consoante o âmbito:**
   - **Funcionalidade / mini-projeto:** Objetivo → Análise/Problema identificado
     (normalmente com uma lista de requisitos ou comportamentos esperados) → Implementação e
     funcionamento (em prosa, sem código) → Vantagens obtidas.
   - **Decisão de arquitetura** (ex. Docker, endpoint único, cache offline): Problema inicial →
     "A Decisão de..." ou "Porquê escolher X e não Y?" → Solução implementada → Vantagens da
     Solução.

---

## 2. Português de Portugal — vocabulário a preferir

Usar sempre a variante europeia, nunca a brasileira:

| Usar (PT-PT) | Não usar (PT-BR) |
|---|---|
| ecrã | tela |
| telemóvel | celular |
| ficheiro | arquivo |
| utilizador | usuário |
| aplicação / app | aplicativo |
| camada | layer (traduzido) |
| gerir / gestão | gerenciar / gerenciamento |
| descarregar | baixar (download) |

Conjugações e construções tipicamente PT-PT já usadas no texto: "consigam", "está a decorrer",
"a fazer", gerúndio evitado a favor de "a" + infinitivo ("está a processar" em vez de "está
processando").

---

## 3. Registo e voz: impessoal (regra) vs. primeira pessoa (exceção)

A maior parte do relatório (capítulos 1, 2, 3.1–3.3.6, e toda a descrição de *funcionamento*
do sistema) é escrita numa voz impessoal e académica, usando construções com "se" e particípio
passado, evitando o "eu" e o "nós":

- "foi realizado um estágio curricular..."
- "optou-se por separar a aplicação móvel da camada de gestão..."
- "concluiu-se que uma arquitetura centralizada... seria a solução mais adequada"
- "foi necessário analisar os elementos fundamentais..."
- "determinou-se a transposição das ideias..."

**Quando mudar para primeira pessoa** (exceção deliberada e já presente no texto, ex. secção
3.3.7 sobre a escolha do Strapi, ou a evolução do `restore.sh`): apenas quando o autor está a
descrever, especificamente,

- decisões próprias ("decidi utilizar o Strapi...");
- escolhas de arquitetura ("estruturei o backend do Strapi em sete coleções...");
- aprendizagens pessoais ao longo do estágio;
- melhorias realizadas por iniciativa própria ("fiz várias alterações...", "ajustei o
  mapeamento de volumes...");
- justificações pessoais de uma escolha ("Isto deu-me a liberdade necessária para
  personalizar...", "um projeto que apelidei de Museum Mate").

**A descrição do *funcionamento* do sistema em si mantém-se sempre impessoal**, mesmo dentro de
uma secção que começou em primeira pessoa a justificar uma escolha — a mudança de voz acontece
ao nível da frase/parágrafo, não da secção inteira. Se não for óbvio qual das duas encaixa numa
frase nova, perguntar ao Guilherme antes de escrever a secção toda nesse tom.

---

## 4. Como abrir uma secção e conectores a reutilizar

### Frases de abertura (contextualizar antes de implementar)

Uma secção nova deve começar por enquadrar o tema — nunca entrar diretamente na implementação.
Reutilizar as fórmulas de abertura já existentes no relatório em vez de inventar outras:

- **Nesta fase...** — para situar a secção no tempo do projeto
- **Com o objetivo de...** — para introduzir logo a finalidade
- **Para responder a esta necessidade/imprevisibilidade...** — para ligar a uma necessidade já
  identificada antes
- **Atendendo aos requisitos definidos anteriormente...** — para retomar requisitos já listados
- **Antes do início da implementação...** / **Antes do desenvolvimento de X...** — para marcar
  que houve análise prévia
- **Neste contexto,** — para enquadrar uma decisão dentro do problema já descrito

### Conectores intra-parágrafo

Conjunto limitado e repetido de conectores/marcadores de discurso usado ao longo do texto:

- **Deste modo,** / **Desta forma,** — para introduzir uma consequência ou decisão
- **Assim,** — conclusão/consequência mais curta
- **Para além de** / **Para além disso,** — para adicionar informação, não "além disso" isolado
- **No entanto,** — contraste (nunca "porém" ou "contudo", que não aparecem no texto)
- **Sempre que** — para descrever comportamento condicional/recorrente do sistema
- **Em suma,** — para fechar um raciocínio com uma síntese
- **Analiticamente,** — para introduzir uma explicação técnica mais detalhada
- **Numa abordagem tradicional...** / **Numa fase inicial,** — para contrastar o "antes" com a
  solução adotada
- **Ao longo de** / **No âmbito de/do** — para enquadramento temporal ou institucional

Evitar conectores mais informais ("tipo", "basicamente", "portanto" em excesso) ou demasiado
rebuscados que não aparecem no original ("outrossim", "destarte").

---

## 5. Banco de subtítulos padrão

Reutilizar este vocabulário de títulos/subtítulos ao criar secções novas, em vez de títulos
completamente diferentes. Cada um corresponde a um ponto da narrativa descrita na secção 1:

| Fase da narrativa | Subtítulos já usados no relatório |
|---|---|
| Problema / necessidade | "Problema Inicial", "Problema Identificado" |
| Objetivo | "Objetivo do projeto", "Objetivo da aplicação" |
| Decisão | "A Decisão de Utilizar...", "Porquê escolher X e não Y?" |
| Funcionamento | "Implementação e funcionamento", "Funcionamento", "Arquitetura de...",
  "Arquitetura do...", "Mecanismo de...", "Fluxo de...", "Fluxo do..." |
| Fecho / benefício | "Vantagens da Solução", "Vantagens obtidas" |

---

## 6. Como explicar tecnologia sem ser demasiado técnico

### Ordem obrigatória: conceito → funcionamento → detalhe técnico

Sempre que uma secção envolver código, diagramas ou capturas de ecrã, respeitar esta ordem e
nunca a inverter:

1. explicar primeiro o conceito (o problema/necessidade, em linguagem simples);
2. explicar depois o funcionamento (o que o sistema faz, ainda em prosa);
3. só depois introduzir a figura, o excerto técnico ou o nome do ficheiro/função.

### Glosar termos técnicos em inglês

Padrão muito consistente no relatório: **nunca introduzir um termo técnico em inglês sem o
explicar entre parênteses em português**, logo na primeira ocorrência:

- "modelo Bring Your Own Device (BYOD)"
- "Headless CMS – Content Management System"
- "Foreground Service (Serviço de Primeiro Plano)"
- "JNI (Java Native Interface)"

E depois disso, a explicação é sempre em termos de **o que o utilizador ganha**, não da
implementação:

> "Isto permite que o sistema operativo a promova a um Foreground Service (Serviço de Primeiro
> Plano), blindando o processo contra encerramentos abruptos..."

Nunca colar nomes de ficheiros de código, funções ou snippets dentro do parágrafo de texto
corrido sem contexto — o relatório refere-os ("a função checkCollision()", "o ficheiro
ApiHandler.js") mas sempre a explicar o papel funcional, remetendo o detalhe técnico para uma
figura ("conforme ilustrado na Figura X").

### Metáforas e analogias

O autor recorre a metáforas simples para explicar decisões técnicas a um leitor não técnico:

- "o motor de dados" (para o ApiHandler.js)
- "bússola digital" (para o mapa interativo)
- "assistente invisível e inteligente" (para a navegação automática via QR)
- "barreira invisível" (para o clamp do mapa)
- "não funciona como uma caixa preta" (para justificar a escolha do Strapi)
- "o coração da base de dados" (para a coleção Item)

Ao escrever novas secções (ex. sobre o assistente de IA), procurar uma metáfora equivalente em
vez de apenas descrever o mecanismo tecnicamente.

### Perguntas retóricas para enquadrar a necessidade do utilizador

Recurso usado pelo menos uma vez de forma marcante, vale a pena reutilizar ao introduzir uma
funcionalidade nova centrada no visitante:

> "responder de forma imediata a duas perguntas fundamentais de qualquer visitante: 'Onde é
> que eu estou?' e 'O que é que há para ver aqui perto?'"

---

## 7. Figuras: introdução, referência e posicionamento

- Toda a figura tem de ser **introduzida previamente no texto** — nunca inserir uma imagem sem
  um parágrafo anterior que a prepare.
- Referenciar sempre com "conforme ilustrado na Figura X" / "como se pode observar na Figura X".
- Legendar no formato "Figura X - Descrição curta" (sem ponto final, coerente com as legendas
  já existentes).
- **Ao escrever conteúdo novo, indicar sempre explicitamente**: (a) onde deveria entrar uma
  figura nova (a que parágrafo/parte da secção corresponde) e (b) sugerir uma legenda coerente
  com o estilo das restantes, mesmo que a imagem em si ainda não exista.

---

## 8. Utilização equilibrada de listas

O relatório evita sucessões longas de listas soltas. O padrão dominante é:

> texto (contextualiza) → lista (enumera) → texto (fecha/interpreta)

Ex.: um parágrafo a explicar o "Problema Inicial" do Docker, seguido de uma lista curta de
problemas concretos, seguido de uma frase de fecho ("Esta situação tornava o sistema pouco
prático fora do meu computador de trabalho...").

**Exceção conhecida:** os capítulos de Requisitos Funcionais/Não Funcionais (3.3.4) são listas
longas por natureza — não aplicar aqui a regra texto→lista→texto, é o único sítio do relatório
onde isso acontece propositadamente.

---

## 9. O que evitar

- Não escrever parágrafos centrados em nomes de funções, classes ou ficheiros de código como
  sujeito da frase (ex. evitar "A função `handleClick()` é chamada quando..."). Preferir
  "Sempre que o utilizador toca no ecrã, o sistema..."
- Não usar jargão de engenharia de software sem glosa (não escrever "singleton", "middleware",
  "callback" sem explicar em português o que isso significa na prática).
- Não misturar PT-BR acidentalmente (ex. nunca "tela", "usuário", "celular", "arquivo").
- Não encher parágrafos de números/percentagens técnicas — o relatório é qualitativo e
  descritivo, não um documento de métricas.
- Não abandonar a estrutura Problema → Necessidade → Solução → Funcionamento → Benefícios sem
  motivo, mesmo em secções novas (ex. Assistente de IA, NFC, fluxo de desenvolvimento).
- Não escrever de forma promocional sobre ferramentas ou tecnologias (ex. elogiar a IA/Claude
  Code em abstrato, linguagem de marketing). Descrever sempre o fluxo de trabalho realmente
  utilizado e os resultados concretos obtidos — incluindo limitações — nunca um texto de venda.

---

## 10. Onde integrar: localizar antes de criar

Antes de escrever qualquer conteúdo novo, seguir esta ordem — nunca criar uma secção nova por
conveniência, apenas porque é mais simples do que integrar:

1. **Localizar primeiro a secção existente** onde a funcionalidade poderia caber (ler o índice
   e os títulos de 3.3 e 4 antes de decidir).
2. **Verificar se basta expandir essa secção** — um parágrafo adicional, uma frase a mais numa
   lista, uma nota — em vez de criar um título novo.
3. **Só criar uma secção nova** quando não existir, de facto, um local adequado para o conteúdo
   (ex. uma funcionalidade que não pertence a nenhum ficheiro/ecrã já documentado).
4. **Só criar um capítulo/subcapítulo novo de topo** quando a dimensão real da funcionalidade o
   justificar (várias páginas, arquitetura própria) — nunca para uma funcionalidade pequena.

Regra prática: uma funcionalidade "irmã" de outra já documentada (ex. NFC ao lado de QR) deve
entrar na mesma secção que essa outra, não numa secção própria.

---

## 11. Checklist de coerência global ao integrar conteúdo novo

Sempre que uma funcionalidade for integrada no relatório, verificar **todos** os locais onde
ela pode ter de aparecer — não assumir que um único capítulo chega:

- [ ] **Requisitos funcionais** (3.3.4) — a funcionalidade deve estar listada aqui se for uma
      capacidade da aplicação.
- [ ] **Arquitetura** (3.3.5/3.3.6) — se a funcionalidade implicar uma decisão de arquitetura
      ou afetar componentes existentes.
- [ ] **Descrição do frontend** (capítulo 4) — se tiver um ecrã, componente QML ou interação
      visível ao visitante.
- [ ] **Decisões de implementação/coleções do Strapi** (3.3.7) — se envolver dados novos,
      campos novos ou eventos de analytics novos.
- [ ] **Conclusões intermédias** — se a secção onde entra tiver normalmente uma frase de fecho
      ligando ao capítulo seguinte, não esquecer essa transição.
- [ ] **Figuras** — indicar onde entra a figura nova e sugerir legenda (ver secção 7).
- [ ] **Índice e numeração dos títulos** — atualizar manualmente no Word; sinalizar sempre que
      a inserção obriga a renumerar secções seguintes (ex. inserir uma secção 4.6 nova implica
      que a atual 4.6 passe a 4.7, e assim sucessivamente).
- [ ] **Referências cruzadas** — atualizar menções a "ver capítulo X" / "Figura Y" que possam
      ter sido afetadas pela renumeração.

Antes de escrever, ler também a secção anterior e a seguinte no relatório, para garantir
continuidade narrativa; depois de escrever, confirmar que não se está a repetir informação já
explicada noutro capítulo (remeter para lá em vez de duplicar) e que a dimensão do texto novo é
semelhante à das secções vizinhas.

---

## 12. Bibliografia

Formato já usado, seguir à risca para novas referências (ex. documentação do Google Gemini,
Claude Code, spec-kit):

> Autor/Organização. (Ano ou s.d.). *Título em itálico*. Consultado em [data], em [URL]
