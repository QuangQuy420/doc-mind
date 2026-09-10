import type { ReactNode } from 'react';
import { useAuth } from 'react-oidc-context';
import { Navigate } from 'react-router-dom';

/**
 * Gate for routes that need a token. CloudFront serves index.html for any deep
 * link, so this runs before the page's queries and keeps them from firing
 * without a token.
 */
function RequireAuth({ children }: { children: ReactNode }) {
  const auth = useAuth();

  if (auth.isLoading) {
    return <p>Loading…</p>;
  }
  if (!auth.isAuthenticated) {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}

export default RequireAuth;
