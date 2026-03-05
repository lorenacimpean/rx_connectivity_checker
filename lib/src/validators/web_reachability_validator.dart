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
      // no-cors avoids preflight and CORS header requirements. The fetch
      // resolves with an opaque response on success (server reached = online)
      // and rejects with a TypeError on a genuine network failure (offline).
      final fetchOptions = web.RequestInit(
        method: 'GET',
        mode: 'no-cors',
        cache: 'no-store',
      );

      await web.window.fetch(url.toJS, fetchOptions).toDart.timeout(timeout);

      return ConnectivityStatus.online;
    } on TimeoutException {
      return checkSlowConnection
          ? ConnectivityStatus.slow
          : ConnectivityStatus.offline;
    } catch (_) {
      // TypeError / NetworkError: genuine network failure.
      // Use navigator.onLine as a secondary signal.
      return web.window.navigator.onLine
          ? ConnectivityStatus.online
          : ConnectivityStatus.offline;
    }
  }
}
