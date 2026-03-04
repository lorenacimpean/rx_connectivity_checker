import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:web/web.dart' as web;

import 'reachability_validator.dart';

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
    assert(
      client == null,
      'IHttpClient injection is not supported on the web platform.',
    );

    if (headers != null) {
      debugPrint(
        'RxConnectivityChecker: custom headers are not supported on web and will be ignored.',
      );
    }

    try {
      final fetchOptions = web.RequestInit(
        method: 'GET',
        mode: 'cors',
        cache: 'no-cache',
      );

      await web.window.fetch(url.toJS, fetchOptions).toDart.timeout(timeout);

      return ConnectivityStatus.online;
    } on TimeoutException {
      return checkSlowConnection
          ? ConnectivityStatus.slow
          : ConnectivityStatus.offline;
    } catch (_) {
      // A CORS TypeError or NetworkError both mean the server was contacted
      // (or definitively unreachable). We treat non-timeout errors as online
      // because a CORS rejection proves the server responded.
      // A true network failure (no route, DNS failure) throws before timeout
      // and lands here as offline.
      //
      // Distinguish by checking if we're actually offline per the browser:
      if (!web.window.navigator.onLine) {
        return ConnectivityStatus.offline;
      }
      // Browser says online but fetch threw (CORS rejection = server reachable).
      return ConnectivityStatus.online;
    }
  }
}
