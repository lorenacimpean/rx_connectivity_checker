import 'dart:async';

import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'reachability_validator_stub.dart'
    if (dart.library.js_interop) 'web_reachability_validator.dart'
    if (dart.library.io) 'native_reachability_validator.dart';

/// Abstract strategy for performing low-level network reachability probes.
abstract class ReachabilityValidator {
  /// Unified factory that returns the platform-correct implementation.
  factory ReachabilityValidator() => getValidator();

  /// Validates reachability by performing a network request.
  ///
  /// A successful response is [ConnectivityStatus.online], or
  /// [ConnectivityStatus.slow] when it took longer than [slowThreshold] (slow
  /// detection is off when [slowThreshold] is null). No response within
  /// [timeout], or any failure, is [ConnectivityStatus.offline].
  Future<ConnectivityStatus> validate({
    required String url,
    required Duration timeout,
    Duration? slowThreshold,
    Map<String, String>? headers,
    IHttpClient? client,
  });
}

/// The status of a request that reached the server after [elapsed].
ConnectivityStatus statusForReachedServer({
  required Duration elapsed,
  required Duration? slowThreshold,
}) =>
    slowThreshold != null && elapsed > slowThreshold
        ? ConnectivityStatus.slow
        : ConnectivityStatus.online;
