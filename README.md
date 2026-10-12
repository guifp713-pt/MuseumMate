# Museum Mate — Enterprise Museum Guide & AI Assistant

> **Estado do Projeto:** Case de Portfólio / Produto Proprietário  
> **Arquitetura:** Monorepo (Mobile Cross-Platform + Headless CMS + AI Integration)

---

## Visão Geral do Produto
O **Museum Mate** é uma solução de guia turístico digital de alta performance desenvolvida para museus modernos. O sistema combina uma aplicação móvel nativa de baixa latência (para garantir fluidez em qualquer dispositivo Android) com um painel administrativo robusto baseado num CMS headless e um assistente inteligente integrado via IA.

Este repositório demonstra a capacidade de conceber, arquitetar e entregar um **ecossistema completo de ponta a ponta**, lidando com desafios complexos de engenharia móvel, persistência local offline e processamento de linguagem natural no backend.

---

## Destaques de Arquitetura & Engenharia

### 1. Aplicação Móvel de Alta Performance (`TourAssistent-main/`)
- **Stack:** C++17 + Qt Quick (QML).
- **Decisão Arquitetural:** Opção escolhida em detrimento de frameworks híbridos tradicionais para garantir consumo mínimo de bateria, renderização a 60 FPS e acesso direto a APIs nativas do sistema operativo.
- **Desafios Resolvidos:**
  * **Áudio em Background (Android):** Desenvolvimento de uma ponte JNI personalizada (`TourAudioService.java`) para manter o reprodutor de áudio ativo em segundo plano com notificações de multimédia ricas e sincronizadas via OS MediaSession.
  * **Modo Offline-First:** Estratégia de cache local robusta utilizando SQLite (`QtQuick.LocalStorage`) para garantir o funcionamento pleno do museu mesmo sem ligação à internet.
  * **Leitura de QR/NFC:** Integração nativa de hardware para navegação instantânea por exposições através de códigos e tags físicas.

### 2. Backend Escalável & CMS (`backend/`)
- **Stack:** Strapi 5 (Node.js + TypeScript).
- **Decisão Arquitetural:** Utilização de um monorepo estruturado para gerir múltiplos tenants/museus com isolamento estrito de dados de telemetria (`entidadeDocumentId`).
- **Plugins Personalizados:** Desenvolvimento de painéis administrativos à medida para mapeamento visual de coordenadas de plantas baixas (*Map Pin Picker*) e dashboards analíticos de utilização.

### 3. Assistente de IA Integrado (`Google Gemini`)
- **Abordagem de Custo-Benefício e Precisão:** Encaminhamento inteligente de pedidos integrando o modelo `gemini-3.1-flash-lite`.
- O sistema prioriza estritamente o catálogo estruturado do museu local para evitar alucinações e utiliza um mecanismo de fallback controlado para conhecimentos gerais quando autorizado pelas regras de negócio.

---

## Stack Tecnológica

| Camada | Tecnologias |
| :--- | :--- |
| **Móvel** | C++17, Qt/QML, Android JNI, QZXing |
| **Backend / API** | Node.js, TypeScript, Strapi 5, Docker |
| **Base de Dados** | SQLite (Cliente), Relational DB (Servidor) |
| **Inteligência Artificial** | Google GenAI SDK (Gemini) |

---
*Nota: Este repositório tem fins estritamente demonstrativos de portfólio. Todos os direitos de propriedade intelectual são reservados.*
