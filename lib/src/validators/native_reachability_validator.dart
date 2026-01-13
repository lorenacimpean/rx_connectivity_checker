import 'dart:async';
import 'dart:io';

import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';

import 'reachability_validator.dart';

/// Global function called by the factory
ReachabilityValidator getValidator() => NativeReachabilityValidator();

class NativeReachabilityValidator implements ReachabilityValidator {
  @override
  Future<ConnectivityStatus> validate({
    required String url,
    required Duration timeout,
    required bool checkSlowConnection,
    Map<String, String>? headers,
    IHttpClient? client,
  }) async {
    try {
      final response = await client!
          .get(Uri.parse(url), headers: headers)
          .timeout(timeout);

      return (response.statusCode >= 200 && response.statusCode < 300)
          ? ConnectivityStatus.online
          : ConnectivityStatus.offline;
    } on TimeoutException {
      return checkSlowConnection
          ? ConnectivityStatus.slow
          : ConnectivityStatus.offline;
    } on SocketException {
      return ConnectivityStatus.offline;
    } catch (_) {
      return ConnectivityStatus.offline;
    }
  }
}
