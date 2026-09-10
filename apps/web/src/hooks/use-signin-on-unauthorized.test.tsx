import { cleanup, renderHook } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../lib/api.ts';
import { useSigninOnUnauthorized } from './use-signin-on-unauthorized.ts';

const signinRedirect = vi.fn().mockResolvedValue(undefined);

vi.mock('react-oidc-context', () => ({
  useAuth: () => ({ signinRedirect }),
}));

// Testing Library only auto-unmounts between tests when `afterEach` is a global;
// vitest globals are off here, so do it explicitly.
afterEach(cleanup);

beforeEach(() => {
  signinRedirect.mockClear();
});

describe('useSigninOnUnauthorized', () => {
  it('redirects to the Hosted UI on an UNAUTHORIZED ApiError', () => {
    renderHook(() => useSigninOnUnauthorized(new ApiError('UNAUTHORIZED', 'expired', 401)));

    expect(signinRedirect).toHaveBeenCalledTimes(1);
  });

  it('ignores other errors and a 401-looking message without the code', () => {
    const { rerender } = renderHook(({ error }) => useSigninOnUnauthorized(error), {
      initialProps: { error: undefined as unknown },
    });

    rerender({ error: new ApiError('NOT_FOUND', 'Unauthorized', 401) });
    rerender({ error: new Error('401 Unauthorized') });

    expect(signinRedirect).not.toHaveBeenCalled();
  });
});
