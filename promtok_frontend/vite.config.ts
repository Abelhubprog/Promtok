import { defineConfig } from 'vite'
import { fileURLToPath, URL } from 'node:url'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  // Use explicit alias for '@' and avoid duplicate path resolution.
  // Removing vite-tsconfig-paths prevents returning extensionless ids during build.
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    proxy: {
      '/api/ws': {
        target: 'ws://localhost',
        ws: true,
      },
      '/api': {
        target: 'http://localhost',
        changeOrigin: true,
      },
    },
  },
  define: {
    global: 'globalThis',
  },
  build: {
    rollupOptions: {
      external: [],
    },
  },
})
