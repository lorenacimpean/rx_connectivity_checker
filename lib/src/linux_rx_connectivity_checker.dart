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
  /// The system-level D-Bus client used for communication.
  ///
  /// NetworkManager resides on the System Bus (not the Session Bus) because
  /// network configuration is a global system state.
  late final DBusClient _client;

  /// Creates an instance of [LinuxRxConnectivityChecker] and initializes
  /// the system D-Bus client.
  LinuxRxConnectivityChecker() {
    _client = DBusClient.system();
  }

  /// A broadcast [Stream] that emits changes in the Linux system's network status.
  ///
  /// This stream performs two primary actions:
  /// 1. On subscription, it fetches the current `Connectivity` property from
  ///    `org.freedesktop.NetworkManager` to provide an immediate initial value.
  /// 2. It subscribes to the `StateChanged` signal to react to real-time updates
  ///    (e.g., unplugging an Ethernet cable or switching Wi-Fi networks).
  ///
  /// Returns `'satisfied'` if the system reports full internet connectivity,
  /// otherwise returns `'unsatisfied'`.
  @override
  Stream<String> get platformStatusStream {
    late StreamController<String> controller;
    StreamSubscription? signalSubscription;

    controller = StreamController<String>.broadcast(
      onListen: () async {
        try {
          // 1. Initial State Check
          // Fetch current Connectivity via the standard 'org.freedesktop.DBus.Properties'
          final result = await _client.callMethod(
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
          signalSubscription =
              DBusSignalStream(
                _client,
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
          controller.add('unknown');
        }
      },
      onCancel: () {
        // OOP Principle: Clean up the subscription to prevent memory leaks
        // and stop receiving unnecessary system signals.
        signalSubscription?.cancel();
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
      controller.add('satisfied');
    } else {
      controller.add('unsatisfied');
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
