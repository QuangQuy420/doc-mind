import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import HomePage from './HomePage.tsx';

vi.mock('../lib/env.ts', () => ({
  env: { VITE_COGNITO_CLIENT_ID: 'client-id', VITE_COGNITO_DOMAIN: 'https://auth.test' },
}));

const auth = {
  isLoading: false,
  isAuthenticated: false,
  error: undefined as Error | undefined,
  user: undefined,
  signinRedirect: vi.fn().mockResolvedValue(undefined),
  removeUser: vi.fn().mockResolvedValue(undefined),
};

vi.mock('react-oidc-context', () => ({
  useAuth: () => auth,
}));

// Testing Library only auto-unmounts between tests when `afterEach` is a global;
// vitest globals are off here, so do it explicitly.
afterEach(cleanup);

beforeEach(() => {
  auth.signinRedirect.mockClear();
});

describe('HomePage', () => {
  it('shows a Log in button when signed out and starts the Hosted UI redirect', () => {
    render(<HomePage />);

    const button = screen.getByRole('button', { name: 'Log in' });
    expect(screen.queryByRole('button', { name: 'Log out' })).toBeNull();

    fireEvent.click(button);

    expect(auth.signinRedirect).toHaveBeenCalledTimes(1);
  });
});
