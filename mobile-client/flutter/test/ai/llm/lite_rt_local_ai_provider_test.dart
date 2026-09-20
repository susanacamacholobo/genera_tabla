import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/ai/llm/lite_rt_local_ai_provider.dart';
import 'package:software1_mobile/ai/llm/local_ai_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(LiteRtLocalAIProvider.channelName);
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('decodes the installed model status', () async {
    _handle(
      channel,
      calls,
      (call) async => <String, Object?>{
        'installed': true,
        'loaded': false,
        'fileName': 'assistant.litertlm',
        'sizeBytes': 1234,
      },
    );
    final provider = LiteRtLocalAIProvider(channel: channel);

    final status = await provider.getModelStatus();

    expect(status.installed, isTrue);
    expect(status.loaded, isFalse);
    expect(status.fileName, 'assistant.litertlm');
    expect(status.sizeBytes, 1234);
    expect(calls.single.method, 'status');
  });

  test('imports, loads and generates one canonical JSON object', () async {
    _handle(channel, calls, (call) async {
      switch (call.method) {
        case 'importModel':
          return <String, Object?>{
            'installed': true,
            'loaded': false,
            'fileName': 'assistant.litertlm',
            'sizeBytes': 2048,
          };
        case 'loadModel':
          return null;
        case 'generate':
          expect(call.arguments, {
            'instruction': 'lista clientes',
            'domainContext': 'Cliente(id, nombre)',
          });
          return '{ "operation": "LIST_ENTITIES", "entity": "Cliente", '
              '"parameters": {} }';
      }
      fail('Unexpected call: ${call.method}');
    });
    final provider = LiteRtLocalAIProvider(channel: channel);

    final imported = await provider.importModel();
    await provider.loadModel();
    final output = await provider.generateStructuredIntent(
      instruction: '  lista clientes  ',
      domainContext: '  Cliente(id, nombre)  ',
    );

    expect(imported.installed, isTrue);
    expect(provider.isModelLoaded, isTrue);
    expect(jsonDecode(output), {
      'operation': 'LIST_ENTITIES',
      'entity': 'Cliente',
      'parameters': <String, Object?>{},
    });
    expect(calls.map((call) => call.method), [
      'importModel',
      'loadModel',
      'generate',
    ]);
  });

  test('rejects model output that is not a JSON object', () async {
    _handle(channel, calls, (call) async {
      if (call.method == 'loadModel') return null;
      if (call.method == 'generate') return '[1, 2, 3]';
      fail('Unexpected call: ${call.method}');
    });
    final provider = LiteRtLocalAIProvider(channel: channel);
    await provider.loadModel();

    await expectLater(
      provider.generateStructuredIntent(
        instruction: 'lista clientes',
        domainContext: 'Cliente',
      ),
      throwsA(
        isA<LocalAIException>().having(
          (error) => error.userMessage,
          'message',
          contains('objeto JSON'),
        ),
      ),
    );
  });

  test('extracts one JSON object from decorated model output', () async {
    _handle(channel, calls, (call) async {
      if (call.method == 'status') {
        return <String, Object?>{
          'installed': true,
          'loaded': true,
          'fileName': 'assistant.litertlm',
          'sizeBytes': 100,
        };
      }
      if (call.method == 'generate') {
        return 'Resultado:\n```json\n'
            '{"operation":"LIST_ENTITIES","entity":"Cliente",'
            '"parameters":{}}\n```';
      }
      return null;
    });
    final provider = LiteRtLocalAIProvider(channel: channel);
    await provider.getModelStatus();

    final response = await provider.generateStructuredIntent(
      instruction: 'lista los clientes',
      domainContext: 'Cliente',
    );

    expect(jsonDecode(response), {
      'operation': 'LIST_ENTITIES',
      'entity': 'Cliente',
      'parameters': <String, Object?>{},
    });
  });

  test('prevents overlapping generations', () async {
    final pending = Completer<String>();
    _handle(channel, calls, (call) async {
      if (call.method == 'loadModel') return null;
      if (call.method == 'generate') return pending.future;
      fail('Unexpected call: ${call.method}');
    });
    final provider = LiteRtLocalAIProvider(channel: channel);
    await provider.loadModel();

    final first = provider.generateStructuredIntent(
      instruction: 'primera',
      domainContext: 'Cliente',
    );
    await expectLater(
      provider.generateStructuredIntent(
        instruction: 'segunda',
        domainContext: 'Cliente',
      ),
      throwsA(isA<LocalAIException>()),
    );
    pending.complete(
      '{"operation":"LIST_ENTITIES","entity":"Cliente",'
      '"parameters":{}}',
    );
    await first;

    expect(calls.where((call) => call.method == 'generate'), hasLength(1));
  });

  test('maps native failures without exposing their details', () async {
    _handle(channel, calls, (call) async {
      throw PlatformException(
        code: 'MODEL_LOAD_FAILED',
        message: 'secret/native/path/model.litertlm',
      );
    });
    final provider = LiteRtLocalAIProvider(channel: channel);

    await expectLater(
      provider.loadModel(),
      throwsA(
        isA<LocalModelException>()
            .having(
              (error) => error.userMessage,
              'message',
              contains('No se pudo cargar'),
            )
            .having(
              (error) => error.userMessage,
              'safe message',
              isNot(contains('secret')),
            ),
      ),
    );
  });

  test('dispose is idempotent and prevents further use', () async {
    _handle(channel, calls, (call) async => null);
    final provider = LiteRtLocalAIProvider(channel: channel);

    await provider.dispose();
    await provider.dispose();

    expect(calls.where((call) => call.method == 'dispose'), hasLength(1));
    await expectLater(
      provider.getModelStatus(),
      throwsA(isA<LocalAIException>()),
    );
  });
}

void _handle(
  MethodChannel channel,
  List<MethodCall> calls,
  Future<Object?> Function(MethodCall call) handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });
}
