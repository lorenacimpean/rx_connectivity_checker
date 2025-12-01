import 'package:http/http.dart';

/// Default implementation using `package:http`.
class DefaultHttpClient {
  Future<Response> get(Uri url, {Map<String, String>? headers}) => get(url);
}
