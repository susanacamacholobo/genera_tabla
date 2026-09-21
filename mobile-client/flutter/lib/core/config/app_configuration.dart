import '../errors/app_exception.dart';

class AppConfiguration {
  AppConfiguration._(this.apiBaseUri);

  static const defaultApiBaseUrl = 'http://10.0.2.2:8080';
  static const domainModelAsset =
      String.fromEnvironment('DEMO_DOMAIN') == 'biblioteca'
      ? 'assets/domain-model-biblioteca.json'
      : 'assets/domain-model.json';

  final Uri apiBaseUri;

  factory AppConfiguration.fromEnvironment() {
    const value = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    );
    return AppConfiguration.fromValue(value);
  }

  factory AppConfiguration.fromValue(String value) {
    final normalized = value.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const ConfigurationException(
        'API_BASE_URL debe ser una URL HTTP(S) absoluta y sin query ni fragmento.',
      );
    }

    final path = uri.path.isEmpty
        ? '/'
        : uri.path.endsWith('/')
        ? uri.path
        : '${uri.path}/';
    return AppConfiguration._(uri.replace(path: path));
  }

  Uri endpoint(String path, {Map<String, String>? queryParameters}) {
    final relativePath = path.trim().replaceFirst(RegExp(r'^/+'), '');
    return apiBaseUri.replace(
      path: '${apiBaseUri.path}$relativePath',
      queryParameters: queryParameters?.isEmpty ?? true
          ? null
          : queryParameters,
    );
  }
}
