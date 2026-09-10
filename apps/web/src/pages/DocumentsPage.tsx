import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { useCreateDocument } from '../hooks/use-create-document.ts';
import { useDocuments } from '../hooks/use-documents.ts';
import { useSigninOnUnauthorized } from '../hooks/use-signin-on-unauthorized.ts';
import { ApiError } from '../lib/api.ts';

// Same bounds as the API's CreateDocumentRequest, so a bad name fails in the
// browser instead of costing a round trip.
const createDocumentSchema = z.object({
  file_name: z
    .string()
    .trim()
    .min(1, 'File name is required')
    .max(255, 'File name must be at most 255 characters'),
});

type CreateDocumentForm = z.infer<typeof createDocumentSchema>;

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof ApiError ? error.message : fallback;
}

function DocumentsPage() {
  const { data, isPending, error, fetchNextPage, hasNextPage, isFetchingNextPage } = useDocuments();
  const createDocument = useCreateDocument();
  // One call per error source: `??` would let a list error hide a 401 from create.
  useSigninOnUnauthorized(error);
  useSigninOnUnauthorized(createDocument.error);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<CreateDocumentForm>({
    resolver: zodResolver(createDocumentSchema),
    defaultValues: { file_name: '' },
  });

  // `mutate`, not `mutateAsync`: handleSubmit re-throws a rejected handler, which
  // would surface as an unhandled rejection. The error is rendered from
  // `createDocument.error` below instead.
  const onSubmit = handleSubmit((values) => {
    createDocument.mutate(values.file_name, { onSuccess: () => reset() });
  });

  const documents = data?.pages.flatMap((page) => page.data) ?? [];

  return (
    <section>
      <h2>Documents</h2>

      <form onSubmit={(event) => void onSubmit(event)}>
        <label htmlFor="file_name">File name</label>
        <input id="file_name" type="text" {...register('file_name')} />
        <button type="submit" disabled={createDocument.isPending}>
          {createDocument.isPending ? 'Creating…' : 'Create'}
        </button>
        {errors.file_name && <p role="alert">{errors.file_name.message}</p>}
        {createDocument.error && (
          <p role="alert">
            Could not create the document: {errorMessage(createDocument.error, 'unknown error')}
          </p>
        )}
      </form>

      {isPending && <p>Loading…</p>}

      {error && (
        <p role="alert">Could not load documents: {errorMessage(error, 'unknown error')}</p>
      )}

      {!isPending && !error && documents.length === 0 && <p>No documents yet.</p>}

      {documents.length > 0 && (
        <ul>
          {documents.map((document) => (
            <li key={document.document_id}>
              <strong>{document.file_name}</strong> — {document.status} (
              {new Date(document.created_at).toLocaleString()})
            </li>
          ))}
        </ul>
      )}

      {hasNextPage && (
        <button type="button" disabled={isFetchingNextPage} onClick={() => void fetchNextPage()}>
          {isFetchingNextPage ? 'Loading…' : 'Load more'}
        </button>
      )}
    </section>
  );
}

export default DocumentsPage;
