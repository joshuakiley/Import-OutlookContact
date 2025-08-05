import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    host: '0.0.0.0',
    port: 5000,
    strictPort: true
  },
  preview: {
    host: '0.0.0.0',
    port: 5000,
    strictPort: true
  },
  build: {
    target: 'es2022',
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'msal': ['@microsoft/msal-browser'],
          'validation': ['zod', 'dompurify']
        }
      }
    }
  },
  define: {
    // Security: Prevent accidental exposure of sensitive env vars
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV)
  }
});
