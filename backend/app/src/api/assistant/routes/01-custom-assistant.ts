export default {
  type: 'content-api',
  routes: [
    {
      method: 'POST',
      path: '/assistant/ask',
      handler: 'api::assistant.assistant.ask',
      config: {
        auth: false, // Público — o assistente não exige autenticação do visitante (FR-010)
        policies: [],
        middlewares: [],
      },
    },
  ],
};
