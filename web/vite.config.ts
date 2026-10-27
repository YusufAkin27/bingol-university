/// <reference types="vitest/globals" />
import { loadEnv } from 'vite';
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '');
  const backend = env.VITE_DEV_BACKEND || 'http://localhost:8080';
  return {
    plugins: [react()],
    server: {
      port: Number(env.VITE_DEV_PORT || 5173),
      proxy: {
        '/api': { target: backend, changeOrigin: false },
        '/files': { target: backend, changeOrigin: false },
        '/ws': { target: backend, changeOrigin: false, ws: true },
      },
    },
    // preview de aynı proxy'yi kullanır (derlenmiş uygulamayı yerelde denemek için)
    preview: {
      port: 4173,
      proxy: {
        '/api': { target: backend, changeOrigin: false },
        '/files': { target: backend, changeOrigin: false },
      },
    },
    build: {
      sourcemap: false,
      chunkSizeWarningLimit: 600,
      rollupOptions: {
        output: {
          // büyük bağımlılıklar ayrı, uzun süre önbelleklenebilir parçalar olur
          manualChunks(id: string) {
            if (!id.includes('node_modules')) return undefined;
            if (/recharts|d3-|victory-vendor/.test(id)) return 'vendor-charts';
            if (/react-router|@remix-run/.test(id)) return 'vendor-router';
            if (/@tanstack/.test(id)) return 'vendor-query';
            if (/[/]react(-dom)?[/]|scheduler/.test(id)) return 'vendor-react';
            return undefined;
          },
        },
      },
    },
    test: {
      environment: 'jsdom',
      globals: true,
      setupFiles: ['./src/test/setup.ts'],
      css: { modules: { classNameStrategy: 'non-scoped' as const } },
      include: ['src/**/*.test.{ts,tsx}'],
      coverage: {
        provider: 'v8' as const,
        reporter: ['text-summary', 'lcov', 'html'],
        reportsDirectory: 'coverage',
        include: ['src/**/*.{ts,tsx}'],
        exclude: ['src/**/*.test.{ts,tsx}', 'src/test/**', 'src/**/*.d.ts', 'src/main.tsx'],
      },
    },
  };
});
