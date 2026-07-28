export default {
  type: 'content-api',
  routes: [
    {
      method: 'GET',
      path: '/museum-config/area-zoom',
      handler: 'api::museum-config.museum-config.getAreaZoom',
      config: {
        auth: false, // Público — expõe apenas um número de zoom, nada sensível
        policies: [],
        middlewares: [],
      },
    },
  ],
};
