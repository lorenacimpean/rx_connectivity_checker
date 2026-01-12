import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'rx_connectivity_checker_method_channel.dart';

abstract class RxConnectivityCheckerPlatform extends PlatformInterface {
  static final Object _token = Object();

  static RxConnectivityCheckerPlatform _instance =
      MethodChannelRxConnectivityChecker();

  static RxConnectivityCheckerPlatform get instance => _instance;

  static set instance(RxConnectivityCheckerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  RxConnectivityCheckerPlatform() : super(token: _token);

  /// A stream that emits events when the native platform detects a connectivity change.
  ///
  /// Returns a stream of strings representing the status (e.g. "satisfied", "lost").
  Stream<String> get platformStatusStream {
    throw UnimplementedError('onConnectivityChanged has not been implemented.');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
