import { useEffect } from 'react';
import { useAuth } from 'react-oidc-context';
import { isUnauthorized } from '../lib/api.ts';

/**
 * Send the user back to the Hosted UI when the API rejects the token.
 * The decision is made on `error.code === 'UNAUTHORIZED'`, never on the status
 * text: the code is part of the API contract, the wording is not.
 */
export function useSigninOnUnauthorized(error: unknown): void {
  const auth = useAuth();
  const { signinRedirect } = auth;

  useEffect(() => {
    if (isUnauthorized(error)) {
      void signinRedirect();
    }
  }, [error, signinRedirect]);
}
