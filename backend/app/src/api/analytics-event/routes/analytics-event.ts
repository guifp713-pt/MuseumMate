import { factories } from '@strapi/strapi';

export default factories.createCoreRouter('api::analytics-event.analytics-event', {
  config: {
    // Aqui configuras o acesso público aos endpoints padrão (find, findOne)
    find: { auth: false },
    findOne: { auth: false },
    create: { auth: false }, // Se precisares de POST
    update: { auth: false },
    delete: { auth: false },
  },
});