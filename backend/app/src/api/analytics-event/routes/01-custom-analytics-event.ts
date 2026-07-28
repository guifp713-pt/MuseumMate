export default {
  type: 'content-api',
  routes: [
    {
      method: 'GET',
      path: '/analytics-events/language-stats',
      handler: 'api::analytics-event.analytics-event.getLanguageStats',
      config: {
        auth: false, // Mantém false para acesso público
        policies: [],
        middlewares: [],
      },
    },
  ],
};