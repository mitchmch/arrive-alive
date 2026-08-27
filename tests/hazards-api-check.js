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
  delete require.cache[require.resolve('../api/hazards')];
  const handler = require('../api/hazards');

  const unavailable = responseRecorder();
  await handler({method: 'GET', headers: {}}, unavailable);
  assert.equal(unavailable.statusCode, 503);
  assert.equal(unavailable.body.code, 'backend_not_configured');

  const blockedWrite = responseRecorder();
  await handler({method: 'POST', headers: {}}, blockedWrite);
  assert.equal(blockedWrite.statusCode, 405, 'The public proxy must remain read-only');

  process.env.SUPABASE_APP_API_URL = 'https://project.example/functions/v1/app-api/';
  const originalFetch = global.fetch;
  let captured;
  global.fetch = async (url, options) => {
    captured = {url, options};
    return new Response(JSON.stringify({hazards: []}), {
      status: 200,
      headers: {'Content-Type': 'application/json'},
    });
  };
  const proxied = responseRecorder();
  await handler({method: 'GET', headers: {'x-request-id': 'request-1'}}, proxied);
  assert.equal(proxied.statusCode, 200);
  assert.equal(captured.url, 'https://project.example/functions/v1/app-api/api/public-hazards');
  assert.equal(captured.options.method, 'GET');
  assert.equal(captured.options.headers.Authorization, undefined, 'Public reads must not require or forward a user credential');
  assert.equal(captured.options.headers['X-Request-Id'], 'request-1');
  global.fetch = originalFetch;

  console.log('Public hazard proxy checks passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
