#!/bin/sh

echo "📦 Creating backup..."

tar -czf /backup/backup.tar.gz \
  --exclude=node_modules \
  --exclude=.cache \
  --exclude=build \
  -C /app .

echo "✅ Backup created!"