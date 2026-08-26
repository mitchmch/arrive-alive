const assert = require('node:assert/strict');

function responseRecorder() {
  return {
    statusCode: 200, headers: {}, body: null,
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
    send(body) { this.body = body; return this; },
    end() { return this; },
  };
}

(async () => {
  delete process.env.SUPABASE_APP_API_URL;
  delete require.cache[require.resolve('../api/sync')];
  const handler = require('../api/sync');
  const unavailable = responseRecorder();
  await handler({method: 'GET', headers: {}, url: '/api/sync'}, unavailable);
  assert.equal(unavailable.statusCode, 503);
  assert.equal(unavailable.body.code, 'backend_not_configured');
  assert.equal(unavailable.body.persistence.durable, false);

  process.env.SUPABASE_APP_API_URL = 'https://project.example/functions/v1/app-api/';
  const originalFetch = global.fetch;
  let captured;
  global.fetch = async (url, options) => {
    captured = {url, options};
    return new Response(JSON.stringify({persistence: {durable: true}}), {status: 200, headers: {'Content-Type': 'application/json'}});
  };
  const proxied = responseRecorder();
  await handler({method: 'POST', headers: {authorization: 'Bearer opaque-token-value-that-is-long-enough', 'idempotency-key': 'op-1'}, url: '/api/sync', body: {operation: 'merge', snapshot: {collections: {}}}}, proxied);
  assert.equal(proxied.statusCode, 200);
  assert.equal(captured.url, 'https://project.example/functions/v1/app-api/api/sync');
  assert.equal(captured.options.headers.Authorization, 'Bearer opaque-token-value-that-is-long-enough');
  assert.equal(captured.options.headers['Idempotency-Key'], 'op-1');
  assert.match(captured.options.body, /"operation":"merge"/);
  global.fetch = originalFetch;

  console.log('Durable sync proxy checks passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
