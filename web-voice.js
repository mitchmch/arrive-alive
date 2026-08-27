(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ArriveAliveVoice = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  function createVoiceController(options = {}) {
    const endpoint = options.endpoint || '/api/voice';
    const fetchFn = options.fetch || (typeof fetch === 'function' ? fetch.bind(globalThis) : null);
    const AudioCtor = options.Audio || (typeof Audio === 'function' ? Audio : null);
    const fallback = options.fallback || (() => {});
    let enabled = true;
    let requestController = null;
    let audio = null;
    let objectUrl = null;

    function releaseAudio() {
      if (audio) {
        try {
          audio.pause();
          audio.currentTime = 0;
        } catch (_) {}
      }
      audio = null;
      if (objectUrl && typeof URL !== 'undefined' && URL.revokeObjectURL) {
        URL.revokeObjectURL(objectUrl);
      }
      objectUrl = null;
    }

    function stop() {
      requestController?.abort();
      requestController = null;
      releaseAudio();
    }

    async function speak(text) {
      const message = String(text || '').trim().slice(0, 220);
      if (!enabled || !message) return {provider: 'disabled'};
      stop();
      if (!fetchFn || !AudioCtor || typeof Blob === 'undefined') {
        fallback(message);
        return {provider: 'native'};
      }
      requestController = typeof AbortController === 'function' ? new AbortController() : null;
      try {
        const response = await fetchFn(endpoint, {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({text: message}),
          signal: requestController?.signal,
        });
        if (!response.ok || !String(response.headers.get('content-type') || '').includes('audio/')) {
          throw new Error(`Cloud voice returned ${response.status}`);
        }
        const bytes = await response.arrayBuffer();
        if (!bytes.byteLength) throw new Error('Cloud voice returned no audio');
        const blob = new Blob([bytes], {type: 'audio/mpeg'});
        objectUrl = URL.createObjectURL(blob);
        audio = new AudioCtor(objectUrl);
        audio.preload = 'auto';
        await audio.play();
        requestController = null;
        return {provider: 'elevenlabs'};
      } catch (error) {
        if (error?.name === 'AbortError') return {provider: 'cancelled'};
        releaseAudio();
        fallback(message);
        return {provider: 'native', error: error?.message || 'Cloud voice unavailable'};
      }
    }

    function setEnabled(value) {
      enabled = Boolean(value);
      if (!enabled) stop();
    }

    return {speak, stop, setEnabled, isEnabled: () => enabled};
  }

  return {createVoiceController};
});
