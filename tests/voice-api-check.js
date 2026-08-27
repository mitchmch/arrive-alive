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
  const handler = require('../api/voice');
  delete process.env.ELEVENLABS_API_KEY;
  const unavailable = responseRecorder();
  await handler({method: 'POST', headers: {}, body: {text: 'Turn left'}}, unavailable);
  assert.equal(unavailable.statusCode, 503);
  assert.equal(unavailable.body.code, 'voice_not_configured');

  const method = responseRecorder();
  await handler({method: 'GET', headers: {}}, method);
  assert.equal(method.statusCode, 405);

  process.env.ELEVENLABS_API_KEY = 'test-key';
  const invalid = responseRecorder();
  await handler({method: 'POST', headers: {}, body: {text: ''}}, invalid);
  assert.equal(invalid.statusCode, 400);

  const originalFetch = global.fetch;
  let captured;
  global.fetch = async (url, options) => {
    captured = {url, options};
    return new Response(new Uint8Array([73, 68, 51]), {
      status: 200,
      headers: {'Content-Type': 'audio/mpeg'},
    });
  };
  const audio = responseRecorder();
  await handler({method: 'POST', headers: {'x-forwarded-for': '203.0.113.10'}, body: {text: 'Turn left ahead'}}, audio);
  assert.equal(audio.statusCode, 200);
  assert.equal(audio.headers['Content-Type'], 'audio/mpeg');
  assert.equal(audio.headers['X-Voice-Provider'], 'elevenlabs');
  assert.match(captured.url, /text-to-speech\/4bSnEy0K5TXdv7EEYf9t/);
  assert.equal(captured.options.headers['xi-api-key'], 'test-key');
  assert.equal(JSON.parse(captured.options.body).model_id, 'eleven_flash_v2_5');
  global.fetch = originalFetch;
  delete process.env.ELEVENLABS_API_KEY;

  console.log('Voice API checks passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
