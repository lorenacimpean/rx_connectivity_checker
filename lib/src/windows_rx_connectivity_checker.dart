import 'dart:async';

import 'package:flutter/services.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker_platform_interface.dart';

/// The Windows implementation of [RxConnectivityCheckerPlatform].
class WindowsRxConnectivityChecker extends RxConnectivityCheckerPlatform {
  /// Matches Android: "rx_connectivity_checker"
  final MethodChannel _methodChannel = const MethodChannel(
    'rx_connectivity_checker',
  );

  /// Matches Android: "rx_connectivity_checker/events"
  final EventChannel _eventChannel = const EventChannel(
    'rx_connectivity_checker/events',
  );

  /// Returns a stream of strings matching the Android implementation:
  /// "available", "lost", "capabilities_changed".
  ///
  /// The main [ConnectivityChecker] listens to this to trigger validation.
  @override
  Stream<String> get platformStatusStream {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      return event.toString();
    });
  }

  @override
  Future<String?> getPlatformVersion() async {
    return await _methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  /// Registers this class as the default instance of [RxConnectivityCheckerPlatform].
  static void registerWith() {
    RxConnectivityCheckerPlatform.instance = WindowsRxConnectivityChecker();
  }
}
