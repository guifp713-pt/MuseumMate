import { PinMap } from '@strapi/icons';

export default {
  register(app: any) {
    // Customfield existente — Áreas
    app.customFields.register({
      name: 'pin-picker',
      pluginId: 'map-picker',
      type: 'decimal',
      intlLabel: {
        id: 'map-picker.label',
        defaultMessage: '📍 Seletor de Pin (Mapa)',
      },
      intlDescription: {
        id: 'map-picker.description',
        defaultMessage: 'Clica na imagem do mapa para gerar as coordenadas automaticamente',
      },
      icon: PinMap,
      components: {
        Input: async () => import('./components/MapPinPickerField'),
      },
    });

    // Novo customField — Itens (usa a Área selecionada para descobrir o Mapa e aplicar zoom)
    app.customFields.register({
      name: 'item-pin-picker',
      pluginId: 'map-picker',
      type: 'decimal',
      intlLabel: {
        id: 'map-picker.item-label',
        defaultMessage: '📍 Seletor de Pin do Item (com Zoom na Área)',
      },
      intlDescription: {
        id: 'map-picker.item-description',
        defaultMessage: 'Clica na imagem ampliada da Área para posicionar o Item automaticamente',
      },
      icon: PinMap,
      components: {
        Input: async () => import('./components/Itempinpickerfield'),
      },
    });
  },
  bootstrap() {},
};