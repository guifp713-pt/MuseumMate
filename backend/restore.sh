#!/bin/sh

echo "🚀 Starting Strapi container..."

# Criar projeto se não existir
if [ ! -f "/app/package.json" ]; then
  echo "📦 Creating Strapi project..."
  npx create-strapi-app@latest /app --quickstart --no-run --skip-cloud
fi

cd /app

# Instalar dependências globais do Strapi
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.bin/strapi" ]; then
  echo "📥 Installing global dependencies..."
  npm install
fi

# Iniciar Watch Mode para TODOS os plugins locais detetados
for plugin in src/plugins/*; do
  if [ -d "$plugin" ] && [ -f "$plugin/package.json" ]; then
    echo "📊 Custom plugin detected: $plugin"
    (
      cd "$plugin"
      # Instala dependências do plugin se não existirem
      if [ ! -d "node_modules" ]; then
        echo "📥 Installing dependencies for $plugin..."
        npm install
      fi
      echo "👀 Starting watch mode for $plugin..."
      npm run watch
    ) &
  fi
done

echo "🔥 Starting Strapi with Admin Watch..."
npx strapi develop --watch-admin