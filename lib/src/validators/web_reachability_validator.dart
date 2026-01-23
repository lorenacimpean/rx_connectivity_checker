import 'dart:async';
import 'dart:js_interop';

import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:web/web.dart' as web;

import 'reachability_validator.dart';

/// Global function called by the factory
ReachabilityValidator getValidator() => WebReachabilityValidator();

class WebReachabilityValidator implements ReachabilityValidator {
  @override
  Future<ConnectivityStatus> validate({
    required String url,
    required Duration timeout,
    required bool checkSlowConnection,
    Map<String, String>? headers,
    IHttpClient? client,
  }) async {
    try {
      final fetchOptions = web.RequestInit(
        method: 'HEAD',
        mode: 'no-cors', // Essential for bypasssing browser CORS blocks
        cache: 'no-cache',
      );

      // Web fetch does not have a native timeout parameter; handled via Dart Future
      await web.window.fetch(url.toJS, fetchOptions).toDart.timeout(timeout);

      // In 'no-cors', a successful completion (even with an opaque response)
      // confirms the server is reachable.
      return ConnectivityStatus.online;
    } on TimeoutException {
      return checkSlowConnection
          ? ConnectivityStatus.slow
          : ConnectivityStatus.offline;
    } catch (_) {
      // Any JS TypeError or network error caught here maps to offline.
      return ConnectivityStatus.offline;
    }
  }
}
