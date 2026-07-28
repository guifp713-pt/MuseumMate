// vite.config.ts ou src/admin/vite.config.ts
import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    allowedHosts: [
      'landowner-upload-dollop.ngrok-free.dev',
      '.ngrok-free.dev' // Isso permite qualquer subdomínio do ngrok
    ],
  },
});