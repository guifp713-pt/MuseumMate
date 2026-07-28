module.exports = {
  register({ strapi }) {
    // 1. Registo original do picker da Área
    strapi.customFields.register({
      name: 'pin-picker',
      plugin: 'map-picker',
      type: 'decimal', // Mapeamos para o tipo decimal (number) do teu posX
    });

    // 2. NOVO: Registo do picker do Item
    strapi.customFields.register({
      name: 'item-pin-picker',
      plugin: 'map-picker',
      type: 'decimal', // Mantemos a mesma tipagem do original
    });
  },
  bootstrap() {},
  destroy() {},
  config: {
    default: {},
    validator() {},
  },
  controllers: {},
  routes: {},
  services: {},
  contentTypes: {},
  policies: {},
  middlewares: {},
};