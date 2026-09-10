import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { useCreateDocument } from '../hooks/use-create-document.ts';
import type { useDocuments } from '../hooks/use-documents.ts';
import type { Document } from '../lib/api.ts';
import DocumentsPage from './DocumentsPage.tsx';

const documentsState = {
  data: undefined as { pages: { data: Document[] }[] } | undefined,
  isPending: false,
  error: null as unknown,
  fetchNextPage: vi.fn(),
  hasNextPage: false,
  isFetchingNextPage: false,
};

const createState = {
  // Mirrors react-query's `mutate(variables, { onSuccess })`: resolve at once.
  mutate: vi.fn((_fileName: string, options?: { onSuccess?: () => void }) => {
    options?.onSuccess?.();
  }),
  isPending: false,
  error: null as unknown,
};

vi.mock('../hooks/use-documents.ts', () => ({
  useDocuments: () => documentsState as unknown as ReturnType<typeof useDocuments>,
}));
vi.mock('../hooks/use-create-document.ts', () => ({
  useCreateDocument: () => createState as unknown as ReturnType<typeof useCreateDocument>,
}));
vi.mock('../hooks/use-signin-on-unauthorized.ts', () => ({
  useSigninOnUnauthorized: () => undefined,
}));

// Testing Library only auto-unmounts between tests when `afterEach` is a global;
// vitest globals are off here, so do it explicitly.
afterEach(cleanup);

beforeEach(() => {
  documentsState.data = undefined;
  documentsState.hasNextPage = false;
  documentsState.fetchNextPage.mockClear();
  createState.mutate.mockClear();
});

describe('DocumentsPage', () => {
  it('renders the empty state when the list is empty', () => {
    documentsState.data = { pages: [{ data: [] }] };

    render(<DocumentsPage />);

    expect(screen.getByText('No documents yet.')).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Load more' })).toBeNull();
  });

  it('lists documents and loads the next page on "Load more"', () => {
    documentsState.data = {
      pages: [
        {
          data: [
            {
              document_id: 'd1',
              user_id: 'u1',
              file_name: 'notes.pdf',
              status: 'PENDING',
              created_at: '2026-09-10T00:00:00Z',
              expires_at: null,
            },
          ],
        },
      ],
    };
    documentsState.hasNextPage = true;

    render(<DocumentsPage />);

    expect(screen.getByText('notes.pdf')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Load more' }));

    expect(documentsState.fetchNextPage).toHaveBeenCalledTimes(1);
  });

  it('creates a document from the trimmed file name and clears the form', async () => {
    documentsState.data = { pages: [{ data: [] }] };

    render(<DocumentsPage />);
    const input = screen.getByLabelText('File name') as HTMLInputElement;

    fireEvent.input(input, { target: { value: '  notes.pdf  ' } });
    fireEvent.submit(screen.getByRole('button', { name: 'Create' }).closest('form')!);

    await waitFor(() => expect(createState.mutate).toHaveBeenCalledTimes(1));
    expect(createState.mutate.mock.calls[0]?.[0]).toBe('notes.pdf');
    await waitFor(() => expect(input.value).toBe(''));
  });
});
