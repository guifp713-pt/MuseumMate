import { factories } from '@strapi/strapi';

export default factories.createCoreController('api::analytics-event.analytics-event', ({ strapi }) => {
  return {
    async getLanguageStats(ctx) {
      try {
        const { dataFiltro } = ctx.query as { dataFiltro?: string };

        let query = strapi.db.connection('analytics_events')
          .select('language')
          .countDistinct('session_id as totalSessoes')
          // .where('event_type', 'visit_start') <-- Removido para contar todos os tipos de eventos
          .groupBy('language');

        if (dataFiltro) {
          query = query.whereRaw('DATE(timestamp) = ?', [dataFiltro]);
        }

        const stats = await query;
        return stats;
      } catch (error) {
        return ctx.badRequest('Erro ao calcular estatisticas de idiomas', error);
      }
    }
  };
});