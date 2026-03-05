import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker_platform_interface.dart';

/// The Linux implementation of [RxConnectivityCheckerPlatform] using the D-Bus
/// system bus to communicate with NetworkManager.
///
/// This implementation subscribes to system signals to provide a reactive
/// stream of connectivity updates without constant polling.
class LinuxRxConnectivityChecker extends RxConnectivityCheckerPlatform {
  /// Cached broadcast stream so that multiple subscribers (e.g. multiple
  /// [ConnectivityChecker] instances) share a single D-Bus connection rather
  /// than each creating their own.
  Stream<String>? _cachedStream;

  /// A broadcast [Stream] that emits changes in the Linux system's network status.
  ///
  /// On first subscription the stream:
  /// 1. Opens a system D-Bus connection and fetches the current `Connectivity`
  ///    property from `org.freedesktop.NetworkManager` for an immediate value.
  /// 2. Subscribes to `StateChanged` signals for real-time updates.
  ///
  /// The D-Bus connection is closed when the last subscriber cancels, releasing
  /// the underlying file descriptor and preventing leaks on hot-restart or
  /// widget disposal. A subsequent subscription reopens the connection.
  ///
  /// Emits `'available'` for full internet connectivity, `'lost'` otherwise.
  @override
  Stream<String> get platformStatusStream {
    _cachedStream ??= _buildStream();
    return _cachedStream!;
  }

  Stream<String> _buildStream() {
    late StreamController<String> controller;
    StreamSubscription? signalSubscription;
    DBusClient? client;

    controller = StreamController<String>.broadcast(
      onListen: () async {
        // Create a fresh D-Bus client each time a new subscription begins so
        // that re-subscribing after a cancel works correctly.
        client = DBusClient.system();
        try {
          // 1. Initial State Check
          // Fetch current Connectivity via the standard 'org.freedesktop.DBus.Properties'
          final result = await client!.callMethod(
            destination: 'org.freedesktop.NetworkManager',
            path: DBusObjectPath('/org/freedesktop/NetworkManager'),
            interface: 'org.freedesktop.DBus.Properties',
            name: 'Get',
            values: [
              DBusString('org.freedesktop.NetworkManager'),
              DBusString('Connectivity'),
            ],
          );

          if (result.returnValues.isNotEmpty) {
            // Properties.Get returns a Variant (v), which we unpack to Uint32 (u)
            final connectivity = result.returnValues[0].asVariant().asUint32();
            _emitStatus(controller, connectivity);
          }

          // 2. Continuous Monitoring
          // Listen for 'StateChanged' signals emitted by NetworkManager
          signalSubscription = DBusSignalStream(
            client!,
            sender: 'org.freedesktop.NetworkManager',
            interface: 'org.freedesktop.NetworkManager',
            name: 'StateChanged',
          ).listen((signal) {
            if (signal.values.isNotEmpty) {
              final state = signal.values[0].asUint32();
              _emitStatus(controller, state);
            }
          });
        } catch (e) {
          debugPrint('LinuxConnectivity Error: $e');
          controller.add('lost');
        }
      },
      onCancel: () async {
        // Cancel the signal subscription first, then close the D-Bus client
        // to release the underlying system socket and prevent FD leaks on
        // hot-restart or widget disposal.
        await signalSubscription?.cancel();
        signalSubscription = null;
        await client?.close();
        client = null;
        // Clear the cache so the next call to platformStatusStream creates a
        // fresh stream with a new D-Bus connection.
        _cachedStream = null;
      },
    );

    return controller.stream;
  }

  /// Returns the current platform version string.
  @override
  Future<String?> getPlatformVersion() async => "Linux (DBus)";

  /// Translates Linux NetworkManager state codes into unified plugin status strings.
  ///
  /// * [state] of `4` represents `NM_CONNECTIVITY_FULL`.
  /// * [state] of `70` represents `NM_STATE_CONNECTED_GLOBAL`.
  void _emitStatus(StreamController<String> controller, int state) {
    if (state == 4 || state == 70) {
      controller.add('available');
    } else {
      controller.add('lost');
    }
  }

  /// Registers this class as the default instance of [RxConnectivityCheckerPlatform]
  /// for the Linux platform.
  ///
  /// This method is called by the generated platform initialization code.
  static void registerWith() {
    RxConnectivityCheckerPlatform.instance = LinuxRxConnectivityChecker();
  }
}
