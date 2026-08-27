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
  delete require.cache[require.resolve('../api/public-speed-limits')];
  const handler = require('../api/public-speed-limits');

  const unavailable = responseRecorder();
  await handler({method: 'GET', headers: {}}, unavailable);
  assert.equal(unavailable.statusCode, 503);
  assert.equal(unavailable.body.code, 'backend_not_configured');

  const blockedWrite = responseRecorder();
  await handler({method: 'POST', headers: {}}, blockedWrite);
  assert.equal(blockedWrite.statusCode, 405, 'The public speed-limit proxy must remain read-only');

  const options = responseRecorder();
  await handler({method: 'OPTIONS', headers: {}}, options);
  assert.equal(options.statusCode, 204);
  assert.equal(options.headers['Access-Control-Allow-Methods'], 'GET, OPTIONS');

  process.env.SUPABASE_APP_API_URL = 'https://project.example/functions/v1/app-api/';
  const originalFetch = global.fetch;
  let captured;
  global.fetch = async (url, requestOptions) => {
    captured = {url, options: requestOptions};
    return new Response(JSON.stringify({
      limits: [
        {mode: 'car', limitKph: 60},
        {mode: 'bus', limitKph: 50},
        {mode: 'lorry', limitKph: 50},
        {mode: 'motorbike', limitKph: 60},
      ],
    }), {status: 200, headers: {'Content-Type': 'application/json'}});
  };
  const proxied = responseRecorder();
  await handler({method: 'GET', headers: {'x-request-id': 'request-2'}}, proxied);
  assert.equal(proxied.statusCode, 200);
  assert.equal(captured.url, 'https://project.example/functions/v1/app-api/api/public-speed-limits');
  assert.equal(captured.options.method, 'GET');
  assert.equal(captured.options.headers.Authorization, undefined);
  assert.equal(captured.options.headers['X-Request-Id'], 'request-2');
  global.fetch = originalFetch;

  console.log('Public speed-limit proxy checks passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
