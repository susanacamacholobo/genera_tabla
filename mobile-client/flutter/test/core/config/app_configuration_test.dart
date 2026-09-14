import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';
import 'package:software1_mobile/core/errors/app_exception.dart';

void main() {
  group('AppConfiguration', () {
    test('normalizes the base URL and resolves API endpoints', () {
      final configuration = AppConfiguration.fromValue(
        ' https://server.example/api ',
      );

      expect(
        configuration.apiBaseUri.toString(),
        'https://server.example/api/',
      );
      expect(
        configuration
            .endpoint('/clientes', queryParameters: {'page': '2'})
            .toString(),
        'https://server.example/api/clientes?page=2',
      );
    });

    test('uses the Android emulator host as the default', () {
      expect(
        AppConfiguration.fromEnvironment().apiBaseUri.toString(),
        '${AppConfiguration.defaultApiBaseUrl}/',
      );
    });

    for (final value in <String>[
      '',
      'localhost:8080',
      'ftp://localhost/modelo',
      'http://user:secret@localhost:8080',
      'http://localhost:8080?token=secret',
      'http://localhost:8080/#fragment',
    ]) {
      test('rejects an unsafe or malformed API_BASE_URL: $value', () {
        expect(
          () => AppConfiguration.fromValue(value),
          throwsA(isA<ConfigurationException>()),
        );
      });
    }
  });
}
