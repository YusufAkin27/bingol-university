import { defineConfig, devices } from '@playwright/test';

/**
 * Tarayici (E2E) testleri: Vite gelistirme sunucusunu kendi portunda acar, API istekleri
 * VITE_DEV_BACKEND adresindeki calisan backend'e proxy'lenir.
 *
 *   E2E_PORT=5181 VITE_DEV_BACKEND=http://localhost:8080 npx playwright test
 *
 * Paralel ajanlar/gelistiriciler cakismasin diye E2E_PORT her calismada farkli verilebilir.
 */
const port = Number(process.env.E2E_PORT || 5190);
const backend = process.env.VITE_DEV_BACKEND || 'http://localhost:8080';
// E2E_BASE_URL verilirse (ornek: http://localhost:8090 uretim benzeri nginx) Vite sunucusu acilmaz.
const external = process.env.E2E_BASE_URL;

export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  expect: { timeout: 7_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list']],
  outputDir: './e2e/.results',
  use: {
    baseURL: external || `http://localhost:${port}`,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    locale: 'tr-TR',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: external ? undefined : {
    command: `npx vite --port ${port} --strictPort`,
    port,
    reuseExistingServer: true,
    env: { VITE_DEV_PORT: String(port), VITE_DEV_BACKEND: backend },
    timeout: 60_000,
  },
});
