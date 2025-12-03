import 'package:http/http.dart' as http;
import 'package:http/http.dart';

/// Default implementation using `package:http`.
class DefaultHttpClient implements IHttpClient {
  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) =>
      http.get(url, headers: headers);
}

/// Interface for the HTTP client dependency, ensuring testability.
abstract class IHttpClient {
  Future<http.Response> get(Uri url, {Map<String, String>? headers});
}
