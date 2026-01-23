import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import '../../rx_connectivity_checker_platform_interface.dart';

/// The Web implementation of [RxConnectivityCheckerPlatform].
///
/// This class uses modern JS interop ([dart:js_interop] and [package:web]) to
/// observe the browser's connectivity events. It adheres to the Federated
/// Plugin architecture to provide seamless web support for the
/// `rx_connectivity_checker` package.
class WebRxConnectivityChecker extends RxConnectivityCheckerPlatform {
  /// A broadcast [Stream] that emits the current network status.
  ///
  /// This stream listens to the browser's `online` and `offline` events on
  /// the [web.window] object.
  ///
  /// * Emits `'satisfied'` when the browser reports the device is online.
  /// * Emits `'unsatisfied'` when the browser reports the device is offline.
  ///
  /// This implementation uses a "cold" approach: event listeners are only
  /// attached to the browser when there is at least one active listener
  /// on the Dart side.
  @override
  Stream<String> get platformStatusStream {
    late StreamController<String> controller;

    // References to the JS functions are stored to allow for proper
    // removal if the stream is ever fully cancelled.
    JSFunction? onlineHandler;
    JSFunction? offlineHandler;

    controller = StreamController<String>.broadcast(
      onListen: () {
        // 1. Synchronously emit the current state upon first subscription.
        final bool isOnline = web.window.navigator.onLine;
        controller.add(isOnline ? 'satisfied' : 'unsatisfied');

        // 2. Define and convert Dart closures to JS functions.
        onlineHandler = ((web.Event _) => controller.add('satisfied')).toJS;
        offlineHandler = ((web.Event _) => controller.add('unsatisfied')).toJS;

        // 3. Attach native event listeners to the browser window.
        web.window.addEventListener('online', onlineHandler!);
        web.window.addEventListener('offline', offlineHandler!);
      },
      onCancel: () {
        // Cleanup: Remove listeners to prevent memory leaks in the browser.
        if (onlineHandler != null) {
          web.window.removeEventListener('online', onlineHandler!);
        }
        if (offlineHandler != null) {
          web.window.removeEventListener('offline', offlineHandler!);
        }
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Returns the browser's user agent string.
  ///
  /// Used primarily for debugging and identifying the browser environment.
  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }

  /// Registers this class as the default instance of [RxConnectivityCheckerPlatform].
  ///
  /// This is called automatically by the Flutter build system during the
  /// plugin initialization phase on the web.
  static void registerWith(Registrar registrar) {
    RxConnectivityCheckerPlatform.instance = WebRxConnectivityChecker();
  }
}
