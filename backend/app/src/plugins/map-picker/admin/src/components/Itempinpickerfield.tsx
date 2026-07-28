import React, { useState, useEffect } from 'react';
import {
  useFetchClient,
  useForm,
} from '@strapi/strapi/admin';

// Fator de zoom por omissão (igual ao valor original) — usado até o valor real
// chegar do backend, ou se o pedido falhar.
const DEFAULT_ZOOM_SCALE = 2;

export default function ItemPinPickerField(props: any) {
  const { name, value, onChange } = props;

  // 1. Leitura ao vivo do formulário (funciona mesmo com o documento ainda não gravado)
  const values = useForm('ItemPinPickerField', (state: any) => state.values);
  const setFormValue = useForm('ItemPinPickerField', (state: any) => state.onChange);

  const { get } = useFetchClient();

  const [mapImageUrl, setMapImageUrl] = useState<string | null>(null);
  const [siblingAreas, setSiblingAreas] = useState<any[]>([]);
  const [activeArea, setActiveArea] = useState<{ posX: number; posY: number; nameArea?: string } | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Fator de zoom da entidade ativa (specs/002-content-source-switch) — lido
  // via API em vez de importado estaticamente, para não depender do bundler do
  // plugin resolver um caminho fora da sua própria pasta (config/museum.ts vive
  // em backend/app/src/config, fora deste plugin). Troca automaticamente
  // quando ACTIVE_ENTITY_DOCUMENT_ID muda no backend, sem rebuild do plugin.
  const [zoomScale, setZoomScale] = useState<number>(DEFAULT_ZOOM_SCALE);

  useEffect(() => {
    let cancelled = false;
    get('/api/museum-config/area-zoom')
      .then((res: any) => {
        if (cancelled) return;
        const zoom = res.data?.zoom;
        if (typeof zoom === 'number' && zoom > 0) setZoomScale(zoom);
      })
      .catch((err: any) => {
        console.error('Não foi possível carregar o zoom configurado, a usar o valor por omissão:', err);
      });
    return () => {
      cancelled = true;
    };
  }, [get]);

  // 2. Extração segura do ID da Área a partir do campo de relação 'area' do Item
  function extractAreaId(areaValue: any): string | number | undefined {
    if (!areaValue) return undefined;

    // (a) Estado "dirty" com connect[]
    if (Array.isArray(areaValue.connect) && areaValue.connect.length > 0) {
      const entry = areaValue.connect[0];
      return entry.apiData?.documentId ?? entry.apiData?.id ?? entry.documentId ?? entry.id;
    }

    // (b) Array direto
    if (Array.isArray(areaValue)) {
      return areaValue[0]?.documentId ?? areaValue[0]?.id;
    }

    // (c) Objeto direto
    return areaValue.documentId ?? areaValue.id;
  }

  const areaId = extractAreaId(values?.area);

  // Leitura em tempo real das coordenadas do Item diretamente do formulário
  const currentPosX = values?.posXItem ?? value;
  const currentPosY = values?.posYItem;

  // 3. Fetch cruzado: Área selecionada -> Mapa pai -> todas as Áreas irmãs desse Mapa
  useEffect(() => {
    if (!areaId) {
      setMapImageUrl(null);
      setSiblingAreas([]);
      setActiveArea(null);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    // CORREÇÃO AQUI: Alterado de [image]=true para [imageMap]=true para bater certo com o teu Schema
    get(`/content-manager/collection-types/api::area.area/${areaId}?populate[map][populate][areas]=true&populate[map][populate][imageMap]=true`)
      .then((res) => {
        if (cancelled) return;

        const areaData = res.data?.data ?? res.data; // tolera ambos os formatos de resposta do Strapi v5
        const mapa = areaData?.map;
        const img = mapa?.imageMap;

        setActiveArea({
          posX: Number(areaData?.posX ?? 0),
          posY: Number(areaData?.posY ?? 0),
          nameArea: areaData?.nameArea,
        });

        setMapImageUrl(img?.url || img?.formats?.large?.url || null);

        // Remove a própria Área da lista de "irmãs" (já é o ponto de origem do zoom)
        const irmas = Array.isArray(mapa?.areas) ? mapa.areas : [];
        setSiblingAreas(irmas.filter((a: any) => (a.documentId ?? a.id) !== areaId));
      })
      .catch((err) => {
        console.error('Erro ao carregar dados da Área/Mapa para o Item:', err);
        if (!cancelled) setError('Não foi possível carregar o mapa desta Área.');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [areaId, get]);

  // 4. Matemática do clique
  const handleImageClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    let calcPosX = (e.clientX - rect.left) / rect.width;
    let calcPosY = (e.clientY - rect.top) / rect.height;

    calcPosX = parseFloat(Math.max(0, Math.min(0.9999, calcPosX)).toFixed(4));
    calcPosY = parseFloat(Math.max(0, Math.min(0.9999, calcPosY)).toFixed(4));

    // Atualiza o campo nativo (customField) onde este componente está acoplado
    onChange({ target: { name, value: calcPosX, type: 'decimal' } });

    // Preenche os campos reais de posição do Item
    if (setFormValue) {
      setFormValue({ target: { name: 'posXItem', value: calcPosX, type: 'decimal' } });
      setFormValue({ target: { name: 'posYItem', value: calcPosY, type: 'decimal' } });
    }
  };

  // ---- UI ----

  if (!areaId) {
    return (
      <div style={{ padding: '16px', background: '#eaf5ff', color: '#005b96', borderRadius: '8px', borderLeft: '4px solid #005b96', marginTop: '8px' }}>
        ℹ️ <strong>Ajuda!</strong> Escolha uma <strong>Área</strong> no campo acima para desbloquear o seletor de coordenadas do Item.
      </div>
    );
  }

  if (loading) {
    return <div style={{ padding: '16px', color: '#666' }}>A carregar o mapa interativo...</div>;
  }

  if (error) {
    return (
      <div style={{ padding: '16px', background: '#fcebea', color: '#b72b1a', borderRadius: '8px', borderLeft: '4px solid #b72b1a', marginTop: '8px' }}>
        ❌ {error}
      </div>
    );
  }

  if (!mapImageUrl) {
    return (
      <div style={{ padding: '16px', background: '#fcebea', color: '#b72b1a', borderRadius: '8px', borderLeft: '4px solid #b72b1a', marginTop: '8px' }}>
        ❌ O Mapa associado a esta Área não tem nenhuma imagem. Edite o Mapa em causa e adicione uma imagem primeiro.
      </div>
    );
  }

  const zoomStyle: React.CSSProperties = activeArea
    ? {
        transformOrigin: `${activeArea.posX * 100}% ${activeArea.posY * 100}%`,
        transform: `scale(${zoomScale})`,
        transition: 'transform 0.3s ease-in-out',
      }
    : {};

  return (
    <div style={{ marginTop: '8px' }}>
      <div style={{ marginBottom: '12px', fontSize: '13px', color: '#ffffff' }}>
        <strong>Área:</strong> {activeArea?.nameArea ?? '—'}
        {'  |  '}
        <strong>Coordenadas do Item:</strong> X:{' '}
        <span style={{ color: '#d4af37' }}>{currentPosX ?? '0.0000'}</span> | Y:{' '}
        <span style={{ color: '#d4af37' }}>{currentPosY ?? '0.0000'}</span>
      </div>

      <div
        style={{
          position: 'relative',
          display: 'inline-block',
          overflow: 'hidden',
          border: '2px dashed #dcdce4',
          borderRadius: '8px',
          backgroundColor: '#f6f6f9',
          maxWidth: '100%',
        }}
      >
        <div onClick={handleImageClick} style={{ position: 'relative', display: 'inline-block', cursor: 'crosshair', ...zoomStyle }}>
          <img
            src={mapImageUrl}
            alt="Mapa Interativo (Área ampliada)"
            style={{ maxWidth: '100%', maxHeight: '500px', display: 'block' }}
            draggable={false}
          />

          {/* Pins estáticos das outras Áreas */}
          {siblingAreas.map(
            (sibling: any) =>
              sibling.posX != null &&
              sibling.posY != null && (
                <div
                  key={sibling.documentId ?? sibling.id}
                  title={sibling.nameArea}
                  style={{
                    position: 'absolute',
                    left: `${sibling.posX * 100}%`,
                    top: `${sibling.posY * 100}%`,
                    width: '14px',
                    height: '14px',
                    backgroundColor: 'rgba(140,140,160,0.6)',
                    borderRadius: '50%',
                    transform: 'translate(-50%, -50%)',
                    border: '2px solid white',
                    pointerEvents: 'none',
                  }}
                />
              )
          )}

          {/* Pin da própria Área ativa (origem do zoom) */}
          <div
            title={activeArea?.nameArea}
            style={{
              position: 'absolute',
              left: `${(activeArea?.posX ?? 0) * 100}%`,
              top: `${(activeArea?.posY ?? 0) * 100}%`,
              width: '16px',
              height: '16px',
              borderRadius: '50%',
              transform: 'translate(-50%, -50%)',
              border: '2px dashed #005b96',
              pointerEvents: 'none',
            }}
          />

          {/* Pin do Item */}
          {currentPosX !== undefined && currentPosY !== undefined && currentPosX !== null && currentPosY !== null && (
            <div
              style={{
                position: 'absolute',
                left: `${currentPosX * 100}%`,
                top: `${currentPosY * 100}%`,
                width: '20px',
                height: '20px',
                backgroundColor: '#d4af37',
                borderRadius: '50%',
                transform: 'translate(-50%, -50%)',
                border: '3px solid white',
                boxShadow: '0 2px 8px rgba(0,0,0,0.4)',
                pointerEvents: 'none',
              }}
            />
          )}
        </div>
      </div>

      <p style={{ fontSize: '12px', color: '#666', marginTop: '8px' }}>
        * A imagem está ampliada (zoom {zoomScale}x) e centrada na Área selecionada. Clique no local exato do Item.
      </p>
    </div>
  );
}