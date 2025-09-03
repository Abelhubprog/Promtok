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
    // Relax chunk size warnings (we also apply manualChunks below)
    chunkSizeWarningLimit: 1600,
    rollupOptions: {
      external: [],
      output: {
        // Split large deps to keep the main bundle leaner
        manualChunks: {
          vendor: [
            'react',
            'react-dom',
            'react-router-dom',
            'zustand',
            'axios',
          ],
          editor: [
            '@tiptap/react',
            '@tiptap/starter-kit',
            'easymde',
            'react-simplemde-editor',
          ],
          markdown: [
            'react-markdown',
            'remark-gfm',
            'remark-math',
            'rehype-raw',
            'rehype-katex',
            'katex',
          ],
        },
      },
    },
  },
})
