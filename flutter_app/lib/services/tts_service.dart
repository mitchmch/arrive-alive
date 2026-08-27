import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

typedef CloudVoiceRequest = Future<Uint8List> Function(
  String text,
  String language,
);
typedef AudioBytesPlayer = Future<void> Function(Uint8List bytes);
typedef NativeSpeech = Future<void> Function(String text, String language);
typedef StopSpeech = Future<void> Function();

/// Speaks guidance with the server-provided ElevenLabs African voice and falls
/// back to the device TTS engine whenever the request or MP3 playback fails.
///
/// No provider credential is stored in the app. [AppConfig.voiceApiUrl] is a
/// configurable server-side proxy endpoint.
class TtsService {
  static final TtsService _instance = TtsService._();

  factory TtsService() => _instance;

  TtsService._()
      : _requestCloudVoice = _defaultCloudVoiceRequest,
        _audioPlayer = AudioPlayer() {
    _playAudioBytes = _defaultPlayAudioBytes;
    _speakNatively = _defaultNativeSpeak;
    _stopSpeech = _defaultStop;
  }

  /// Test-only dependency seam. Production callers use the singleton factory.
  TtsService.forTesting({
    required CloudVoiceRequest requestCloudVoice,
    required AudioBytesPlayer playAudioBytes,
    required NativeSpeech speakNatively,
    StopSpeech? stopSpeech,
  })  : _requestCloudVoice = requestCloudVoice,
        _playAudioBytes = playAudioBytes,
        _speakNatively = speakNatively,
        _stopSpeech = stopSpeech ?? _noopStop,
        _audioPlayer = null;

  final CloudVoiceRequest _requestCloudVoice;
  final AudioPlayer? _audioPlayer;
  late final AudioBytesPlayer _playAudioBytes;
  late final NativeSpeech _speakNatively;
  late final StopSpeech _stopSpeech;

  FlutterTts? _tts;
  bool _initialized = false;
  bool _enabled = true;
  String _language = 'en-US';
  int _speechGeneration = 0;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (_audioPlayer == null) return;

    _tts = FlutterTts();
    try {
      await _tts!.setLanguage(_language);
      await _tts!.setSpeechRate(0.45);
      await _tts!.setVolume(1);
      await _tts!.setPitch(1);
      await _tts!.awaitSpeakCompletion(true);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (_) {
      // Individual engines are retried when speech is requested.
    }
  }

  /// Speaks one instruction. Cloud MP3 playback is preferred; native TTS is a
  /// reliable fallback for an unavailable endpoint, malformed response, or
  /// audio-player failure.
  Future<void> speak(String text) async {
    final normalized = text.trim();
    if (!_enabled || normalized.isEmpty) return;
    await init();
    final generation = ++_speechGeneration;
    await _stopCurrentPlayback();
    if (!_enabled || generation != _speechGeneration) return;

    try {
      final bytes = await _requestCloudVoice(normalized, _language);
      if (bytes.isEmpty) throw const FormatException('Empty voice response');
      if (!_enabled || generation != _speechGeneration) return;
      await _playAudioBytes(bytes);
      return;
    } catch (_) {
      if (!_enabled || generation != _speechGeneration) return;
      try {
        await _speakNatively(normalized, _language);
      } catch (_) {
        // Navigation remains usable visually if neither speech engine works.
      }
    }
  }

  Future<void> stop() async {
    _speechGeneration++;
    await _stopCurrentPlayback();
  }

  Future<void> _stopCurrentPlayback() async {
    try {
      await _stopSpeech();
    } catch (_) {}
  }

  set enabled(bool value) {
    _enabled = value;
    if (!value) stop();
  }

  bool get enabled => _enabled;

  Future<void> setLanguage(String language) async {
    _language = language;
    await init();
    try {
      await _tts?.setLanguage(language);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _audioPlayer?.dispose();
  }

  static Future<Uint8List> _defaultCloudVoiceRequest(
    String text,
    String language,
  ) async {
    final response = await http
        .post(
          Uri.parse(AppConfig.voiceApiUrl),
          headers: const {
            'Accept': 'audio/mpeg',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'text': text, 'language': language}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Voice endpoint returned ${response.statusCode}',
        response.request?.url,
      );
    }
    return response.bodyBytes;
  }

  Future<void> _defaultPlayAudioBytes(Uint8List bytes) async {
    await _audioPlayer!.play(BytesSource(bytes));
  }

  Future<void> _defaultNativeSpeak(String text, String language) async {
    _tts ??= FlutterTts();
    await _tts!.setLanguage(language);
    await _tts!.stop();
    await _tts!.speak(text);
  }

  Future<void> _defaultStop() async {
    await _audioPlayer?.stop();
    await _tts?.stop();
  }

  static Future<void> _noopStop() async {}
}
