import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WebStorageStateStore } from 'oidc-client-ts';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { AuthProvider, type AuthProviderProps } from 'react-oidc-context';
import { BrowserRouter } from 'react-router-dom';
import App from './App.tsx';
import './index.css';
import { retryQuery } from './lib/api.ts';
import { env } from './lib/env.ts';

const oidcConfig: AuthProviderProps = {
  authority: env.VITE_COGNITO_AUTHORITY,
  client_id: env.VITE_COGNITO_CLIENT_ID,
  // Must equal a Cognito callback URL byte for byte, trailing slash included.
  redirect_uri: env.VITE_REDIRECT_URI,
  // Authorization code + PKCE: a browser app is a public client and keeps no secret.
  response_type: 'code',
  scope: 'openid email profile',
  // Renews with the refresh token; Cognito has no `prompt=none` iframe renew.
  automaticSilentRenew: true,
  // sessionStorage survives reloads and deep links but dies with the tab.
  // The oidc-client-ts default is in-memory, which logs the user out on F5.
  userStore: new WebStorageStateStore({ store: window.sessionStorage }),
  // The PKCE verifier + `state` live in a *separate* store that defaults to
  // localStorage; keep the whole flow tab-scoped, not just the tokens.
  stateStore: new WebStorageStateStore({ store: window.sessionStorage }),
  // Drop ?code=&state= from the address bar once the callback is exchanged.
  onSigninCallback: () => {
    window.history.replaceState({}, document.title, window.location.pathname);
  },
};

const queryClient = new QueryClient({
  // See retryQuery: no retries on 4xx, so an UNAUTHORIZED redirects at once.
  defaultOptions: { queries: { retry: retryQuery } },
});

const rootElement = document.getElementById('root');
if (!rootElement) {
  throw new Error('Root element #root not found');
}

createRoot(rootElement).render(
  <StrictMode>
    <AuthProvider {...oidcConfig}>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </QueryClientProvider>
    </AuthProvider>
  </StrictMode>,
);
