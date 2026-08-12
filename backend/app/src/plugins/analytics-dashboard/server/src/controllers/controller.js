const controller = ({ strapi }) => ({
  index(ctx) {
    ctx.body = strapi
      .plugin("analytics-dashboard")
      // the name of the service file & the method.
      .service("service")
      .getWelcomeMessage();
  },

  // specs/004-analytics-multi-entity §7 — GET /analytics-dashboard/active-entity
  activeEntity(ctx) {
    ctx.body = strapi.plugin("analytics-dashboard").service("service").getActiveEntity();
  },
});

export default controller;