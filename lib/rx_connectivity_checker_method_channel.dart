import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rx_connectivity_checker_platform_interface.dart';

/// An implementation of [RxConnectivityCheckerPlatform] that uses method channels.
class MethodChannelRxConnectivityChecker extends RxConnectivityCheckerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('rx_connectivity_checker');

  /// The event channel used to listen for continuous network changes.
  /// The name MUST match the one defined in Android (Kotlin) and iOS (Swift).
  @visibleForTesting
  final eventChannel = const EventChannel('rx_connectivity_checker/events');

  /// Cached stream to prevent creating multiple transformers/subscriptions.
  Stream<String>? _onConnectivityChanged;

  /// Exposes the native connectivity events as a Dart stream.
  ///
  /// This implementation:
  /// 1. Uses a Singleton-like pattern for the stream to ensure efficiency.
  /// 2. Handles generic PlatformExceptions gracefully.
  @override
  Stream<String> get platformStatusStream {
    // Optimization: Initialize the stream only once (Lazy Loading)
    _onConnectivityChanged ??= eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => event.toString())
        .handleError((error) {
          // Log error or handle specific platform exceptions here
          debugPrint('RxConnectivityChecker: Error in stream: $error');
          // Return a fallback state or rethrow depending on requirements
          return 'unknown';
        });

    return _onConnectivityChanged!;
  }

  @override
  Future<String?> getPlatformVersion() async {
    try {
      final version = await methodChannel.invokeMethod<String>(
        'getPlatformVersion',
      );
      return version;
    } on PlatformException catch (e) {
      // Adhering to KISS: Log the error and return null, allowing the UI
      // to handle the "unknown" state rather than crashing.
      debugPrint(
        'RxConnectivityChecker: Failed to get platform version: ${e.message}',
      );
      return null;
    }
  }
}
