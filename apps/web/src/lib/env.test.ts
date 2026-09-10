import { describe, expect, it, vi } from 'vitest';

const validEnv = {
  VITE_API_BASE_URL: 'https://api.example.com/',
  VITE_COGNITO_AUTHORITY: 'https://cognito-idp.ap-southeast-1.amazonaws.com/ap-southeast-1_abc',
  VITE_COGNITO_CLIENT_ID: 'client-id',
  VITE_COGNITO_DOMAIN: 'https://docmind-dev-abc.auth.ap-southeast-1.amazoncognito.com/',
  VITE_REDIRECT_URI: 'https://app.example.com/',
};

/** env.ts parses at import time, so every case needs a fresh module instance. */
async function loadEnv(overrides: Partial<typeof validEnv> = {}) {
  vi.resetModules();
  for (const [name, value] of Object.entries({ ...validEnv, ...overrides })) {
    vi.stubEnv(name, value);
  }
  const module = await import('./env.ts');
  return module.env;
}

describe('env', () => {
  it('parses a valid environment and strips trailing slashes from base URLs', async () => {
    const env = await loadEnv();

    expect(env.VITE_API_BASE_URL).toBe('https://api.example.com');
    expect(env.VITE_COGNITO_DOMAIN).toBe(
      'https://docmind-dev-abc.auth.ap-southeast-1.amazoncognito.com',
    );
    // The redirect URI keeps its slash: it must match the Cognito callback byte for byte.
    expect(env.VITE_REDIRECT_URI).toBe('https://app.example.com/');
  });

  it('throws a readable error naming the missing variable', async () => {
    // An unfilled `.env.example` copy leaves the value empty, not undefined.
    await expect(loadEnv({ VITE_COGNITO_CLIENT_ID: '' })).rejects.toThrow(
      /Invalid frontend environment[\s\S]*VITE_COGNITO_CLIENT_ID/,
    );
  });

  it('rejects a redirect URI without the trailing slash', async () => {
    await expect(loadEnv({ VITE_REDIRECT_URI: 'https://app.example.com' })).rejects.toThrow(
      /VITE_REDIRECT_URI: must end with "\/"/,
    );
  });
});
