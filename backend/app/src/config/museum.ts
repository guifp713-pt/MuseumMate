/**
 * Single source of truth (backend side) for which `entidade` document is
 * currently served by the assistant. The mobile app keeps an equivalent
 * constant of its own (`ApiHandler.js`) — see
 * specs/002-content-source-switch/contracts/active-entity-config.md for the
 * contract both stacks must follow. Switching museums means updating both
 * values to the same documentId.
 */
//export const ACTIVE_ENTITY_DOCUMENT_ID = 'gqag59gr2pvu95qawb4dq1ol'; //Industria Textil Norte
export const ACTIVE_ENTITY_DOCUMENT_ID = 'ifajyzfd52v3tvq1mrf8j6eu'; //Museu de Portimao

/**
 * Fator de zoom aplicado, no editor de Items (Itempinpickerfield.tsx), quando
 * uma Área é ampliada para se posicionar um Item lá dentro. Espelha o mesmo
 * conceito usado na app (mapScale.xScale/yScale em HomePage.qml, ver
 * ApiHandler.js → AREA_ZOOM_BY_ENTITY / getAreaZoom()).
 *
 * Chave = documentId da entidade; entidades não listadas usam DEFAULT_AREA_ZOOM
 * (o valor 2.0 original). Trocar ACTIVE_ENTITY_DOCUMENT_ID acima já é
 * suficiente para o zoom certo entrar em vigor automaticamente — não é preciso
 * mexer aqui a não ser que o próprio valor de zoom precise de ser afinado.
 */
export const DEFAULT_AREA_ZOOM = 2.0;

export const AREA_ZOOM_BY_ENTITY: Record<string, number> = {
  // Museu de Portimão — áreas fisicamente maiores do que a entidade fictícia;
  // 2.0 cortava itens fora do enquadramento. 1.3 é um valor de partida a
  // validar visualmente (suficiente para ver a área toda, mantendo algum foco).
  ifajyzfd52v3tvq1mrf8j6eu: 1.3,
};

export function getAreaZoomForActiveEntity(): number {
  return AREA_ZOOM_BY_ENTITY[ACTIVE_ENTITY_DOCUMENT_ID] ?? DEFAULT_AREA_ZOOM;
}