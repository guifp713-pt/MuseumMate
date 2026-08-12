import { ACTIVE_ENTITY_DOCUMENT_ID } from "../../../../../config/museum";

const service = ({ strapi }) => ({
  getWelcomeMessage() {
    return "Welcome to Strapi 🚀";
  },

  // specs/004-analytics-multi-entity §7 — exposes the backend's currently
  // configured active museum so the dashboard can default its selector to it
  // (FR-017), without duplicating ACTIVE_ENTITY_DOCUMENT_ID a third time.
  getActiveEntity() {
    return { documentId: ACTIVE_ENTITY_DOCUMENT_ID };
  },
});

export default service;