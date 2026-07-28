import React from 'react';

// Recebemos os dados dinâmicos através das "props" entre chavetas
export default function KpiCard({ title, value, percentage, isPositive, iconText, iconBg }) {
  
  // Definir a cor do texto da tendência (verde se positivo/bom, vermelho se negativo/mau)
  const trendColor = isPositive ? '#10b981' : '#ef4444';
  const trendArrow = isPositive ? '↗' : '↘';

  return (
    <div style={{
      background: '#ffffff',
      padding: '24px',
      borderRadius: '16px',
      boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03)',
      position: 'relative',
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'space-between',
      border: '1px solid #f3f4f6'
    }}>
      
      {/* Linha do Topo: Título e Ícone */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <span style={{ 
          color: '#8a92a6', 
          fontSize: '12px', 
          fontWeight: '700', 
          letterSpacing: '0.5px' 
        }}>
          {title}
        </span>
        
        {/* Badge do Ícone (Simulado com CSS) */}
        <div style={{
          background: iconBg || '#f3f4f6',
          color: '#4f46e5',
          width: '36px',
          height: '36px',
          borderRadius: '10px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: '16px',
          fontWeight: 'bold'
        }}>
          {iconText}
        </div>
      </div>

      {/* Meio: O Número Gigante */}
      <div style={{ margin: '16px 0 8px 0' }}>
        <h2 style={{ 
          fontSize: '40px', 
          fontWeight: '700', 
          color: '#1d2939', 
          margin: 0,
          lineHeight: '1'
        }}>
          {value}
        </h2>
      </div>

      {/* Rodapé: A Tendência/Percentagem */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '14px' }}>
        <span style={{ color: trendColor, fontWeight: '600', display: 'flex', alignItems: 'center' }}>
          {trendArrow} {percentage}
        </span>
        <span style={{ color: '#8a92a6' }}>vs período anterior</span>
      </div>

    </div>
  );
}