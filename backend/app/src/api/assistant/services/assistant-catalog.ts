/**
 * assistant-catalog — obtém o catálogo completo do museu para o prompt do assistente.
 *
 * Estratégia (Research §3): o catálogo é pequeno (~30 itens / ~10 áreas), pelo que
 * é carregado por inteiro, sem camada de retrieval/embeddings.
 *
 * Proveniência da tradução (FR-005 / FR-006): o catálogo é construído a partir da
 * árvore em português (locale canónico, o único garantidamente completo) e, por
 * cima, sobrepõe-se a localização no idioma ativo do visitante. Cada campo de texto
 * fica marcado com `official: true` quando existe tradução oficial no Strapi para
 * esse idioma, e `official: false` quando só existe o original em português — é
 * essa marca que permite ao modelo saber o que pode usar tal-e-qual e o que tem de
 * traduzir (e, por consequência, devolver `autoTranslated` corretamente).
 */

import { ACTIVE_ENTITY_DOCUMENT_ID } from '../../../config/museum';

const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutos (Research §3)
const BASE_LOCALE = 'pt';

const CATALOG_POPULATE = {
  dictionaries: true,
  tours: { populate: { items: true } },
  maps: { populate: { areas: { populate: { items: true } } } },
};

/**
 * Lançado quando ACTIVE_ENTITY_DOCUMENT_ID (specs/002-content-source-switch)
 * não corresponde a nenhuma entidade — o controller já trata qualquer erro
 * lançado por getCatalog como assistant_unavailable (502), por isso não
 * precisa de tratamento dedicado além deste tipo distinguível.
 */
export class EntityNotFoundError extends Error {
  constructor(documentId: string) {
    super(`No entidade found for documentId "${documentId}"`);
    this.name = 'EntityNotFoundError';
  }
}

/** Um campo de texto do catálogo, com a respetiva proveniência. */
export interface CatalogField {
  value: string;
  official: boolean; // true = tradução oficial no idioma pedido; false = original PT
}

export interface CatalogItem {
  name: CatalogField | null;
  description: CatalogField | null;
}

export interface CatalogArea {
  name: CatalogField | null;
  subtitle: CatalogField | null;
  description: CatalogField | null;
  items: CatalogItem[];
}

export interface CatalogMap {
  name: CatalogField | null;
  floor: CatalogField | null;
  areas: CatalogArea[];
}

export interface CatalogTour {
  name: CatalogField | null;
  duration: CatalogField | null;
  description: CatalogField | null;
  items: CatalogItem[];
}

export interface CatalogEntity {
  name: CatalogField | null;
  description: CatalogField | null;
  welcomeMessage: CatalogField | null;
  tours: CatalogTour[];
  maps: CatalogMap[];
  dictionary: Array<{ key: string; value: string }>;
}

export interface Catalog {
  language: string;
  entities: CatalogEntity[];
}

const cache: Record<string, { expiresAt: number; catalog: Catalog }> = {};

/**
 * Indexa recursivamente todos os nós com `documentId` de uma árvore do Strapi,
 * para que o nó equivalente noutro locale possa ser encontrado.
 */
function indexByDocumentId(node: any, index: Record<string, any> = {}): Record<string, any> {
  if (Array.isArray(node)) {
    node.forEach((child) => indexByDocumentId(child, index));
    return index;
  }
  if (!node || typeof node !== 'object') return index;

  if (typeof node.documentId === 'string') {
    index[node.documentId] = node;
  }
  Object.keys(node).forEach((key) => {
    const child = node[key];
    if (child && typeof child === 'object') indexByDocumentId(child, index);
  });
  return index;
}

/**
 * Escolhe o valor de um campo: prefere a tradução oficial no idioma pedido e,
 * na sua ausência, recorre ao original em português marcado como não-oficial.
 */
function pickField(localized: any, base: any, key: string): CatalogField | null {
  const localizedValue = localized ? localized[key] : undefined;
  if (typeof localizedValue === 'string' && localizedValue.trim().length > 0) {
    return { value: localizedValue.trim(), official: true };
  }

  const baseValue = base ? base[key] : undefined;
  if (typeof baseValue === 'string' && baseValue.trim().length > 0) {
    return { value: baseValue.trim(), official: false };
  }

  return null;
}

function buildItem(baseItem: any, index: Record<string, any>): CatalogItem {
  const localized = index[baseItem.documentId];
  return {
    name: pickField(localized, baseItem, 'nameItem'),
    description: pickField(localized, baseItem, 'descriptionItem'),
  };
}

function buildArea(baseArea: any, index: Record<string, any>): CatalogArea {
  const localized = index[baseArea.documentId];
  return {
    name: pickField(localized, baseArea, 'nameArea'),
    subtitle: pickField(localized, baseArea, 'subtitleArea'),
    description: pickField(localized, baseArea, 'descriptionArea'),
    items: (baseArea.items || []).map((item: any) => buildItem(item, index)),
  };
}

function buildMap(baseMap: any, index: Record<string, any>): CatalogMap {
  const localized = index[baseMap.documentId];
  return {
    name: pickField(localized, baseMap, 'nameMap'),
    floor: pickField(localized, baseMap, 'floorMap'),
    areas: (baseMap.areas || []).map((area: any) => buildArea(area, index)),
  };
}

function buildTour(baseTour: any, index: Record<string, any>): CatalogTour {
  const localized = index[baseTour.documentId];
  return {
    name: pickField(localized, baseTour, 'nameTour'),
    duration: pickField(localized, baseTour, 'timeTour'),
    description: pickField(localized, baseTour, 'descriptionTour'),
    items: (baseTour.items || []).map((item: any) => buildItem(item, index)),
  };
}

function buildEntity(baseEntity: any, index: Record<string, any>): CatalogEntity {
  const localized = index[baseEntity.documentId];

  // O dicionário é terminologia de interface: prefere-se a versão localizada,
  // mas um locale pode trazer a lista vazia (é o caso do EN neste catálogo) —
  // daí o teste ao comprimento e não à existência, que com um array vazio
  // (truthy) deixaria o dicionário por preencher em vez de recorrer ao PT.
  const localizedDictionaries = localized && localized.dictionaries;
  const dictionarySource =
    localizedDictionaries && localizedDictionaries.length > 0
      ? localizedDictionaries
      : baseEntity.dictionaries || [];
  const dictionary = dictionarySource
    .filter((entry: any) => entry && entry.key && entry.value)
    .map((entry: any) => ({ key: String(entry.key), value: String(entry.value) }));

  return {
    name: pickField(localized, baseEntity, 'nameEntity'),
    description: pickField(localized, baseEntity, 'descriptionEntity'),
    welcomeMessage: pickField(localized, baseEntity, 'welcome_message'),
    tours: (baseEntity.tours || []).map((tour: any) => buildTour(tour, index)),
    maps: (baseEntity.maps || []).map((map: any) => buildMap(map, index)),
    dictionary,
  };
}

export default ({ strapi }) => ({
  /**
   * Devolve o catálogo completo para o idioma pedido, com cache em processo (5 min).
   * Lança em caso de falha de leitura — o controller trata como assistant_error.
   */
  async getCatalog(language: string): Promise<Catalog> {
    const now = Date.now();
    const cached = cache[language];
    if (cached && cached.expiresAt > now) {
      return cached.catalog;
    }

    // Árvore canónica em PT: é a única garantidamente completa, por isso é a base.
    // Filtrada pela entidade ativa (specs/002-content-source-switch) — nunca a
    // primeira entidade encontrada, e nunca todas as entidades existentes.
    const baseEntities = await strapi.documents('api::entidade.entidade').findMany({
      filters: { documentId: { $eq: ACTIVE_ENTITY_DOCUMENT_ID } },
      locale: BASE_LOCALE,
      status: 'published',
      populate: CATALOG_POPULATE,
    });

    if (!baseEntities || baseEntities.length === 0) {
      throw new EntityNotFoundError(ACTIVE_ENTITY_DOCUMENT_ID);
    }

    // Sobreposição no idioma ativo (quando é o próprio PT, reutiliza-se a base).
    const localizedEntities =
      language === BASE_LOCALE
        ? baseEntities
        : await strapi.documents('api::entidade.entidade').findMany({
            filters: { documentId: { $eq: ACTIVE_ENTITY_DOCUMENT_ID } },
            locale: language,
            status: 'published',
            populate: CATALOG_POPULATE,
          });

    const index = indexByDocumentId(localizedEntities);

    const catalog: Catalog = {
      language,
      entities: baseEntities.map((entity: any) => buildEntity(entity, index)),
    };

    cache[language] = { expiresAt: now + CACHE_TTL_MS, catalog };
    return catalog;
  },
});
