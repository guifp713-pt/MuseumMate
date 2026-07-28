import React, { useState, useEffect, useMemo } from 'react';
import KpiCard from '../components/KpiCard';

// =========================================================================
// 🧠 1. CONSTRUTOR DE PERÍODOS (Puro UTC, Sem Dependência de Timezone Local)
// =========================================================================
export function buildPeriod(periodoAtivo) {
  const agora = new Date();
  
  const hojeAno = agora.getUTCFullYear();
  const hojeMes = agora.getUTCMonth();
  const hojeDia = agora.getUTCDate();

  // Constante base em milissegundos para evitar mutação direta e bugs de transição de mês
  const baseMs = Date.UTC(hojeAno, hojeMes, hojeDia, 0, 0, 0, 0);
  const ONE_DAY_MS = 24 * 60 * 60 * 1000;

  let inicioAtual, fimAtual, inicioAnterior, fimAnterior;

  if (periodoAtivo === 'hoje') {
    inicioAtual = new Date(baseMs);
    fimAtual = new Date(baseMs + ONE_DAY_MS - 1);
    inicioAnterior = new Date(baseMs - ONE_DAY_MS);
    fimAnterior = new Date(baseMs - 1);
  } else if (periodoAtivo === '7d') {
    inicioAtual = new Date(baseMs - 6 * ONE_DAY_MS);
    fimAtual = new Date(baseMs + ONE_DAY_MS - 1);
    inicioAnterior = new Date(baseMs - 13 * ONE_DAY_MS);
    fimAnterior = new Date(baseMs - 6 * ONE_DAY_MS - 1);
  } else if (periodoAtivo === '30d') {
    inicioAtual = new Date(baseMs - 29 * ONE_DAY_MS);
    fimAtual = new Date(baseMs + ONE_DAY_MS - 1);
    inicioAnterior = new Date(baseMs - 59 * ONE_DAY_MS);
    fimAnterior = new Date(baseMs - 29 * ONE_DAY_MS - 1);
  } else if (periodoAtivo === 'ano') {
    inicioAtual = new Date(Date.UTC(hojeAno, 0, 1, 0, 0, 0, 0));
    fimAtual = new Date(Date.UTC(hojeAno, 11, 31, 23, 59, 59, 999));
    inicioAnterior = new Date(Date.UTC(hojeAno - 1, 0, 1, 0, 0, 0, 0));
    fimAnterior = new Date(Date.UTC(hojeAno - 1, 11, 31, 23, 59, 59, 999));
  }

  return {
    inicioAtual,
    fimAtual,
    inicioAnterior,
    fimAnterior,
    dataISO: inicioAnterior.toISOString() 
  };
}

// =========================================================================
// 🧠 2. NORMALIZADOR DE EVENTOS (Suporte Strapi v4/v5 & Sanitização de Id)
// =========================================================================
export function normalizeEvent(eventoCru) {
  if (!eventoCru) return null;
  const e = eventoCru.attributes || eventoCru;
  
  let parsedItemId = null;
  if (e.itemId !== null && e.itemId !== undefined) {
    parsedItemId = Number(e.itemId);
    if (isNaN(parsedItemId)) parsedItemId = e.itemId;
  }

  const linguaCrua = e.metadata?.language || e.metadata?.lingua || e.language || 'en';

  return {
    timestamp: e.timestamp ? new Date(e.timestamp) : null,
    eventType: e.eventType || null,
    itemId: parsedItemId,
    language: linguaCrua.toLowerCase().trim().substring(0, 2),
    deviceId: e.metadata?.deviceId || e.sessionId || null
  };
}

// =========================================================================
// 🧪 2.5 NOVA ETAPA DA PIPELINE: AGREGADOR ESTRUTURAL DOS DADOS DO GRÁFICO
// =========================================================================
export function buildChartData(eventosNormalizados, periodoConfig, periodoAtivo) {
  const { inicioAtual, fimAtual } = periodoConfig;

  // Filtrar APENAS eventos que representam uma visita ("visit_start") contidos no intervalo
  const eventosFiltrados = eventosNormalizados.filter(e => {
    return (
      e && 
      e.timestamp && 
      e.timestamp >= inicioAtual && 
      e.timestamp <= fimAtual && 
      e.eventType === 'visit_start'
    );
  });

  if (periodoAtivo === 'hoje') {
    const contadores = { '10h': 0, '12h': 0, '14h': 0, '16h': 0, '18h': 0 };
    
    eventosFiltrados.forEach(e => {
      const hora = e.timestamp.getUTCHours();
      if (hora <= 10) contadores['10h']++;
      else if (hora <= 12) contadores['12h']++;
      else if (hora <= 14) contadores['14h']++;
      else if (hora <= 16) contadores['16h']++;
      else contadores['18h']++;
    });

    return Object.keys(contadores).map(key => ({ label: key, visitas: contadores[key] }));
  }

  if (periodoAtivo === '7d') {
    const diasMapa = {};
    for (let i = 6; i >= 0; i--) {
      const d = new Date(inicioAtual.getTime());
      d.setUTCDate(d.getUTCDate() + (6 - i));
      const label = `${String(d.getUTCDate()).padStart(2, '0')}/${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
      diasMapa[label] = 0;
    }

    eventosFiltrados.forEach(e => {
      const label = `${String(e.timestamp.getUTCDate()).padStart(2, '0')}/${String(e.timestamp.getUTCMonth() + 1).padStart(2, '0')}`;
      if (diasMapa[label] !== undefined) {
        diasMapa[label]++;
      }
    });

    return Object.keys(diasMapa).map(key => ({ label: key, visitas: diasMapa[key] }));
  }

  if (periodoAtivo === '30d') {
    const contadores = { 'Semana 1': 0, 'Semana 2': 0, 'Semana 3': 0, 'Semana 4': 0 };
    const diffTotalMs = fimAtual.getTime() - inicioAtual.getTime();
    const tamanhoSemanaMs = diffTotalMs / 4;

    eventosFiltrados.forEach(e => {
      const diffEventMs = e.timestamp.getTime() - inicioAtual.getTime();
      if (diffEventMs <= tamanhoSemanaMs) contadores['Semana 1']++;
      else if (diffEventMs <= tamanhoSemanaMs * 2) contadores['Semana 2']++;
      else if (diffEventMs <= tamanhoSemanaMs * 3) contadores['Semana 3']++;
      else contadores['Semana 4']++;
    });

    return Object.keys(contadores).map(key => ({ label: key, visitas: contadores[key] }));
  }

  if (periodoAtivo === 'ano') {
    const mesesLabels = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    const contadores = {};
    mesesLabels.forEach(m => { contadores[m] = 0; });

    eventosFiltrados.forEach(e => {
      const mesIdx = e.timestamp.getUTCMonth();
      const label = mesesLabels[mesIdx];
      if (contadores[label] !== undefined) {
        contadores[label]++;
      }
    });

    return mesesLabels.map(m => ({ label: m, visitas: contadores[m] }));
  }

  return [];
}

// =========================================================================
// 🧪 2.6 NOVA FUNÇÃO: AGREGADOR DE DADOS PARA O GRÁFICO DE TOP ITENS
// =========================================================================
export function buildTopItemsChartData(eventosNormalizados, periodoConfig, nomesDosItens) {
  const { inicioAtual, fimAtual } = periodoConfig;
  const contagemItens = {};

  eventosNormalizados.forEach(e => {
    // 1. Filtrar pelo período ativo
    if (e && e.timestamp && e.timestamp >= inicioAtual && e.timestamp <= fimAtual) {
      // 2. Garantir que apenas 'item_view' é contabilizado
      if (e.eventType === 'item_view' && e.itemId !== null && e.itemId !== undefined) {
        if (!contagemItens[e.itemId]) {
          contagemItens[e.itemId] = 0;
        }
        contagemItens[e.itemId]++;
      }
    }
  });

  // 3. Mapear, atribuir nomes e ordenar
  const resultados = Object.keys(contagemItens).map(id => {
    return {
      itemId: id,
      nome: nomesDosItens[id] || `Item #${id}`,
      visualizacoes: contagemItens[id]
    };
  });

  // 4. Ordenar decrescente e retornar apenas os 8 mais vistos
  return resultados
    .sort((a, b) => b.visualizacoes - a.visualizacoes)
    .slice(0, 8);
}

// =========================================================================
// 🧠 3. CALCULO DE ESTATÍSTICAS ANALÍTICAS (Isolado e com Logs de Auditoria)
// =========================================================================
export function calculateStats(eventosNormalizados, periodoConfig, nomesDosItens = {}) {
  const { inicioAtual, fimAtual, inicioAnterior, fimAnterior } = periodoConfig;

  let atualTotalVisitas = 0;
  let anteriorTotalVisitas = 0;

  const contagemIdiomasAtual = {};
  const contagemIdiomasAnterior = {};
  const contagemItems = {};

  eventosNormalizados.forEach(e => {
    if (!e || !e.timestamp) return;

    const t = e.timestamp;
    const noAtual = t >= inicioAtual && t <= fimAtual;
    const noAnterior = t >= inicioAnterior && t <= fimAnterior;

    // Contagem rigorosa EXCLUSIVA da métrica de Visitas Iniciais (sincronizada com o Gráfico)
    if (noAtual && e.eventType === 'visit_start') atualTotalVisitas++;
    if (noAnterior && e.eventType === 'visit_start') anteriorTotalVisitas++;

    if (!noAtual && !noAnterior) return;

    if (noAtual && e.itemId !== null) {
      if (!contagemItems[e.itemId]) {
        contagemItems[e.itemId] = { views: 0, scans: 0 };
      }
      if (e.eventType === 'item_view') {
        contagemItems[e.itemId].views++;
      } else if (e.eventType === 'scan_success' || e.eventType === 'scan_sucess') {
        contagemItems[e.itemId].scans++;
      }
    }

    if (e.deviceId) {
      const mapaDoPeriodo = noAtual ? contagemIdiomasAtual : contagemIdiomasAnterior;
      if (!mapaDoPeriodo[e.deviceId]) {
        mapaDoPeriodo[e.deviceId] = { pt: 0, en: 0, es: 0, fr: 0, totalCliquesUser: 0 };
      }

      if (mapaDoPeriodo[e.deviceId][e.language] !== undefined) {
        mapaDoPeriodo[e.deviceId][e.language]++;
      } else {
        mapaDoPeriodo[e.deviceId].t++;
      }
      mapaDoPeriodo[e.deviceId].totalCliquesUser++;
    }
  });

  let itemMaisVistoId = null;
  let maxViews = 0;
  let scansDoItemMaisVisto = 0;

  Object.keys(contagemItems).forEach(id => {
    if (contagemItems[id].views > maxViews) {
      maxViews = contagemItems[id].views;
      itemMaisVistoId = id;
      scansDoItemMaisVisto = contagemItems[id].scans;
    }
  });

  const itemMaisVistoNome = itemMaisVistoId
    ? (nomesDosItens[itemMaisVistoId] || `Carregando item #${itemMaisVistoId}...`)
    : "Nenhum item visto";

  const itemMaisVistoDetalhes = itemMaisVistoId
    ? `${maxViews} views (${scansDoItemMaisVisto} scans)`
    : "0 views (0 scans)";

  const atualTotal = atualTotalVisitas;
  const anteriorTotal = anteriorTotalVisitas;

  let percentagemVisitas = "0%";
  let isPositiveVisitas = true;

  if (anteriorTotal === 0 && atualTotal > 0) {
    percentagemVisitas = `+100%`;
  } else if (anteriorTotal > 0) {
    const diff = ((atualTotal - anteriorTotal) / anteriorTotal) * 100;
    isPositiveVisitas = diff >= 0;
    percentagemVisitas = `${diff >= 0 ? '+' : ''}${diff.toFixed(1)}%`;
  } else if (anteriorTotal > 0 && atualTotal === 0) {
    percentagemVisitas = "-100%";
    isPositiveVisitas = false;
  }

  // ✅ 1. Usar APENAS os utilizadores do período atual para o cálculo da distribuição
  const utilizadoresUnicosAtual = Object.keys(contagemIdiomasAtual).length;

  const consolidacaoGlobalIdiomas = { pt: 0, en: 0, es: 0, fr: 0 };

  const acumularVotos = (mapaDoPeriodo) => {
    Object.values(mapaDoPeriodo).forEach(user => {
      if (user.totalCliquesUser > 0) {
        consolidacaoGlobalIdiomas.pt += user.pt / user.totalCliquesUser;
        consolidacaoGlobalIdiomas.en += user.en / user.totalCliquesUser;
        consolidacaoGlobalIdiomas.es += user.es / user.totalCliquesUser;
        consolidacaoGlobalIdiomas.fr += user.fr / user.totalCliquesUser;
      }
    });
  };

  // ✅ 2. Acumular APENAS os dados de hoje/período ativo
  acumularVotos(contagemIdiomasAtual);

  let topIdioma = 'EN';
  let topPercentagemStr = '0%';
  let maxVotosAcumulados = -1;

  const distribuicaoIdiomas = ['pt', 'en', 'es', 'fr'].map(lang => {
    const pesoFracionado = consolidacaoGlobalIdiomas[lang];
    
    // ✅ 3. O divisor passa a ser estritamente os utilizadores atuais
    const percentagemNum = utilizadoresUnicosAtual > 0 
      ? (pesoFracionado / utilizadoresUnicosAtual) * 100 
      : 0;

    if (pesoFracionado > maxVotosAcumulados) {
      maxVotosAcumulados = pesoFracionado;
      topIdioma = lang.toUpperCase();
      topPercentagemStr = `${percentagemNum.toFixed(1)}%`;
    }

    return {
      code: lang.toUpperCase(),
      label: lang === 'pt' ? 'Português (PT)' : lang === 'en' ? 'Inglês (EN)' : lang === 'es' ? 'Espanhol (ES)' : 'Francês (FR)',
      percentageStr: `${percentagemNum.toFixed(1)}%`,
      percentageNum: percentagemNum,
      corBarra: lang === 'pt' ? '#10b981' : lang === 'en' ? '#3b82f6' : lang === 'es' ? '#f59e0b' : '#a855f7'
    };
  });

  distribuicaoIdiomas.sort((a, b) => b.percentageNum - a.percentageNum);

  return {
    total: atualTotal,
    anteriorTotal,
    percentagem: percentagemVisitas,
    isPositive: isPositiveVisitas,
    idiomaPrincipal: topIdioma,
    idiomaPrincipalPercentagem: topPercentagemStr,
    distribuicaoIdiomas,
    itemMaisVistoNome,
    itemMaisVistoDetalhes
  };
}

// =========================================================================
// 🧠 4. CUSTOM HOOK DE GESTÃO E CAPTURA DE DADOS (useAnalytics OTIMIZADO)
// =========================================================================
function useAnalytics(periodoAtivo, dataLimiteISO) {
  const [eventosPuros, setEventosPuros] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isBackgroundRefreshing, setIsBackgroundRefreshing] = useState(false); 
  const [error, setError] = useState(null);
  const [loadingProgress, setLoadingProgress] = useState({ paginaAtual: 1, totalPaginas: 1, eventosCarregados: 0 });

  useEffect(() => {
    let isMounted = true;
    let timerId = null;

    async function fetchAnalytics(isBackground = false) {
      try {
        if (!isBackground) setLoading(true);
        else setIsBackgroundRefreshing(true);
        setError(null);

        let acumulado = [];
        let paginaAtual = 1;
        let totalDePaginas = 1;
        
        do {
          const endpoint = `http://localhost:1337/api/analytics-events?publicationState=preview&pagination[page]=${paginaAtual}&pagination[pageSize]=100&sort=id:desc`;
          
          const response = await fetch(endpoint);
          if (!response.ok) throw new Error('Falha na comunicação com o Strapi.');
          
          const result = await response.json();

          if (result.data && Array.isArray(result.data)) {
            acumulado = [...acumulado, ...result.data];
          }

          if (result.meta?.pagination) {
            totalDePaginas = result.meta.pagination.pageCount;
          } else {
            break;
          }

          if (isMounted) {
            setLoadingProgress({
              paginaAtual: paginaAtual,
              totalPaginas: totalDePaginas || 1,
              eventosCarregados: acumulado.length
            });
          }

          paginaAtual++;
        } while (paginaAtual <= totalDePaginas);

        if (isMounted) {
          setEventosPuros(acumulado);
        }
      } catch (err) {
        if (isMounted) setError(err.message);
      } finally {
        if (isMounted) {
          setLoading(false);
          setIsBackgroundRefreshing(false);
        }
      }
    }

    fetchAnalytics(false);

    timerId = setInterval(() => {
      fetchAnalytics(true);
    }, 10000); 

    return () => {
      isMounted = false;
      clearInterval(timerId);
    };
  }, [periodoAtivo, dataLimiteISO]);

  const eventosNormalizados = useMemo(() => {
    if (!eventosPuros || eventosPuros.length === 0) return [];
    return eventosPuros.map(normalizeEvent).filter(Boolean);
  }, [eventosPuros]);

  return { eventosNormalizados, loading, isBackgroundRefreshing, error, loadingProgress };
}

// =========================================================================
// 📊 4.5 COMPONENTE DE GRÁFICO TOTALMENTE "BURRO" (Evolução Visitas)
// =========================================================================
export function EvolucaoVisitasChart({ dados }) {
  const [activeTooltip, setActiveTooltip] = useState(null);
  const dadosAtuais = dados && dados.length > 0 ? dados : [{ label: 'Sem dados', visitas: 0 }];

  const svgWidth = 600;
  const svgHeight = 135; 
  const paddingLeft = 35;
  const paddingRight = 20;
  const paddingTop = 15;
  const paddingBottom = 22;

  const chartWidth = svgWidth - paddingLeft - paddingRight;
  const chartHeight = svgHeight - paddingTop - paddingBottom;

  const maxValorRaw = Math.max(...dadosAtuais.map(d => d.visitas), 10);
  const magnitude = Math.pow(10, Math.floor(Math.log10(maxValorRaw)));
  const divisorEixo = magnitude / 2 > 0 ? magnitude / 2 : 1;
  const maxEixoY = Math.ceil(maxValorRaw / divisorEixo) * divisorEixo;

  const pontos = dadosAtuais.map((d, index) => {
    const divisorHorizontal = dadosAtuais.length > 1 ? dadosAtuais.length - 1 : 1;
    const x = paddingLeft + (index / divisorHorizontal) * chartWidth;
    const y = paddingTop + chartHeight - (d.visitas / maxEixoY) * chartHeight;
    return { x, y, label: d.label, visitas: d.visitas };
  });

  let linePathD = '';
  let areaPathD = '';

  if (pontos.length > 0) {
    linePathD = `M ${pontos[0].x} ${pontos[0].y}`;
    for (let i = 1; i < pontos.length; i++) {
      linePathD += ` L ${pontos[i].x} ${pontos[i].y}`;
    }
    areaPathD = `${linePathD} L ${pontos[pontos.length - 1].x} ${paddingTop + chartHeight} L ${pontos[0].x} ${paddingTop + chartHeight} Z`;
  }

  const linhasGrelhaY = [0, 0.5, 1].map(proporcao => {
    const valor = maxEixoY * proporcao;
    const y = paddingTop + chartHeight - (valor / maxEixoY) * chartHeight;
    return { y, valor };
  });

  return (
    <div style={{ width: '100%', overflow: 'visible', position: 'relative' }}>
      <div style={{ minWidth: '100%', position: 'relative' }}>
        <svg viewBox={`0 0 ${svgWidth} ${svgHeight}`} style={{ width: '100%', height: 'auto', display: 'block', overflow: 'visible' }}>
          <defs>
            <linearGradient id="visitasGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#3b82f6" stopOpacity="0.14" />
              <stop offset="100%" stopColor="#3b82f6" stopOpacity="0.00" />
            </linearGradient>
          </defs>

          {linhasGrelhaY.map((linha, idx) => (
            <g key={idx}>
              <line
                x1={paddingLeft}
                y1={linha.y}
                x2={svgWidth - paddingRight}
                y2={linha.y}
                stroke="#f3f4f6"
                strokeWidth="1"
              />
              <text
                x={paddingLeft - 8}
                y={linha.y + 3.5}
                textAnchor="end"
                style={{ fontSize: '10px', fill: '#9ca3af', fontFamily: 'monospace', fontWeight: '400' }}
              >
                {Math.round(linha.valor).toLocaleString()}
              </text>
            </g>
          ))}

          {areaPathD && <path d={areaPathD} fill="url(#visitasGradient)" />}

          {linePathD && (
            <path
              d={linePathD}
              fill="none"
              stroke="#3b82f6"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          )}

          {pontos.map((ponto, idx) => (
            <g 
              key={idx} 
              onMouseEnter={(e) => {
                const rect = e.currentTarget.ownerSVGElement.getBoundingClientRect();
                const scaleX = rect.width / svgWidth;
                const scaleY = rect.height / svgHeight;
                setActiveTooltip({
                  label: ponto.label,
                  visitas: ponto.visitas,
                  x: ponto.x * scaleX,
                  y: ponto.y * scaleY
                });
              }}
              onMouseMove={(e) => {
                if (!activeTooltip) return;
                const rect = e.currentTarget.ownerSVGElement.getBoundingClientRect();
                const scaleX = rect.width / svgWidth;
                const scaleY = rect.height / svgHeight;
                setActiveTooltip(prev => prev ? {
                  ...prev,
                  x: ponto.x * scaleX,
                  y: ponto.y * scaleY
                } : null);
              }}
              onMouseLeave={() => setActiveTooltip(null)}
              style={{ cursor: 'pointer' }}
            >
              <circle cx={ponto.x} cy={ponto.y} r="12" fill="transparent" />
              <circle
                cx={ponto.x}
                cy={ponto.y}
                r="3.5"
                fill="#ffffff"
                stroke="#3b82f6"
                strokeWidth="2"
                style={{ transition: 'r 0.15s ease', r: activeTooltip?.label === ponto.label ? '5' : '3.5' }}
              />
            </g>
          ))}

          {pontos.map((ponto, idx) => (
            <text
              key={idx}
              x={ponto.x}
              y={paddingTop + chartHeight + 14}
              textAnchor="middle"
              style={{ fontSize: '10px', fill: '#9ca3af', fontWeight: '400' }}
            >
              {ponto.label}
            </text>
          ))}
        </svg>

        {activeTooltip && (
          <div style={{
            position: 'absolute',
            left: `${activeTooltip.x}px`,
            top: `${activeTooltip.y - 65}px`,
            transform: 'translateX(-50%)',
            backgroundColor: '#1e293b',
            color: '#ffffff',
            padding: '10px 16px',
            borderRadius: '8px',
            fontSize: '13px',
            fontFamily: 'Inter, sans-serif',
            boxShadow: '0 6px 16px rgba(0, 0, 0, 0.2)',
            pointerEvents: 'none',
            zIndex: 50,
            whiteSpace: 'nowrap',
            display: 'flex',
            flexDirection: 'column',
            gap: '4px',
            alignItems: 'center',
            transition: 'opacity 0.1s ease, top 0.1s ease, left 0.1s ease'
          }}>
            <div style={{ fontWeight: '500', opacity: 0.8, fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              {activeTooltip.label}
            </div>
            <div style={{ fontWeight: '700', fontSize: '14px' }}>
              Visitas: <span style={{ color: '#60a5fa' }}>{activeTooltip.visitas}</span>
            </div>
            <div style={{
              width: '0',
              height: '0',
              borderLeft: '6px solid transparent',
              borderRight: '6px solid transparent',
              borderTop: '6px solid #1e293b',
              position: 'absolute',
              bottom: '-5px',
              left: '50%',
              transform: 'translateX(-50%)'
            }} />
          </div>
        )}
      </div>
    </div>
  );
}

// =========================================================================
// 📊 4.6 NOVO COMPONENTE: GRÁFICO TOP ITENS (Barras Horizontais)
// =========================================================================
export function TopItemsChart({ dados }) {
  const [activeTooltip, setActiveTooltip] = useState(null);
  const dadosAtuais = dados && dados.length > 0 ? dados : [{ nome: 'Nenhum item visualizado', visualizacoes: 0 }];

  const svgWidth = 800;
  const svgHeight = 320; 
  // O padding esquerdo é maior para acomodar os nomes compridos dos itens
  const paddingLeft = 240; 
  const paddingRight = 40;
  const paddingTop = 20;
  const paddingBottom = 30;

  const chartWidth = svgWidth - paddingLeft - paddingRight;
  const chartHeight = svgHeight - paddingTop - paddingBottom;

  const maxValorRaw = Math.max(...dadosAtuais.map(d => d.visualizacoes), 5);
  const magnitude = Math.pow(10, Math.floor(Math.log10(maxValorRaw)));
  const divisorEixo = magnitude / 2 > 0 ? magnitude / 2 : 1;
  const maxEixoX = Math.ceil(maxValorRaw / divisorEixo) * divisorEixo;

  const stepY = chartHeight / dadosAtuais.length;
  // Altura da barra ligeiramente menor que o espaçamento (step) para dar um respiro visual
  const barHeight = Math.min(stepY * 0.6, 24);

  // Linhas verticais da grelha de fundo (indicando a quantidade de views)
  const linhasGrelhaX = [0, 0.25, 0.5, 0.75, 1].map(proporcao => {
    const valor = maxEixoX * proporcao;
    const x = paddingLeft + (valor / maxEixoX) * chartWidth;
    return { x, valor };
  });

  const truncateText = (text, maxLength) => {
    if (text.length > maxLength) return text.substring(0, maxLength - 3) + '...';
    return text;
  };

  return (
    <div style={{ width: '100%', overflow: 'visible', position: 'relative' }}>
      <div style={{ minWidth: '100%', position: 'relative' }}>
        <svg viewBox={`0 0 ${svgWidth} ${svgHeight}`} style={{ width: '100%', height: 'auto', display: 'block', overflow: 'visible' }}>
          
          {/* Grelha de Fundo Vertical */}
          {linhasGrelhaX.map((linha, idx) => (
            <g key={`grid-${idx}`}>
              <line
                x1={linha.x}
                y1={paddingTop}
                x2={linha.x}
                y2={svgHeight - paddingBottom}
                stroke="#f3f4f6"
                strokeWidth="1"
              />
              <text
                x={linha.x}
                y={svgHeight - paddingBottom + 16}
                textAnchor="middle"
                style={{ fontSize: '10px', fill: '#9ca3af', fontFamily: 'monospace', fontWeight: '400' }}
              >
                {Math.round(linha.valor).toLocaleString()}
              </text>
            </g>
          ))}

          {/* Barras e Textos */}
          {dadosAtuais.map((d, i) => {
            const yCentro = paddingTop + i * stepY + stepY / 2;
            const yBarra = yCentro - barHeight / 2;
            const barWidth = maxEixoX > 0 ? (d.visualizacoes / maxEixoX) * chartWidth : 0;
            const barWidthVisual = Math.max(barWidth, 4); // Garante que há pelo menos um traço visível mesmo com zero/poucos dados
            
            const isHovered = activeTooltip?.nome === d.nome;

            return (
              <g 
                key={i}
                onMouseEnter={(e) => {
                  const rect = e.currentTarget.ownerSVGElement.getBoundingClientRect();
                  const scaleX = rect.width / svgWidth;
                  const scaleY = rect.height / svgHeight;
                  setActiveTooltip({
                    nome: d.nome,
                    visualizacoes: d.visualizacoes,
                    x: (paddingLeft + barWidthVisual / 2) * scaleX,
                    y: yBarra * scaleY
                  });
                }}
                onMouseLeave={() => setActiveTooltip(null)}
                style={{ cursor: 'pointer' }}
              >
                {/* Zona de hover invisível para facilitar a interação com o rato */}
                <rect 
                  x={0} 
                  y={yCentro - stepY / 2} 
                  width={svgWidth} 
                  height={stepY} 
                  fill="transparent" 
                />

                {/* Nome do Item (Esquerda do eixo) */}
                <text
                  x={paddingLeft - 16}
                  y={yCentro}
                  textAnchor="end"
                  alignmentBaseline="central"
                  style={{ 
                    fontSize: '12px', 
                    fill: isHovered ? '#1e3a8a' : '#4b5563', 
                    fontWeight: isHovered ? '600' : '500',
                    transition: 'all 0.2s ease'
                  }}
                >
                  {truncateText(d.nome, 32)}
                </text>

                {/* Barra */}
                <rect
                  x={paddingLeft}
                  y={yBarra}
                  width={barWidthVisual}
                  height={barHeight}
                  rx="4"
                  ry="4"
                  fill={isHovered ? '#2563eb' : '#3b82f6'}
                  style={{ transition: 'fill 0.2s ease, width 0.5s ease-out' }}
                />

                {/* Valor da barra (Direita da barra, se couber, ou em cima dela) */}
                <text
                  x={paddingLeft + barWidthVisual + 10}
                  y={yCentro}
                  alignmentBaseline="central"
                  style={{ 
                    fontSize: '11px', 
                    fill: '#6b7280', 
                    fontWeight: '600',
                    opacity: isHovered ? 1 : 0.7,
                    transition: 'opacity 0.2s ease'
                  }}
                >
                  {d.visualizacoes > 0 ? d.visualizacoes : ''}
                </text>
              </g>
            );
          })}
        </svg>

        {/* Tooltip */}
        {activeTooltip && (
          <div style={{
            position: 'absolute',
            left: `${activeTooltip.x}px`,
            top: `${activeTooltip.y - 10}px`,
            transform: 'translate(-50%, -100%)',
            backgroundColor: '#1e293b',
            color: '#ffffff',
            padding: '10px 16px',
            borderRadius: '8px',
            fontSize: '13px',
            fontFamily: 'Inter, sans-serif',
            boxShadow: '0 6px 16px rgba(0, 0, 0, 0.2)',
            pointerEvents: 'none',
            zIndex: 50,
            whiteSpace: 'nowrap',
            display: 'flex',
            flexDirection: 'column',
            gap: '4px',
            alignItems: 'center',
            transition: 'opacity 0.1s ease, top 0.1s ease, left 0.1s ease'
          }}>
            <div style={{ fontWeight: '500', opacity: 0.8, fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              {activeTooltip.nome}
            </div>
            <div style={{ fontWeight: '700', fontSize: '14px' }}>
              Visualizações: <span style={{ color: '#60a5fa' }}>{activeTooltip.visualizacoes}</span>
            </div>
            <div style={{
              width: '0',
              height: '0',
              borderLeft: '6px solid transparent',
              borderRight: '6px solid transparent',
              borderTop: '6px solid #1e293b',
              position: 'absolute',
              bottom: '-5px',
              left: '50%',
              transform: 'translateX(-50%)'
            }} />
          </div>
        )}
      </div>
    </div>
  );
}

// =========================================================================
// 🎨 5. COMPONENTE PRINCIPAL (HomePage)
// =========================================================================
export function HomePage() {
  const [periodoAtivo, setPeriodoAtivo] = useState('hoje');
  const [nomesDosItens, setNomesDosItens] = useState({});
  
  const periodoConfig = useMemo(() => buildPeriod(periodoAtivo), [periodoAtivo]);

  const { eventosNormalizados, loading, isBackgroundRefreshing, error, loadingProgress } = useAnalytics(periodoAtivo, periodoConfig.dataISO);

  useEffect(() => {
    async function carregarNomesDoStrapi() {
      try {
        const response = await fetch('http://localhost:1337/api/items?pagination[pageSize]=100');
        if (!response.ok) return;
        const result = await response.json();
        if (result.data && Array.isArray(result.data)) {
          const dicionario = {};
          result.data.forEach(item => {
            const nome = item.nameItem || item.attributes?.nameItem;
            if (nome) dicionario[item.id] = nome;
          });
          setNomesDosItens(dicionario);
        }
      } catch (err) {
        console.error("Erro ao sincronizar mapeamento de itens:", err);
      }
    }
    carregarNomesDoStrapi();
  }, []);

  const formatarVisualUTC = (dObj) => {
    return dObj.toISOString().split('T')[0];
  };

  const stats = useMemo(() => {
    return calculateStats(eventosNormalizados, periodoConfig, nomesDosItens);
  }, [eventosNormalizados, periodoConfig, nomesDosItens]);

  const dadosGrafico = useMemo(() => {
    return buildChartData(eventosNormalizados, periodoConfig, periodoAtivo);
  }, [eventosNormalizados, periodoConfig, periodoAtivo]);

  // Instanciar os dados do novo gráfico Top Items
  const dadosTopItems = useMemo(() => {
    return buildTopItemsChartData(eventosNormalizados, periodoConfig, nomesDosItens);
  }, [eventosNormalizados, periodoConfig, nomesDosItens]);

  if (loading) {
    const percentagemProgresso = Math.min(
      Math.round((loadingProgress.paginaAtual / loadingProgress.totalPaginas) * 100),
      100
    );

    return (
      <div style={{ padding: '32px', fontFamily: 'Inter, system-ui, sans-serif', backgroundColor: '#f9fafb', minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <style>{`
          @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
          @keyframes pulseText { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
          .custom-spinner { width: 50px; height: 50px; border: 4px solid #e5e7eb; border-top: 4px solid #2563eb; border-radius: 50%; animation: spin 1s linear infinite; margin-bottom: 20px; }
          .pulse-loading-text { animation: pulseText 1.8s ease-in-out infinite; }
        `}</style>
        <div style={{ background: '#ffffff', padding: '40px', borderRadius: '16px', boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.05)', border: '1px solid #e5e7eb', textAlign: 'center', maxWidth: '460px', width: '100%' }}>
          <div style={{ display: 'flex', justifyContent: 'center' }}><div className="custom-spinner"></div></div>
          <h3 style={{ margin: '0 0 8px 0', fontSize: '18px', fontWeight: '700', color: '#1e3a8a' }}>Sincronização Base de Dados</h3>
          <p className="pulse-loading-text" style={{ color: '#4b5563', fontSize: '14px', margin: '0 0 24px 0', fontWeight: '500' }}>⏳ A calcular balanço proporcional...</p>
          <div style={{ backgroundColor: '#f3f4f6', borderRadius: '9999px', height: '10px', width: '100%', overflow: 'hidden', marginBottom: '16px' }}>
            <div style={{ width: `${percentagemProgresso}%`, height: '100%', backgroundColor: '#2563eb', borderRadius: '9999px', transition: 'width 0.3s ease-out' }}></div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', color: '#6b7280', fontSize: '12px', fontWeight: '600', borderTop: '1px solid #f3f4f6', paddingTop: '14px' }}>
            <span>Página: {loadingProgress.paginaAtual} / {loadingProgress.totalPaginas}</span>
            <span style={{ color: '#059669', backgroundColor: '#ecfdf5', padding: '2px 8px', borderRadius: '4px' }}>{loadingProgress.eventosCarregados.toLocaleString()} eventos lidos</span>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return <div style={{ padding: '32px', color: '#ef4444', fontFamily: 'sans-serif' }}>❌ Erro: {error}</div>;
  }

  const obterLabelsUI = (periodo) => {
    const dataAtualStr = `${formatarVisualUTC(periodoConfig.inicioAtual)} a ${formatarVisualUTC(periodoConfig.fimAtual)}`;
    const dataAnteriorStr = `${formatarVisualUTC(periodoConfig.inicioAnterior)} a ${formatarVisualUTC(periodoConfig.fimAnterior)}`;

    switch (periodo) {
      case 'hoje':
        return {
          kpiVisitasTitulo: 'VISITAS HOJE',
          tabelaAtualLabel: 'Hoje',
          tabelaAnteriorLabel: 'Dia Anterior',
          tabelaDataAtual: formatarVisualUTC(periodoConfig.inicioAtual),
          tabelaDataAnterior: formatarVisualUTC(periodoConfig.inicioAnterior),
          contextoComparativo: 'vs dia ant.'
        };
      case '7d':
        return {
          kpiVisitasTitulo: 'VISITAS DA SEMANA',
          tabelaAtualLabel: 'Últimos 7 dias',
          tabelaAnteriorLabel: '7 dias anteriores',
          tabelaDataAtual: dataAtualStr,
          tabelaDataAnterior: dataAnteriorStr,
          contextoComparativo: 'vs semana ant.'
        };
      case '30d':
        return {
          kpiVisitasTitulo: 'VISITAS DO MÊS',
          tabelaAtualLabel: 'Últimos 30 dias',
          tabelaAnteriorLabel: '30 dias anteriores',
          tabelaDataAtual: dataAtualStr,
          tabelaDataAnterior: dataAnteriorStr,
          contextoComparativo: 'vs mês ant.'
        };
      case 'ano':
        return {
          kpiVisitasTitulo: 'VISITAS DO ANO',
          tabelaAtualLabel: 'Ano Atual',
          tabelaAnteriorLabel: 'Ano Anterior',
          tabelaDataAtual: dataAtualStr,
          tabelaDataAnterior: dataAnteriorStr,
          contextoComparativo: 'vs ano ant.'
        };
      default:
        return { kpiVisitasTitulo: 'VISITAS', tabelaAtualLabel: 'Atual', tabelaAnteriorLabel: 'Anterior', tabelaDataAtual: '', tabelaDataAnterior: '', contextoComparativo: 'vs período ant.' };
    }
  };

  const labelsUI = obterLabelsUI(periodoAtivo);
  const btnStyle = (ativo) => ({ padding: '8px 16px', borderRadius: '6px', fontSize: '14px', cursor: 'pointer', marginRight: '8px', border: ativo ? '1px solid #2563eb' : '1px solid #e5e7eb', backgroundColor: ativo ? '#eff6ff' : '#fff', color: ativo ? '#2563eb' : '#4b5563', fontWeight: ativo ? '600' : '400', transition: 'all 0.2s ease' });

  return (
    <div style={{ padding: '32px', fontFamily: 'Inter, system-ui, sans-serif', backgroundColor: '#f9fafb', minHeight: '100vh', color: '#111827' }}>

      {/* Cabeçalho */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', borderBottom: '1px solid #e5e7eb', paddingBottom: '16px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: '800', margin: 0, color: '#1e3a8a' }}>MUSEUM MATE — DASHBOARD DE ANALÍTICA</h1>
          <p style={{ color: '#6b7280', margin: '4px 0 0 0', fontSize: '14px' }}>Métricas baseadas no balanço proporcional de cliques por utilizador único</p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          {isBackgroundRefreshing && (
            <span style={{ fontSize: '12px', color: '#2563eb', animation: 'pulseText 1s infinite' }}>🔄 Atualizando...</span>
          )}
          <div style={{ fontSize: '12px', backgroundColor: '#e0e7ff', color: '#4338ca', padding: '6px 12px', borderRadius: '9999px', fontWeight: '600' }}>● Ajuste Proporcional Ativo</div>
        </div>
      </div>

      {/* Filtros */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
        <div style={{ display: 'flex' }}>
          <button style={btnStyle(periodoAtivo === 'hoje')} onClick={() => setPeriodoAtivo('hoje')}>Hoje</button>
          <button style={btnStyle(periodoAtivo === '7d')} onClick={() => setPeriodoAtivo('7d')}>Últimos 7 dias</button>
          <button style={btnStyle(periodoAtivo === '30d')} onClick={() => setPeriodoAtivo('30d')}>Últimos 30 dias</button>
          <button style={btnStyle(periodoAtivo === 'ano')} onClick={() => setPeriodoAtivo('ano')}>Ano</button>
        </div>
      </div>

      {/* ZONA 1: KPIs */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '24px', marginBottom: '32px' }}>
        <KpiCard
          title={labelsUI.kpiVisitasTitulo}
          value={stats.total.toString()}
          percentage={`${stats.percentagem} ${labelsUI.contextoComparativo}`}
          isPositive={stats.isPositive}
          iconText=""
          iconBg="#f0fdf4"
        />
        <KpiCard
          title="IDIOMA DOMINANTE"
          value={stats.idiomaPrincipal}
          percentage={`${stats.idiomaPrincipalPercentagem} de presença estatística`}
          isPositive={true}
          iconText=""
          iconBg="#eff6ff"
        />
        <KpiCard
          title="ITEM MAIS VISITADO"
          value={stats.itemMaisVistoNome}
          percentage={stats.itemMaisVistoDetalhes}
          isPositive={true}
          iconText=""
          iconBg="#fff1f2"
        />
      </div>

      {/* ZONA 2: Área Analítica Reorganizada */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        
        {/* Linha 1: Tabela Comparativa (Esquerda) & Distribuição de Idiomas (Direita) */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(350px, 1fr))', gap: '24px' }}>
          
          {/* Cartão 1: Tabela Comparativa */}
          <div style={{ background: '#fff', padding: '20px', borderRadius: '12px', border: '1px solid #e5e7eb', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <h3 style={{ margin: '0 0 12px 0', fontSize: '15px', fontWeight: '700', color: '#1e3a8a' }}>Visitas por Período Comparativo</h3>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px', textAlign: 'left' }}>
                <thead>
                  <tr style={{ borderBottom: '2px solid #e5e7eb', color: '#4b5563' }}>
                    <th style={{ padding: '8px 6px' }}>Intervalo Temporal</th>
                    <th style={{ padding: '8px 6px' }}>Contexto</th>
                    <th style={{ padding: '8px 6px' }}>Visitantes Únicos</th>
                  </tr>
                </thead>
                <tbody>
                  <tr style={{ borderBottom: '1px solid #f3f4f6' }}>
                    <td style={{ padding: '10px 6px', fontFamily: 'monospace', fontSize: '12px', color: '#4b5563' }}>{labelsUI.tabelaDataAnterior}</td>
                    <td><span style={{ backgroundColor: '#f3f4f6', padding: '2px 6px', borderRadius: '4px', fontSize: '11px' }}>{labelsUI.tabelaAnteriorLabel}</span></td>
                    <td style={{ padding: '10px 6px', fontWeight: '700', color: '#1e3a8a' }}>{stats.anteriorTotal}</td>
                  </tr>
                  <tr>
                    <td style={{ padding: '10px 6px', fontFamily: 'monospace', fontSize: '12px', color: '#111827' }}>{labelsUI.tabelaDataAtual}</td>
                    <td><span style={{ backgroundColor: '#ecfdf5', color: '#065f46', padding: '2px 6px', borderRadius: '4px', fontSize: '11px', fontWeight: '600' }}>{labelsUI.tabelaAtualLabel}</span></td>
                    <td style={{ padding: '10px 6px', fontWeight: '700', color: '#059669' }}>{stats.total}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          {/* Cartão 2: Distribuição de Idiomas */}
          <div style={{ background: '#fff', padding: '20px', borderRadius: '12px', border: '1px solid #e5e7eb' }}>
            <h3 style={{ margin: '0 0 14px 0', fontSize: '15px', fontWeight: '700', color: '#1e3a8a' }}>Distribuição de Idiomas</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {stats.distribuicaoIdiomas.map((idioma) => (
                <div key={idioma.code} style={{ display: 'flex', alignItems: 'center' }}>
                  <div style={{ width: '130px', fontSize: '12px', fontWeight: '500' }}>{idioma.label}</div>
                  <div style={{ flexGrow: 1, height: '7px', backgroundColor: '#e5e7eb', borderRadius: '9999px', marginRight: '10px', overflow: 'hidden' }}>
                    <div style={{ width: idioma.percentageStr, height: '100%', backgroundColor: idioma.corBarra, transition: 'width 0.4s ease-out' }}></div>
                  </div>
                  <div style={{ width: '50px', fontSize: '12px', fontWeight: '600', textAlign: 'right' }}>{idioma.percentageStr}</div>
                </div>
              ))}
            </div>
          </div>

        </div>

        {/* Linha 2: Gráfico de Evolução das Visitas (Largura Total) */}
        <div style={{ background: '#fff', padding: '20px', borderRadius: '12px', border: '1px solid #e5e7eb', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
          <div>
            <h3 style={{ margin: '0 0 2px 0', fontSize: '15px', fontWeight: '700', color: '#1e3a8a' }}>Evolução das Visitas</h3>
            <p style={{ margin: '0 0 10px 0', color: '#6b7280', fontSize: '12px' }}>Acompanhamento do tráfego iniciado no período ativo</p>
          </div>
          <EvolucaoVisitasChart dados={dadosGrafico} />
        </div>

        {/* Linha 3: NOVO GRÁFICO (Itens Mais Vistos) */}
        <div style={{ background: '#fff', padding: '20px', borderRadius: '12px', border: '1px solid #e5e7eb', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
          <div>
            <h3 style={{ margin: '0 0 2px 0', fontSize: '15px', fontWeight: '700', color: '#1e3a8a' }}>Itens Mais Vistos</h3>
            <p style={{ margin: '0 0 10px 0', color: '#6b7280', fontSize: '12px' }}>Top itens por número de visualizações</p>
          </div>
          <TopItemsChart dados={dadosTopItems} />
        </div>

      </div>
    </div>
  );
}