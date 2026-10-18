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
  static const String _available = 'available';
  static const String _lost = 'lost';
  static const String _unknown = 'unknown';
  static const String _networkManagerName = 'org.freedesktop.NetworkManager';

  // NMConnectivityState values of the `Connectivity` property.
  static const int _nmConnectivityNone = 1;
  static const int _nmConnectivityFull = 4;

  // NMState values carried by the `StateChanged` signal.
  static const int _nmStateAsleep = 10;
  static const int _nmStateDisconnected = 20;
  static const int _nmStateConnectedGlobal = 70;

  /// Creates the Linux implementation.
  ///
  /// [createClient] opens the D-Bus connection; it defaults to the system bus
  /// and is only replaced in tests (e.g. with a private bus hosting a fake
  /// NetworkManager).
  LinuxRxConnectivityChecker({
    @visibleForTesting DBusClient Function()? createClient,
  }) : _createClient = createClient ?? DBusClient.system;

  final DBusClient Function() _createClient;

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
  /// Emits `'available'` for full internet connectivity, `'lost'` when there is
  /// no network at all, and `'unknown'` for every other state (connectivity
  /// checking disabled, captive portal, limited or transitional states, or
  /// NetworkManager unreachable) so that the Dart side verifies access itself.
  @override
  Stream<String> get platformStatusStream {
    _cachedStream ??= _buildStream();
    return _cachedStream!;
  }

  Stream<String> _buildStream() {
    late StreamController<String> controller;
    StreamSubscription<int>? signalSubscription;
    DBusClient? client;

    controller = StreamController<String>.broadcast(
      onListen: () async {
        // Each listen session owns its client, so a cancel that overlaps a new
        // listen (e.g. navigating between screens) never closes the new one.
        final sessionClient = _createClient();
        client = sessionClient;
        try {
          final connectivity = await _readConnectivity(sessionClient);
          if (client != sessionClient) return;
          if (connectivity != null) {
            controller.add(statusFromConnectivity(connectivity));
          }
          signalSubscription = _stateChanges(sessionClient).listen(
            (state) => controller.add(statusFromState(state)),
          );
        } catch (e) {
          // Without NetworkManager (not installed, or a sandbox without system
          // bus access) the network state is unknown, not lost: let the Dart
          // side check over HTTP instead of reporting offline.
          debugPrint('LinuxConnectivity Error: $e');
          if (client == sessionClient) controller.add(_unknown);
        }
      },
      onCancel: () async {
        final cancelledSubscription = signalSubscription;
        final cancelledClient = client;
        signalSubscription = null;
        client = null;
        // The next call to platformStatusStream creates a fresh stream with a
        // new D-Bus connection.
        _cachedStream = null;
        // Cancel the signal subscription first, then close the D-Bus client
        // to release the underlying system socket and prevent FD leaks.
        await cancelledSubscription?.cancel();
        await cancelledClient?.close();
      },
    );

    return controller.stream;
  }

  /// Reads NetworkManager's current `Connectivity` property.
  Future<int?> _readConnectivity(DBusClient client) async {
    final result = await client.callMethod(
      destination: _networkManagerName,
      path: DBusObjectPath('/org/freedesktop/NetworkManager'),
      interface: 'org.freedesktop.DBus.Properties',
      name: 'Get',
      values: [DBusString(_networkManagerName), DBusString('Connectivity')],
    );
    // Properties.Get returns a Variant (v), which we unpack to Uint32 (u).
    return result.returnValues.isEmpty
        ? null
        : result.returnValues[0].asVariant().asUint32();
  }

  /// NetworkManager's `StateChanged` signals, as NMState values.
  Stream<int> _stateChanges(DBusClient client) => DBusSignalStream(
        client,
        sender: _networkManagerName,
        interface: _networkManagerName,
        name: 'StateChanged',
      )
          .where((signal) => signal.values.isNotEmpty)
          .map((signal) => signal.values[0].asUint32());

  /// Returns the current platform version string.
  @override
  Future<String?> getPlatformVersion() async => "Linux (DBus)";

  /// Maps NetworkManager's `Connectivity` property to a plugin status.
  ///
  /// `NM_CONNECTIVITY_UNKNOWN` (checking disabled), `PORTAL` and `LIMITED`
  /// map to `'unknown'` so that the Dart side runs its own check.
  @visibleForTesting
  static String statusFromConnectivity(int connectivity) =>
      switch (connectivity) {
        _nmConnectivityFull => _available,
        _nmConnectivityNone => _lost,
        _ => _unknown,
      };

  /// Maps the NetworkManager state carried by `StateChanged` to a plugin status.
  ///
  /// Only `NM_STATE_ASLEEP` and `NM_STATE_DISCONNECTED` mean there is no network;
  /// connecting, local-only and site-only states map to `'unknown'`.
  @visibleForTesting
  static String statusFromState(int state) => switch (state) {
        _nmStateConnectedGlobal => _available,
        _nmStateAsleep || _nmStateDisconnected => _lost,
        _ => _unknown,
      };

  /// Registers this class as the default instance of [RxConnectivityCheckerPlatform]
  /// for the Linux platform.
  ///
  /// This method is called by the generated platform initialization code.
  static void registerWith() {
    RxConnectivityCheckerPlatform.instance = LinuxRxConnectivityChecker();
  }
}
