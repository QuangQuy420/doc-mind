import { useQuery } from '@tanstack/react-query';
import { ApiError, getMe } from '../lib/api.ts';
import { useAuthToken, useUserId } from './use-auth-token.ts';

/** The caller's profile from `GET /me`. Idle until there is a token. */
export function useMe() {
  const token = useAuthToken();
  const userId = useUserId();

  return useQuery({
    queryKey: ['me', userId],
    queryFn: async () => {
      if (!token) {
        throw new ApiError('UNAUTHORIZED', 'Not signed in.', 401);
      }
      return getMe(token);
    },
    enabled: Boolean(token),
  });
}
