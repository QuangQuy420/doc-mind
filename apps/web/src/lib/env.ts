/**
 * The five `VITE_*` variables the SPA needs, validated once at module load.
 *
 * A static site has no server to fail at boot, so a missing or malformed value
 * would otherwise surface as a confusing 404 from Cognito or the API. Parsing
 * here turns that into one readable error in the console instead.
 */
import { z } from 'zod';

// Base URLs are concatenated with paths, so a trailing slash would produce `//`.
const baseUrl = z.url().transform((value) => value.replace(/\/+$/, ''));

const envSchema = z.object({
  // terraform output api_url
  VITE_API_BASE_URL: baseUrl,
  // terraform output cognito_issuer
  VITE_COGNITO_AUTHORITY: z.url(),
  // terraform output cognito_client_id
  VITE_COGNITO_CLIENT_ID: z.string().min(1),
  // terraform output cognito_hosted_ui_domain
  VITE_COGNITO_DOMAIN: baseUrl,
  // terraform output site_url + "/". The trailing slash is not cosmetic: the
  // redirect URI must match a Cognito callback URL byte for byte.
  VITE_REDIRECT_URI: z.url().endsWith('/', 'must end with "/" to match the Cognito callback URL'),
});

const parsed = envSchema.safeParse(import.meta.env);

if (!parsed.success) {
  const problems = parsed.error.issues
    .map((issue) => `  - ${issue.path.join('.')}: ${issue.message}`)
    .join('\n');
  throw new Error(`Invalid frontend environment (see apps/web/.env.example):\n${problems}`);
}

export const env = parsed.data;
