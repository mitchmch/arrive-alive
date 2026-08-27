const assert = require('node:assert/strict');
const {createVoiceController} = require('../web-voice');

class FakeAudio {
  constructor(url) { this.url = url; this.currentTime = 0; }
  async play() { this.played = true; }
  pause() { this.paused = true; }
}

(async () => {
  const originalUrl = global.URL;
  global.URL = {
    createObjectURL: () => 'blob:voice',
    revokeObjectURL: () => {},
  };
  const fallbacks = [];
  const cloud = createVoiceController({
    Audio: FakeAudio,
    fallback: text => fallbacks.push(text),
    fetch: async () => new Response(new Uint8Array([1, 2, 3]), {
      status: 200,
      headers: {'Content-Type': 'audio/mpeg'},
    }),
  });
  assert.equal((await cloud.speak('Turn left ahead')).provider, 'elevenlabs');
  assert.deepEqual(fallbacks, []);

  const offline = createVoiceController({
    Audio: FakeAudio,
    fallback: text => fallbacks.push(text),
    fetch: async () => new Response('unavailable', {status: 503}),
  });
  assert.equal((await offline.speak('Hazard ahead')).provider, 'native');
  assert.deepEqual(fallbacks, ['Hazard ahead']);
  offline.setEnabled(false);
  assert.equal((await offline.speak('Do not speak')).provider, 'disabled');
  global.URL = originalUrl;

  console.log('Voice controller checks passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
