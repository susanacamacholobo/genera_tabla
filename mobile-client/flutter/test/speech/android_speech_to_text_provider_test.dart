import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/speech/android_speech_to_text_provider.dart';
import 'package:software1_mobile/core/errors/app_exception.dart';
import 'package:software1_mobile/speech/speech_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AndroidSpeechToTextProvider.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('queries native on-device availability', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isAvailable');
      return true;
    });
    final provider = AndroidSpeechToTextProvider(channel: channel);

    expect(await provider.isAvailable(), isTrue);
  });

  test('returns a typed local transcript and forwards the locale', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'listen');
      expect(call.arguments, {'locale': 'es-ES'});
      return {
        'transcript': '  crea un cliente  ',
        'locale': 'es-ES',
        'confidence': 0.87,
      };
    });
    final provider = AndroidSpeechToTextProvider(channel: channel);

    final result = await provider.listen();

    expect(result.transcript, 'crea un cliente');
    expect(result.locale, 'es-ES');
    expect(result.confidence, 0.87);
    expect(provider.isListening, isFalse);
  });

  test('prevents overlapping recognition sessions', () async {
    final pending = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    final provider = AndroidSpeechToTextProvider(channel: channel);

    final first = provider.listen();
    await Future<void>.delayed(Duration.zero);
    expect(provider.isListening, isTrue);
    await expectLater(
      provider.listen(),
      throwsA(isA<SpeechRecognitionException>()),
    );
    pending.complete({'transcript': 'lista clientes', 'locale': 'es-ES'});
    await first;
  });

  test('maps native availability and permission failures safely', () async {
    final errors = {
      'OFFLINE_UNAVAILABLE': SpeechUnavailableException,
      'LANGUAGE_UNAVAILABLE': SpeechUnavailableException,
      'PERMISSION_DENIED': SpeechPermissionException,
    };
    for (final entry in errors.entries) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) => throw PlatformException(
          code: entry.key,
          message: 'private native details',
        ),
      );
      final provider = AndroidSpeechToTextProvider(channel: channel);

      await expectLater(
        provider.listen(),
        throwsA(
          isA<AppException>()
              .having(
                (error) => error.runtimeType,
                'exception type',
                entry.value,
              )
              .having(
                (error) => error.userMessage,
                'safe message',
                isNot(contains('private native details')),
              ),
        ),
      );
    }
  });

  test('rejects malformed native results', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'transcript': '', 'locale': 'es-ES'},
    );
    final provider = AndroidSpeechToTextProvider(channel: channel);

    await expectLater(
      provider.listen(),
      throwsA(isA<SpeechRecognitionException>()),
    );
  });

  test('forwards control operations and disposes idempotently', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    final provider = AndroidSpeechToTextProvider(channel: channel);

    await provider.stop();
    await provider.cancel();
    await provider.dispose();
    await provider.dispose();

    expect(calls, ['stop', 'cancel', 'dispose']);
    await expectLater(
      provider.listen(),
      throwsA(isA<SpeechRecognitionException>()),
    );
  });
}
