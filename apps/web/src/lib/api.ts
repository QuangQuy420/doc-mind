/**
 * The only place that talks HTTP to the DocMind API.
 *
 * Every endpoint answers with the same envelope — `{ data }`, `{ data, meta }`
 * or `{ error: { code, message, details } }` — so there is one unwrapper here
 * and callers get plain values or an `ApiError`. The UI branches on
 * `error.code`, never on an HTTP status or a message string.
 */
import type { components, operations } from './api.types';
import { env } from './env.ts';

export type Document = components['schemas']['Document'];
export type MeOut = components['schemas']['MeOut'];
export type PageMeta = components['schemas']['PageMeta'];
export type CreateDocumentRequest = components['schemas']['CreateDocumentRequest'];
export type ListDocumentsQuery = NonNullable<
  operations['list_documents_documents_get']['parameters']['query']
>;

export class ApiError extends Error {
  readonly code: string;
  readonly details: unknown;
  /** HTTP status, or 0 when the request never got a response (network/CORS). */
  readonly status: number;

  constructor(code: string, message: string, status: number, details?: unknown) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

/** True for the one error the UI must act on: send the user back to the Hosted UI. */
export function isUnauthorized(error: unknown): boolean {
  return error instanceof ApiError && error.code === 'UNAUTHORIZED';
}

/**
 * react-query retry policy. A 4xx from our own API (UNAUTHORIZED, NOT_FOUND,
 * VALIDATION_ERROR) never gets better on retry; the default of 3 would hold the
 * login redirect for ~7 s. Only transient failures (network, 5xx) are retried,
 * at most twice. `failureCount` is the number of attempts that already failed.
 */
export function retryQuery(failureCount: number, error: unknown): boolean {
  const clientError = error instanceof ApiError && error.status >= 400 && error.status < 500;
  return !clientError && failureCount < 2;
}

interface ErrorEnvelope {
  error: { code: string; message: string; details?: unknown };
}

interface DataEnvelope<T> {
  data: T;
  meta?: PageMeta;
}

export interface ApiResult<T> {
  data: T;
  meta?: PageMeta;
}

interface RequestOptions {
  token?: string;
  method?: 'GET' | 'POST';
  body?: unknown;
  query?: Record<string, string | number | undefined>;
}

/**
 * Codes for responses that never reached our handlers (a proxy, CloudFront or
 * the load balancer answering with plain text/HTML). Anything else, including
 * every non-JSON 5xx, becomes INTERNAL_ERROR so the UI still sees a known code.
 */
function statusToCode(status: number): string {
  if (status === 401) return 'UNAUTHORIZED';
  if (status === 403) return 'FORBIDDEN';
  if (status === 404) return 'NOT_FOUND';
  return 'INTERNAL_ERROR';
}

function isErrorEnvelope(payload: unknown): payload is ErrorEnvelope {
  return (
    typeof payload === 'object' &&
    payload !== null &&
    'error' in payload &&
    typeof (payload as ErrorEnvelope).error?.code === 'string'
  );
}

function isDataEnvelope<T>(payload: unknown): payload is DataEnvelope<T> {
  return typeof payload === 'object' && payload !== null && 'data' in payload;
}

function buildUrl(path: string, query?: RequestOptions['query']): string {
  const url = new URL(`${env.VITE_API_BASE_URL}${path}`);
  for (const [key, value] of Object.entries(query ?? {})) {
    if (value !== undefined) {
      url.searchParams.set(key, String(value));
    }
  }
  return url.toString();
}

export async function apiFetch<T>(
  path: string,
  options: RequestOptions = {},
): Promise<ApiResult<T>> {
  const { token, method = 'GET', body, query } = options;

  const headers: Record<string, string> = { Accept: 'application/json' };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
  }

  let response: Response;
  try {
    response = await fetch(buildUrl(path, query), {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    // DNS failure, offline, or a CORS rejection: there is no status to read.
    throw new ApiError('NETWORK_ERROR', 'Could not reach the API.', 0);
  }

  const payload: unknown = await response.json().catch(() => undefined);

  if (isErrorEnvelope(payload)) {
    throw new ApiError(
      payload.error.code,
      payload.error.message,
      response.status,
      payload.error.details,
    );
  }
  if (!response.ok) {
    throw new ApiError(
      statusToCode(response.status),
      `Request failed with status ${response.status}.`,
      response.status,
    );
  }
  if (!isDataEnvelope<T>(payload)) {
    throw new ApiError('INVALID_RESPONSE', 'The API returned an unexpected body.', response.status);
  }

  return { data: payload.data, meta: payload.meta };
}

export async function getMe(token: string): Promise<MeOut> {
  const { data } = await apiFetch<MeOut>('/me', { token });
  return data;
}

export interface DocumentPage {
  data: Document[];
  meta: PageMeta;
}

export async function listDocuments(
  token: string,
  query: ListDocumentsQuery = {},
): Promise<DocumentPage> {
  const { data, meta } = await apiFetch<Document[]>('/documents', {
    token,
    query: { limit: query.limit, cursor: query.cursor ?? undefined, page: query.page },
  });
  if (!meta) {
    throw new ApiError('INVALID_RESPONSE', 'The documents list came back without meta.', 200);
  }
  return { data, meta };
}

export async function createDocument(
  token: string,
  body: CreateDocumentRequest,
): Promise<Document> {
  const { data } = await apiFetch<Document>('/documents', { token, method: 'POST', body });
  return data;
}
