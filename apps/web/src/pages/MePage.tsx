import { useMe } from '../hooks/use-me.ts';
import { useSigninOnUnauthorized } from '../hooks/use-signin-on-unauthorized.ts';
import { ApiError } from '../lib/api.ts';

function MePage() {
  const { data, isPending, error } = useMe();
  useSigninOnUnauthorized(error);

  if (isPending) {
    return <p>Loading…</p>;
  }

  if (error) {
    return (
      <p role="alert">
        Could not load your profile: {error instanceof ApiError ? error.message : 'unknown error'}
      </p>
    );
  }

  return (
    <section>
      <h2>Me</h2>
      <dl>
        <dt>user_id</dt>
        <dd>{data.user_id}</dd>
        <dt>username</dt>
        <dd>{data.username}</dd>
      </dl>
    </section>
  );
}

export default MePage;
