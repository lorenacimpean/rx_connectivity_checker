import 'dart:async';

import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';

import 'reachability_validator.dart';

/// Global function called by the factory
ReachabilityValidator getValidator() => NativeReachabilityValidator();

class NativeReachabilityValidator implements ReachabilityValidator {
  @override
  Future<ConnectivityStatus> validate({
    required String url,
    required Duration timeout,
    Duration? slowThreshold,
    Map<String, String>? headers,
    IHttpClient? client,
  }) async {
    // Fall back to the default HTTP client when none is injected so that
    // callers constructing NativeReachabilityValidator directly (e.g. in
    // tests) do not hit a null-dereference crash.
    final effectiveClient = client ?? DefaultHttpClient();
    final stopwatch = Stopwatch()..start();
    try {
      final response = await effectiveClient
          .get(Uri.parse(url), headers: headers)
          .timeout(timeout);

      return (response.statusCode >= 200 && response.statusCode < 300)
          ? statusForReachedServer(
              elapsed: stopwatch.elapsed,
              slowThreshold: slowThreshold,
            )
          : ConnectivityStatus.offline;
    } catch (_) {
      // No response within the timeout (e.g. a network without internet
      // access, where requests hang), a socket error or any other failure:
      // the server was not reached.
      return ConnectivityStatus.offline;
    }
  }
}
