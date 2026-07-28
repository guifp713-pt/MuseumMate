export default {
  routes: [
    {
      method: 'GET',
      path: '/analytics/dashboard',
      handler: 'analytics.dashboard',
      config: {
        auth: false,
      },
    },
    {
      method: 'GET',
      path: '/analytics/languages',
      handler: 'analytics.languages',
      config: {
        auth: false,
      },
    },
  ],
};