import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

// Kept apart from vite.config.ts so the production build config stays test-free.
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.{ts,tsx}'],
    // Tests stub `fetch` and env vars per file; start every file from a clean slate.
    unstubGlobals: true,
    unstubEnvs: true,
  },
});
