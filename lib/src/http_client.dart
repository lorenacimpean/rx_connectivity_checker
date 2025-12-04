import 'package:http/http.dart' as http;

/// Default implementation using the standard `package:http` library.
///
/// This implementation allows the application to function normally while
/// providing the capability to inject mock clients during testing.
class DefaultHttpClient implements IHttpClient {
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      http.get(url, headers: headers);
}

/// Interface for the HTTP client dependency.
///
/// Abstracting the HTTP client ensures testability and allows the core logic
/// (e.g., [ConnectivityChecker]) to depend on a stable contract rather than a
/// concrete implementation (DIP).
abstract class IHttpClient {
  Future<http.Response> get(Uri url, {Map<String, String>? headers});
}
