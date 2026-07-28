/**
 * Não existe content-type `museum-config`: este é um controller custom puro,
 * que apenas expõe (GET /api/museum-config/area-zoom) o fator de zoom de área
 * configurado para a entidade ativa (specs/002-content-source-switch), para o
 * campo customizado de posicionamento de Items no admin (Itempinpickerfield.tsx)
 * o poder ler sem depender de um import estático fora do seu próprio bundle.
 */
import { ACTIVE_ENTITY_DOCUMENT_ID, getAreaZoomForActiveEntity } from '../../../config/museum';

export default {
  async getAreaZoom(ctx: any) {
    ctx.body = {
      documentId: ACTIVE_ENTITY_DOCUMENT_ID,
      zoom: getAreaZoomForActiveEntity(),
    };
  },
};
