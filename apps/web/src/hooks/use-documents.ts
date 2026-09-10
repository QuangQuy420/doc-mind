import { useInfiniteQuery } from '@tanstack/react-query';
import { ApiError, listDocuments } from '../lib/api.ts';
import { useAuthToken, useUserId } from './use-auth-token.ts';

const PAGE_SIZE = 20;

/**
 * `GET /documents` page by page. The API hands back an opaque `next_cursor`;
 * we pass it back untouched and stop when it is null.
 */
export function useDocuments() {
  const token = useAuthToken();
  const userId = useUserId();

  return useInfiniteQuery({
    queryKey: ['documents', userId],
    // react-query v5 requires an explicit first page param; undefined = no cursor.
    initialPageParam: undefined as string | undefined,
    queryFn: async ({ pageParam }) => {
      if (!token) {
        throw new ApiError('UNAUTHORIZED', 'Not signed in.', 401);
      }
      return listDocuments(token, { limit: PAGE_SIZE, cursor: pageParam });
    },
    getNextPageParam: (lastPage) => lastPage.meta.next_cursor ?? undefined,
    enabled: Boolean(token),
  });
}
