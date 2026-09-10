import { useAuth } from 'react-oidc-context';
import { env } from '../lib/env.ts';

function HomePage() {
  const auth = useAuth();

  const logOut = async () => {
    // Clear the local session first, then end the Hosted UI session. Cognito
    // has no OIDC end_session_endpoint, so this is a plain redirect.
    await auth.removeUser();
    const params = new URLSearchParams({
      client_id: env.VITE_COGNITO_CLIENT_ID,
      // The validated redirect URI is by definition a registered Cognito URL;
      // `window.location.origin` would be wrong on any other origin or port.
      logout_uri: env.VITE_REDIRECT_URI,
    });
    window.location.href = `${env.VITE_COGNITO_DOMAIN}/logout?${params.toString()}`;
  };

  if (auth.isLoading) {
    return <p>Loading…</p>;
  }

  if (auth.error) {
    return <p role="alert">Sign-in failed: {auth.error.message}</p>;
  }

  if (!auth.isAuthenticated) {
    return (
      <section>
        <p>Sign in with Cognito to see your documents.</p>
        <button type="button" onClick={() => void auth.signinRedirect()}>
          Log in
        </button>
      </section>
    );
  }

  return (
    <section>
      <p>Signed in as {auth.user?.profile.email ?? auth.user?.profile.sub}</p>
      <button type="button" onClick={() => void logOut()}>
        Log out
      </button>
    </section>
  );
}

export default HomePage;
