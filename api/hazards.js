'use strict';

const ALLOWED_METHODS = 'GET, OPTIONS';

function send(response, status, body) {
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.status(status).json(body);
}

module.exports = async (request, response) => {
  response.setHeader('Allow', ALLOWED_METHODS);
  if (request.method === 'OPTIONS') {
    response.setHeader('Access-Control-Allow-Methods', ALLOWED_METHODS);
    response.status(204).end();
    return;
  }
  if (request.method !== 'GET') {
    send(response, 405, {error: 'Method not allowed'});
    return;
  }

  const upstreamBase = (process.env.SUPABASE_APP_API_URL || '').replace(/\/+$/, '');
  if (!upstreamBase) {
    send(response, 503, {error: 'Public hazards are not configured', code: 'backend_not_configured'});
    return;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8_000);
  try {
    const upstream = await fetch(`${upstreamBase}/api/public-hazards`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        ...(request.headers['x-request-id'] ? {'X-Request-Id': request.headers['x-request-id']} : {}),
      },
      signal: controller.signal,
    });
    const text = await upstream.text();
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('Content-Type', upstream.headers.get('content-type') || 'application/json; charset=utf-8');
    response.status(upstream.status).send(text);
  } catch (error) {
    send(response, 502, {
      error: error.name === 'AbortError' ? 'Public hazard lookup timed out' : 'Public hazards are unavailable',
      code: 'upstream_unavailable',
    });
  } finally {
    clearTimeout(timeout);
  }
};
