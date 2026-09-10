import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { cleanup, renderHook, waitFor } from '@testing-library/react';
import type { ReactNode } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Document, DocumentPage } from '../lib/api.ts';
import { useDocuments } from './use-documents.ts';

vi.mock('react-oidc-context', () => ({
  useAuth: () => ({ user: { access_token: 'tok', profile: { sub: 'u1' } } }),
}));

vi.mock('../lib/api.ts', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api.ts')>()),
  listDocuments: vi.fn(),
}));

const { listDocuments } = await import('../lib/api.ts');
const listDocumentsMock = vi.mocked(listDocuments);

function doc(id: string): Document {
  return {
    document_id: id,
    user_id: 'u1',
    file_name: `${id}.pdf`,
    status: 'PENDING',
    created_at: '2026-09-10T00:00:00Z',
    expires_at: null,
  };
}

function page(items: Document[], nextCursor: string | null): DocumentPage {
  return {
    data: items,
    meta: {
      page: 1,
      page_size: 1,
      total: 2,
      has_next: nextCursor !== null,
      next_cursor: nextCursor,
    },
  };
}

function wrapper({ children }: { children: ReactNode }) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}

// Testing Library only auto-unmounts between tests when `afterEach` is a global;
// vitest globals are off here, so do it explicitly.
afterEach(cleanup);

beforeEach(() => {
  listDocumentsMock.mockReset();
});

describe('useDocuments', () => {
  it('pages with next_cursor and stops when the API returns null', async () => {
    listDocumentsMock
      .mockResolvedValueOnce(page([doc('d1')], 'cursor-2'))
      .mockResolvedValueOnce(page([doc('d2')], null));

    const { result } = renderHook(() => useDocuments(), { wrapper });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(listDocumentsMock).toHaveBeenLastCalledWith('tok', { limit: 20, cursor: undefined });
    expect(result.current.hasNextPage).toBe(true);

    await result.current.fetchNextPage();

    await waitFor(() => expect(result.current.data?.pages).toHaveLength(2));
    expect(listDocumentsMock).toHaveBeenLastCalledWith('tok', { limit: 20, cursor: 'cursor-2' });
    expect(result.current.data?.pages.flatMap((p) => p.data).map((d) => d.document_id)).toEqual([
      'd1',
      'd2',
    ]);
    expect(result.current.hasNextPage).toBe(false);
  });
});
