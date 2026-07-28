import * as React from 'react';
import { useState, useEffect } from 'react';
import { useFetchClient } from '@strapi/strapi/admin'; // Importação corrigida para Strapi v5

interface Coordinates {
  posX: number;
  posY: number;
}

export default function HomePage() {
  const { get, put } = useFetchClient();
  const [areas, setAreas] = useState<any[]>([]);
  const [selectedArea, setSelectedArea] = useState<any>(null);
  const [coordinates, setCoordinates] = useState<Coordinates | null>(null);
  const [loading, setLoading] = useState(false);

  // 1. Carregar as Áreas (e os Mapas associados) via API do Strapi
  useEffect(() => {
    async function loadAreas() {
      try {
        // Usamos a API do Content Manager para não termos problemas de permissões públicas
        // A sintaxe "populate" vai buscar a relação do mapa e a imagem do mapa.
        const response = await get('/content-manager/collection-types/api::area.area?populate[map][populate]=imageMap'); 
        
        // O Strapi v5 pode enviar os dados dentro de .results ou .data dependendo do endpoint
        const fetchedAreas = response.data?.results || response.data?.data || response.data || [];
        setAreas(fetchedAreas);
      } catch (error) {
        console.error("Erro ao carregar áreas:", error);
      }
    }
    loadAreas();
  }, [get]);

  // 2. Lógica Exata do QML convertida para React (Cálculo de Percentagem)
  const handleMapClick = (event: React.MouseEvent<HTMLDivElement>) => {
    // getBoundingClientRect dá-nos o tamanho real e atual da imagem na tela do admin
    const rect = event.currentTarget.getBoundingClientRect();
    
    // Onde o clique ocorreu em relação ao topo/esquerda da imagem
    const clickX = event.clientX - rect.left;
    const clickY = event.clientY - rect.top;

    // Conversão para percentagem (0.0 a 1.0)
    let calcPosX = clickX / rect.width;
    let calcPosY = clickY / rect.height;

    // Clamping para garantir que não ultrapassa os limites 0.0000 e 0.9999
    calcPosX = Math.max(0, Math.min(0.9999, calcPosX));
    calcPosY = Math.max(0, Math.min(0.9999, calcPosY));

    // Guarda no estado limitando a 4 casas decimais (como no teu DB)
    setCoordinates({
      posX: parseFloat(calcPosX.toFixed(4)),
      posY: parseFloat(calcPosY.toFixed(4))
    });
  };

  // 3. Salvar os dados na base de dados
  const handleSavePosition = async () => {
    if (!selectedArea || !coordinates) return;
    setLoading(true);
    
    try {
      // documentId é a norma no Strapi v5
      const targetId = selectedArea.documentId || selectedArea.id;
      
      await put(`/content-manager/collection-types/api::area.area/${targetId}`, {
        // Os campos têm de bater certo com a tua arquitetura
        posX: coordinates.posX,
        posY: coordinates.posY
      });
      
      alert('📍 Posição salva com sucesso!');
      
      // Atualizar o estado local para refletir a nova posição guardada
      setSelectedArea({ ...selectedArea, posX: coordinates.posX, posY: coordinates.posY });
    } catch (error) {
      console.error("Erro ao salvar:", error);
      alert('❌ Ocorreu um erro ao salvar a posição.');
    } finally {
      setLoading(false);
    }
  };

  // Função auxiliar para encontrar com segurança o URL da imagem do mapa
  const getMapImageUrl = (area: any) => {
    const map = area?.map;
    if (!map) return null;
    
    // Dependendo de como o Strapi constrói a resposta, a imagem pode estar aninhada
    const image = map.imageMap;
    return image?.url || image?.formats?.large?.url || null;
  };

  return (
    <div style={{ padding: '40px', fontFamily: 'sans-serif', backgroundColor: '#f6f6f9', minHeight: '100vh' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 'bold', marginBottom: '8px' }}>📍 Posicionador de Pins</h1>
      <p style={{ color: '#666', marginBottom: '32px' }}>Selecione uma área para registar as suas coordenadas no mapa.</p>
      
      {/* SELETOR DE ÁREAS */}
      <div style={{ marginBottom: '24px', maxWidth: '400px' }}>
        <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold', fontSize: '14px' }}>
          Área de Trabalho:
        </label>
        <select 
          onChange={(e) => {
            const areaId = e.target.value;
            // Procuramos a área pelo documentId ou pelo id clássico
            const area = areas.find(a => String(a.documentId) === areaId || String(a.id) === areaId);
            setSelectedArea(area || null);
            setCoordinates(area && area.posX !== null && area.posY !== null ? { posX: area.posX, posY: area.posY } : null);
          }}
          defaultValue=""
          style={{ width: '100%', padding: '12px', borderRadius: '6px', border: '1px solid #dcdce4', backgroundColor: 'white' }}
        >
          <option value="" disabled>-- Selecione uma Área --</option>
          {areas.map((area) => (
            <option key={area.documentId || area.id} value={area.documentId || area.id}>
              {area.nameArea || `Área sem nome (${area.id})`}
            </option>
          ))}
        </select>
      </div>

      {/* REQUISITO 1: Nenhuma área selecionada */}
      {!selectedArea && (
        <div style={{ padding: '16px', background: '#eaf5ff', color: '#005b96', borderRadius: '8px', borderLeft: '4px solid #005b96' }}>
          ℹ️ <strong>Passo 1:</strong> Selecione uma área na lista acima para começar. Se não houver áreas, crie uma primeiro no Content Manager.
        </div>
      )}

      {/* Lógica se a área estiver selecionada */}
      {selectedArea && (() => {
        const urlImagemMapa = getMapImageUrl(selectedArea);

        // REQUISITO 2: Área não tem mapa (ou mapa não tem imagem)
        if (!urlImagemMapa) {
          return (
            <div style={{ padding: '16px', background: '#fcebea', color: '#b72b1a', borderRadius: '8px', borderLeft: '4px solid #b72b1a' }}>
              ❌ <strong>Atenção:</strong> A área "{selectedArea.nameArea}" não possui nenhum Mapa associado (ou o Mapa não tem imagem). 
              <br/>Por favor, associe um Mapa a esta Área no Content Manager antes de posicionar o pin.
            </div>
          );
        }

        // REQUISITO 3: Sucesso - Mostrar mapa interativo
        return (
          <div style={{ background: 'white', padding: '24px', borderRadius: '8px', boxShadow: '0 1px 4px rgba(33, 33, 52, 0.1)' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
              <div style={{ fontSize: '14px' }}>
                <strong>Mapa:</strong> {selectedArea.map?.nameMap || 'Desconhecido'} <br/>
                <strong>Coordenadas a Salvar:</strong> 
                <span style={{ color: '#d4af37', marginLeft: '8px', fontWeight: 'bold' }}>
                  X: {coordinates?.posX ?? '0.0000'} | Y: {coordinates?.posY ?? '0.0000'}
                </span>
              </div>
              
              <button 
                onClick={handleSavePosition}
                disabled={loading || !coordinates}
                style={{
                  padding: '12px 24px',
                  backgroundColor: loading ? '#9ca3af' : '#27b70f',
                  color: 'white',
                  border: 'none',
                  borderRadius: '6px',
                  fontWeight: 'bold',
                  cursor: loading ? 'not-allowed' : 'pointer',
                  transition: 'background-color 0.2s'
                }}
              >
                {loading ? 'A Guardar...' : '💾 Salvar Posição'}
              </button>
            </div>

            {/* CONTAINER DO MAPA */}
            <div style={{ border: '2px dashed #dcdce4', padding: '16px', backgroundColor: '#f6f6f9', textAlign: 'center' }}>
              <div 
                onClick={handleMapClick}
                style={{ 
                  position: 'relative', 
                  display: 'inline-block', // Mantém a div exatamente do tamanho da imagem
                  cursor: 'crosshair',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.1)'
                }}
              >
                <img 
                  // Se o URL vier como caminho relativo (ex: /uploads/mapa.png), o browser resolve sozinho 
                  src={urlImagemMapa} 
                  alt="Mapa" 
                  style={{ display: 'block', maxWidth: '100%', maxHeight: '600px', width: 'auto', height: 'auto' }}
                  draggable={false}
                />

                {/* PIN VISUAL (Usa exatamente a mesma lógica do QML) */}
                {coordinates && (
                  <div 
                    style={{
                      position: 'absolute',
                      left: `${coordinates.posX * 100}%`,
                      top: `${coordinates.posY * 100}%`,
                      width: '24px',
                      height: '24px',
                      backgroundColor: '#d4af37', // Dourado que usas na app
                      borderRadius: '50%',
                      transform: 'translate(-50%, -50%)', // Centra o Pin perfeitamente na coordenada
                      border: '3px solid white',
                      boxShadow: '0 2px 8px rgba(0,0,0,0.4)',
                      pointerEvents: 'none' // Impede que clicar no pin interfira no clique do mapa
                    }}
                  />
                )}
              </div>
              <p style={{ marginTop: '12px', fontSize: '12px', color: '#666' }}>
                * Clique em qualquer parte da imagem para reposicionar o Pin.
              </p>
            </div>

          </div>
        );
      })()}
    </div>
  );
}