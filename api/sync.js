'use strict';

const MAX_BODY_BYTES = 1_500_000;
const ALLOWED_METHODS = 'GET, POST, OPTIONS';

function send(response, status, body) {
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.status(status).json(body);
}

module.exports = async (request, response) => {
  response.setHeader('Allow', ALLOWED_METHODS);
  if (request.method === 'OPTIONS') {
    response.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, Idempotency-Key');
    response.setHeader('Access-Control-Allow-Methods', ALLOWED_METHODS);
    response.status(204).end();
    return;
  }
  if (!['GET', 'POST'].includes(request.method)) {
    send(response, 405, {error: 'Method not allowed'});
    return;
  }

  const upstreamBase = (process.env.SUPABASE_APP_API_URL || '').replace(/\/+$/, '');
  if (!upstreamBase) {
    send(response, 503, {
      error: 'Durable synchronization is not configured',
      code: 'backend_not_configured',
      persistence: {durable: false, adapter: 'none'},
    });
    return;
  }

  let serializedBody;
  if (request.method === 'POST') {
    try {
      serializedBody = typeof request.body === 'string' ? request.body : JSON.stringify(request.body || {});
    } catch (_) {
      send(response, 400, {error: 'Request body must be valid JSON'});
      return;
    }
    if (Buffer.byteLength(serializedBody) > MAX_BODY_BYTES) {
      send(response, 413, {error: 'Sync payload exceeds 1.5 MB'});
      return;
    }
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12_000);
  try {
    const query = request.url && request.url.includes('?') ? request.url.slice(request.url.indexOf('?')) : '';
    const upstream = await fetch(`${upstreamBase}/api/sync${query}`, {
      method: request.method,
      headers: {
        'Accept': 'application/json',
        ...(serializedBody ? {'Content-Type': 'application/json'} : {}),
        ...(request.headers.authorization ? {'Authorization': request.headers.authorization} : {}),
        ...(request.headers['idempotency-key'] ? {'Idempotency-Key': request.headers['idempotency-key']} : {}),
        ...(request.headers['x-request-id'] ? {'X-Request-Id': request.headers['x-request-id']} : {}),
      },
      body: serializedBody,
      signal: controller.signal,
    });
    const text = await upstream.text();
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('Content-Type', upstream.headers.get('content-type') || 'application/json; charset=utf-8');
    response.status(upstream.status).send(text);
  } catch (error) {
    send(response, 502, {error: error.name === 'AbortError' ? 'Durable sync timed out' : 'Durable sync is unavailable', code: 'upstream_unavailable'});
  } finally {
    clearTimeout(timeout);
  }
};
