export default {
  async getDashboardStats() {

    const itemViews = await strapi.documents(
      'api::analytics-event.analytics-event'
    ).count({
      filters: {
        eventType: 'item_view',
      },
    });

    const visits = await strapi.documents(
      'api::analytics-event.analytics-event'
    ).count({
      filters: {
        eventType: 'visit_start',
      },
    });

    const toursCompleted = await strapi.documents(
      'api::analytics-event.analytics-event'
    ).count({
      filters: {
        eventType: 'tour_complete',
      },
    });

    const scanErrors = await strapi.documents(
      'api::analytics-event.analytics-event'
    ).count({
      filters: {
        eventType: 'scan_error',
      },
    });

    return {
      visits,
      toursCompleted,
      scanErrors,
      itemsViewed: itemViews,
      toursAbove50: 0,
    };
  },

  async getLanguages() {

  const events = await strapi.documents(
    'api::analytics-event.analytics-event'
  ).findMany({
    fields: ['language']
  });

  const total = events.length;

  const counts: Record<string, number> = {};

  for (const event of events) {
    const lang = event.language;

    if (!lang) continue;

    counts[lang] = (counts[lang] || 0) + 1;
  }

  return Object.entries(counts).map(([language, count]) => ({
    language,
    count,
    percentage: Number(
      ((count / total) * 100).toFixed(2)
    ),
  }));

}
};