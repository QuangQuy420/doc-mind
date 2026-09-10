import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, apiFetch, isUnauthorized, listDocuments, retryQuery } from './api.ts';

vi.mock('./env.ts', () => ({
  env: {
    VITE_API_BASE_URL: 'https://api.test',
    VITE_COGNITO_AUTHORITY: 'https://issuer.test',
    VITE_COGNITO_CLIENT_ID: 'client-id',
    VITE_COGNITO_DOMAIN: 'https://auth.test',
    VITE_REDIRECT_URI: 'https://app.test/',
  },
}));

const fetchMock = vi.fn<typeof fetch>();

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function lastRequest(): { url: string; init: RequestInit } {
  const call = fetchMock.mock.calls.at(-1);
  if (!call) {
    throw new Error('fetch was not called');
  }
  return { url: String(call[0]), init: call[1] ?? {} };
}

async function expectApiError(promise: Promise<unknown>): Promise<ApiError> {
  try {
    await promise;
  } catch (error) {
    expect(error).toBeInstanceOf(ApiError);
    return error as ApiError;
  }
  throw new Error('expected the call to throw ApiError');
}

beforeEach(() => {
  fetchMock.mockReset();
  vi.stubGlobal('fetch', fetchMock);
});

describe('apiFetch', () => {
  it('unwraps { data } and sends the bearer token and JSON body', async () => {
    fetchMock.mockResolvedValue(jsonResponse({ data: { ok: true } }, 201));

    const result = await apiFetch<{ ok: boolean }>('/documents', {
      token: 'tok',
      method: 'POST',
      body: { file_name: 'a.pdf' },
    });

    expect(result).toEqual({ data: { ok: true }, meta: undefined });
    const { url, init } = lastRequest();
    expect(url).toBe('https://api.test/documents');
    expect(init.method).toBe('POST');
    expect(init.headers).toMatchObject({
      Authorization: 'Bearer tok',
      'Content-Type': 'application/json',
    });
    expect(init.body).toBe(JSON.stringify({ file_name: 'a.pdf' }));
  });

  it('returns meta alongside data for paginated responses', async () => {
    const meta = { page: 1, page_size: 20, total: 1, has_next: false, next_cursor: null };
    fetchMock.mockResolvedValue(jsonResponse({ data: [{ id: 1 }], meta }));

    const result = await apiFetch<unknown[]>('/documents', { token: 'tok' });

    expect(result.data).toEqual([{ id: 1 }]);
    expect(result.meta).toEqual(meta);
  });

  it('throws ApiError carrying the envelope code, status and details', async () => {
    fetchMock.mockResolvedValue(
      jsonResponse(
        { error: { code: 'UNAUTHORIZED', message: 'Token expired', details: { hint: 'x' } } },
        401,
      ),
    );

    const error = await expectApiError(apiFetch('/me', { token: 'tok' }));

    expect(error.code).toBe('UNAUTHORIZED');
    expect(error.message).toBe('Token expired');
    expect(error.status).toBe(401);
    expect(error.details).toEqual({ hint: 'x' });
    expect(isUnauthorized(error)).toBe(true);
  });

  it('maps a non-JSON 5xx to INTERNAL_ERROR instead of leaking status text', async () => {
    fetchMock.mockResolvedValue(
      new Response('<html>Bad Gateway</html>', { status: 502, statusText: 'Bad Gateway' }),
    );

    const error = await expectApiError(apiFetch('/documents', { token: 'tok' }));

    expect(error.code).toBe('INTERNAL_ERROR');
    expect(error.status).toBe(502);
    expect(isUnauthorized(error)).toBe(false);
  });

  it('throws NETWORK_ERROR with status 0 when fetch itself fails', async () => {
    fetchMock.mockRejectedValue(new TypeError('Failed to fetch'));

    const error = await expectApiError(apiFetch('/me', { token: 'tok' }));

    expect(error.code).toBe('NETWORK_ERROR');
    expect(error.status).toBe(0);
  });
});

describe('retryQuery', () => {
  it('never retries a 4xx from the API, so UNAUTHORIZED redirects at once', () => {
    expect(retryQuery(0, new ApiError('UNAUTHORIZED', 'expired', 401))).toBe(false);
    expect(retryQuery(0, new ApiError('NOT_FOUND', 'gone', 404))).toBe(false);
  });

  it('retries transient failures at most twice', () => {
    const network = new ApiError('NETWORK_ERROR', 'offline', 0);
    expect(retryQuery(0, network)).toBe(true);
    expect(retryQuery(1, new ApiError('INTERNAL_ERROR', 'boom', 502))).toBe(true);
    expect(retryQuery(2, network)).toBe(false);
  });
});

describe('listDocuments', () => {
  it('passes limit and cursor as query params and omits unset ones', async () => {
    const meta = { page: 1, page_size: 2, total: 3, has_next: true, next_cursor: 'c2' };
    fetchMock.mockResolvedValue(jsonResponse({ data: [], meta }));

    const page = await listDocuments('tok', { limit: 2, cursor: 'c1' });

    expect(page.meta.next_cursor).toBe('c2');
    const { url } = lastRequest();
    expect(url).toBe('https://api.test/documents?limit=2&cursor=c1');
  });

  it('rejects a list response that comes back without meta', async () => {
    fetchMock.mockResolvedValue(jsonResponse({ data: [] }));

    const error = await expectApiError(listDocuments('tok'));

    expect(error.code).toBe('INVALID_RESPONSE');
  });
});
