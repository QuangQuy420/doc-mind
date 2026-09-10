import { useMutation, useQueryClient } from '@tanstack/react-query';
import { ApiError, createDocument } from '../lib/api.ts';
import { useAuthToken, useUserId } from './use-auth-token.ts';

/** `POST /documents`. On success the list is refetched from the server. */
export function useCreateDocument() {
  const token = useAuthToken();
  const userId = useUserId();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (fileName: string) => {
      if (!token) {
        throw new ApiError('UNAUTHORIZED', 'Not signed in.', 401);
      }
      return createDocument(token, { file_name: fileName });
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['documents', userId] }),
  });
}
