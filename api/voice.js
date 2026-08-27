const DEFAULT_VOICE_ID = '4bSnEy0K5TXdv7EEYf9t';
const MAX_TEXT_LENGTH = 220;
const WINDOW_MS = 60_000;
const MAX_REQUESTS_PER_WINDOW = 30;
const requestWindows = new Map();

function clientAddress(request) {
  return String(request.headers?.['x-forwarded-for'] || request.socket?.remoteAddress || 'unknown')
    .split(',')[0]
    .trim();
}

function isRateLimited(request, now = Date.now()) {
  const key = clientAddress(request);
  const current = requestWindows.get(key);
  if (!current || now - current.startedAt >= WINDOW_MS) {
    requestWindows.set(key, {startedAt: now, count: 1});
    return false;
  }
  current.count += 1;
  return current.count > MAX_REQUESTS_PER_WINDOW;
}

function json(response, status, body) {
  response.status(status).json(body);
}

module.exports = async (request, response) => {
  response.setHeader('Cache-Control', 'private, no-store');
  response.setHeader('Vary', 'Origin');
  response.setHeader('X-Content-Type-Options', 'nosniff');

  if (request.method === 'OPTIONS') {
    response.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    response.status(204).end();
    return;
  }
  if (request.method !== 'POST') {
    json(response, 405, {code: 'method_not_allowed', message: 'Use POST'});
    return;
  }
  if (isRateLimited(request)) {
    response.setHeader('Retry-After', '60');
    json(response, 429, {code: 'rate_limited', message: 'Voice guidance is temporarily rate limited'});
    return;
  }

  const apiKey = process.env.ELEVENLABS_API_KEY || '';
  if (!apiKey) {
    json(response, 503, {code: 'voice_not_configured', message: 'Cloud voice is unavailable'});
    return;
  }
  const text = String(request.body?.text || '').trim();
  if (!text || text.length > MAX_TEXT_LENGTH) {
    json(response, 400, {code: 'invalid_text', message: `text must contain 1-${MAX_TEXT_LENGTH} characters`});
    return;
  }

  try {
    const voiceId = process.env.ELEVENLABS_VOICE_ID || DEFAULT_VOICE_ID;
    const upstream = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}?output_format=mp3_22050_32`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'audio/mpeg',
          'xi-api-key': apiKey,
        },
        body: JSON.stringify({
          text,
          model_id: 'eleven_flash_v2_5',
          voice_settings: {stability: 0.58, similarity_boost: 0.76, style: 0.08, use_speaker_boost: true},
        }),
      },
    );
    if (!upstream.ok) {
      const detail = await upstream.text();
      console.error('ElevenLabs voice request failed', upstream.status, detail.slice(0, 240));
      json(response, 502, {code: 'voice_provider_error', message: 'Cloud voice is temporarily unavailable'});
      return;
    }
    const audio = Buffer.from(await upstream.arrayBuffer());
    if (!audio.length) {
      json(response, 502, {code: 'empty_voice_response', message: 'Cloud voice returned no audio'});
      return;
    }
    response.setHeader('Content-Type', 'audio/mpeg');
    response.setHeader('Content-Length', String(audio.length));
    response.setHeader('X-Voice-Provider', 'elevenlabs');
    response.status(200).send(audio);
  } catch (error) {
    console.error('Cloud voice request failed', error);
    json(response, 502, {code: 'voice_unavailable', message: 'Cloud voice is temporarily unavailable'});
  }
};

module.exports.DEFAULT_VOICE_ID = DEFAULT_VOICE_ID;
module.exports.isRateLimited = isRateLimited;
