import 'dart:async';

import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'reachability_validator_stub.dart'
    if (dart.library.js_interop) 'web_reachability_validator.dart'
    if (dart.library.io) 'native_reachability_validator.dart';

/// Abstract strategy for performing low-level network reachability probes.
abstract class ReachabilityValidator {
  /// Unified factory that returns the platform-correct implementation.
  /// The 'getValidator' function is defined in each of the three files above.
  factory ReachabilityValidator() => getValidator();

  /// Validates reachability by performing a network request.
  Future<ConnectivityStatus> validate({
    required String url,
    required Duration timeout,
    required bool checkSlowConnection,
    Map<String, String>? headers,
    IHttpClient? client,
  });
}
