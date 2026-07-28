export default {

  async dashboard(ctx) {

    const stats = await strapi
      .service('api::analytics.analytics')
      .getDashboardStats();

    ctx.body = stats;
  },

  async languages(ctx) {

    const result = await strapi
      .service('api::analytics.analytics')
      .getLanguages();

    ctx.body = result;
  },

};