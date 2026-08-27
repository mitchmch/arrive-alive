import 'dart:typed_data';

import 'package:arrive_alive/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud MP3 is preferred when request and playback succeed', () async {
    final played = <Uint8List>[];
    final native = <String>[];
    final service = TtsService.forTesting(
      requestCloudVoice: (text, language) async => Uint8List.fromList([1, 2]),
      playAudioBytes: (bytes) async => played.add(bytes),
      speakNatively: (text, language) async => native.add('$language:$text'),
    );

    await service.speak('Turn left');

    expect(played.single, [1, 2]);
    expect(native, isEmpty);
  });

  test('native TTS receives the selected locale when cloud request fails',
      () async {
    final native = <String>[];
    final service = TtsService.forTesting(
      requestCloudVoice: (text, language) async => throw Exception('offline'),
      playAudioBytes: (_) async {},
      speakNatively: (text, language) async => native.add('$language:$text'),
    );
    await service.setLanguage('fr-FR');

    await service.speak('Tournez à gauche');

    expect(native, ['fr-FR:Tournez à gauche']);
  });

  test('native TTS is used when returned MP3 cannot be played', () async {
    var nativeCalls = 0;
    final service = TtsService.forTesting(
      requestCloudVoice: (text, language) async => Uint8List.fromList([3]),
      playAudioBytes: (_) async => throw Exception('decoder error'),
      speakNatively: (text, language) async => nativeCalls++,
    );

    await service.speak('Continue straight');

    expect(nativeCalls, 1);
  });
}
