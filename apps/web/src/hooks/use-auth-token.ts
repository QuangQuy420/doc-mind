import { useAuth } from 'react-oidc-context';

/** The Cognito access token, or undefined while signed out. Sent as `Bearer`. */
export function useAuthToken(): string | undefined {
  const auth = useAuth();
  return auth.user?.access_token;
}

/**
 * The signed-in user's `sub`, for scoping query keys. Cached server data must
 * never survive an account switch, so every key carries the tenant.
 */
export function useUserId(): string | undefined {
  const auth = useAuth();
  return auth.user?.profile.sub;
}
