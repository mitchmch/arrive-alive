import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech service for voice-guided turn-by-turn navigation.
/// Uses the device's native TTS engine.
class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  FlutterTts? _tts;
  bool _initialized = false;
  bool _enabled = true;
  String _language = 'en-US';

  /// Initialize the TTS engine. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _tts = FlutterTts();

    try {
      await _tts!.setLanguage(_language);
      await _tts!.setSpeechRate(
        0.45,
      ); // Slightly slower for clarity while driving
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
      await _tts!.awaitSpeakCompletion(true);
    } catch (_) {
      // TTS not available on this platform — navigation still works silently
    }
  }

  /// Speak a navigation instruction. Only speaks if enabled.
  Future<void> speak(String text) async {
    if (!_enabled) return;
    await init();
    if (_tts == null) return;

    try {
      await _tts!.stop();
      await _tts!.speak(text);
    } catch (_) {}
  }

  /// Stop any current speech
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  /// Enable or disable voice guidance
  set enabled(bool value) {
    _enabled = value;
    if (!_enabled) {
      stop();
    }
  }

  bool get enabled => _enabled;

  /// Set the TTS language (e.g. 'en-US', 'fr-FR')
  Future<void> setLanguage(String lang) async {
    _language = lang;
    await init();
    try {
      await _tts?.setLanguage(lang);
    } catch (_) {}
  }

  /// Dispose the TTS engine
  void dispose() {
    _tts?.stop();
  }
}
