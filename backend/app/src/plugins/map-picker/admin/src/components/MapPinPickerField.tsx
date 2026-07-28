import React, { useState, useEffect } from 'react';
import {
  useFetchClient,
  useForm,
} from '@strapi/strapi/admin'; // useForm lê o estado AO VIVO do formulário (funciona mesmo em documentos ainda não gravados)

export default function MapPinPickerField(props: any) {
  const { name, value, onChange } = props;

  // 1. Extração correta dos valores do formulário (Strapi v5)
  const values = useForm('MapPinPickerField', (state: any) => state.values);
  const setFormValue = useForm('MapPinPickerField', (state: any) => state.onChange);

  const { get } = useFetchClient();
  const [mapImageUrl, setMapImageUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // 2. Leitura Segura do Campo Relation ('map')
  function extractMapId(mapValue: any): string | number | undefined {
    if (!mapValue) return undefined;

    // (a) Estado "dirty" com connect[]
    if (Array.isArray(mapValue.connect) && mapValue.connect.length > 0) {
      const entry = mapValue.connect[0];
      return entry.apiData?.documentId ?? entry.apiData?.id ?? entry.documentId ?? entry.id;
    }

    // (b) Array direto
    if (Array.isArray(mapValue)) {
      return mapValue[0]?.documentId ?? mapValue[0]?.id;
    }

    // (c) Objeto direto
    return mapValue.documentId ?? mapValue.id;
  }

  const mapId = extractMapId(values?.map);

  // DEBUG temporário — remover depois de confirmar que passou a funcionar em todos os casos
  console.log('DEBUG values:', JSON.stringify(values, null, 2));
  console.log('DEBUG mapId:', mapId);

  // ALTERAÇÃO: Leitura em tempo real de AMBOS os campos diretamente do formulário
  const currentPosX = values?.posX ?? value; // Fallback para o value inicial se ainda não houver no estado vivo
  const currentPosY = values?.posY;

  useEffect(() => {
    if (mapId) {
      setLoading(true);
      get(`/content-manager/collection-types/api::map.map/${mapId}?populate=imageMap`)
        .then((res) => {
          const img = res.data?.imageMap || res.data?.data?.imageMap || res.data?.results?.imageMap;
          setMapImageUrl(img?.url || img?.formats?.large?.url || null);
        })
        .catch(err => console.error("Erro ao carregar imagem do mapa:", err))
        .finally(() => setLoading(false));
    } else {
      setMapImageUrl(null);
    }
  }, [mapId, get]);

  // A MATEMÁTICA DO CLIQUE (SIMÉTRICA PARA X E Y)
  const handleImageClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    let calcPosX = (e.clientX - rect.left) / rect.width;
    let calcPosY = (e.clientY - rect.top) / rect.height;

    // Garante que os limites ficam entre 0 e 0.9999 com 4 casas decimais
    calcPosX = parseFloat(Math.max(0, Math.min(0.9999, calcPosX)).toFixed(4));
    calcPosY = parseFloat(Math.max(0, Math.min(0.9999, calcPosY)).toFixed(4));

    // Atualiza o próprio campo nativo onde este componente está acoplado no Strapi
    onChange({ target: { name, value: calcPosX, type: 'decimal' } });

    // ALTERAÇÃO: Força o autopreenchimento de AMBOS os campos 'posX' e 'posY' no formulário do Strapi v5
    if (setFormValue) {
      setFormValue({ target: { name: 'posX', value: calcPosX, type: 'decimal' } });
      setFormValue({ target: { name: 'posY', value: calcPosY, type: 'decimal' } });
    }
  };

  // UI - REQUISITO 1: Não há mapa selecionado
  if (!mapId) {
    return (
      <div style={{ padding: '16px', background: '#eaf5ff', color: '#005b96', borderRadius: '8px', borderLeft: '4px solid #005b96', marginTop: '8px' }}>
        ℹ️ <strong>Ajuda!</strong> Escolha um <strong>Mapa</strong> no campo acima para desbloquear o seletor de coordenadas.
      </div>
    );
  }

  // UI - A carregar
  if (loading) return <div style={{ padding: '16px', color: '#666' }}>A carregar o mapa interativo...</div>;

  // UI - REQUISITO 2: Tem mapa mas sem imagem
  if (!mapImageUrl) {
    return (
      <div style={{ padding: '16px', background: '#fcebea', color: '#b72b1a', borderRadius: '8px', borderLeft: '4px solid #b72b1a', marginTop: '8px' }}>
        ❌ O mapa que selecionou não tem nenhuma imagem associada. Edite o mapa em causa e adicione uma imagem primeiro.
      </div>
    );
  }

  // UI - REQUISITO 3: Sucesso total (Mostra o Mapa)
  return (
    <div style={{ marginTop: '8px' }}>
      <div style={{ marginBottom: '12px', fontSize: '13px', color: '#ffffff' }}>
        {/* ALTERAÇÃO: Agora exibe na interface o valor reativo do currentPosX */}
        <strong>Coordenadas Atuais:</strong> X: <span style={{ color: '#d4af37' }}>{currentPosX ?? '0.0000'}</span> | Y: <span style={{ color: '#d4af37' }}>{currentPosY ?? '0.0000'}</span>
      </div>

      <div
        onClick={handleImageClick}
        style={{
          position: 'relative',
          display: 'inline-block',
          cursor: 'crosshair',
          border: '2px dashed #dcdce4',
          borderRadius: '8px',
          overflow: 'hidden',
          backgroundColor: '#f6f6f9'
        }}
      >
        <img
          src={mapImageUrl}
          alt="Mapa Interativo"
          style={{ maxWidth: '100%', maxHeight: '500px', display: 'block' }}
          draggable={false}
        />

        {/* ALTERAÇÃO: Renderização do Pin baseada inteiramente nas variáveis vivas do formulário */}
        {currentPosX !== undefined && currentPosY !== undefined && currentPosX !== null && currentPosY !== null && (
          <div style={{
            position: 'absolute',
            left: `${currentPosX * 100}%`,
            top: `${currentPosY * 100}%`,
            width: '24px',
            height: '24px',
            backgroundColor: '#d4af37',
            borderRadius: '50%',
            transform: 'translate(-50%, -50%)',
            border: '3px solid white',
            boxShadow: '0 2px 8px rgba(0,0,0,0.4)',
            pointerEvents: 'none'
          }} />
        )}
      </div>
      <p style={{ fontSize: '12px', color: '#666', marginTop: '8px' }}>
        * Clique em qualquer local da imagem para posicionar o Pin. A conversão de proporção para Android é feita automaticamente.
      </p>
    </div>
  );
}