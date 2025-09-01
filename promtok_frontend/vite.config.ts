import { defineConfig } from 'vite'
import { fileURLToPath, URL } from 'node:url'
import react from '@vitejs/plugin-react'
import tsconfigPaths from 'vite-tsconfig-paths'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tsconfigPaths()],
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
