import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';

/// NetworkManager values used by the Linux tests.
abstract final class NetworkManagerValues {
  static const int connectivityUnknown = 0;
  static const int connectivityNone = 1;
  static const int connectivityFull = 4;
  static const int stateDisconnected = 20;
  static const int stateConnecting = 40;
  static const int stateConnectedGlobal = 70;
}

/// A private D-Bus bus, optionally hosting a fake
/// `org.freedesktop.NetworkManager`, so that the Linux implementation can be
/// exercised on any operating system.
class FakeNetworkManagerBus {
  FakeNetworkManagerBus._(
    this._server,
    this._address,
    this._serviceClient,
    this._networkManager,
  );

  static const String _networkManagerName = 'org.freedesktop.NetworkManager';

  // package:dbus only derives the EXTERNAL auth uid on Linux and Windows; the
  // in-process server does not check it, so a fixed uid works on every OS.
  static const String _testUid = '1000';

  final DBusServer _server;
  final DBusAddress _address;
  final DBusClient _serviceClient;
  final _FakeNetworkManager? _networkManager;

  int _connectionCount = 0;

  /// How many clients [connect] has opened.
  int get connectionCount => _connectionCount;

  /// Starts a bus that is closed at the end of the test.
  ///
  /// NetworkManager reports [connectivity] when asked; when [connectivity] is
  /// null, no NetworkManager is published on the bus.
  static Future<FakeNetworkManagerBus> start({int? connectivity}) async {
    final server = DBusServer();
    final address = await server.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    final serviceClient = _client(address);
    final networkManager =
        connectivity == null ? null : _FakeNetworkManager(connectivity);
    if (networkManager != null) {
      await serviceClient.requestName(_networkManagerName);
      await serviceClient.registerObject(networkManager);
    }
    final bus = FakeNetworkManagerBus._(
      server,
      address,
      serviceClient,
      networkManager,
    );
    addTearDown(bus._close);
    return bus;
  }

  /// Opens a client on this bus, as the Linux implementation does on listen.
  DBusClient connect() {
    _connectionCount++;
    return _client(_address);
  }

  static DBusClient _client(DBusAddress address) =>
      DBusClient(address, authClient: DBusAuthClient(uid: _testUid));

  /// Emits NetworkManager's `StateChanged` signal carrying [state].
  Future<void> changeState(int state) => _networkManager!.emitSignal(
        _networkManagerName,
        'StateChanged',
        [DBusUint32(state)],
      );

  Future<void> _close() async {
    await _serviceClient.close();
    await _server.close();
  }
}

class _FakeNetworkManager extends DBusObject {
  _FakeNetworkManager(this._connectivity)
      : super(DBusObjectPath('/org/freedesktop/NetworkManager'));

  final int _connectivity;

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async =>
      interface == 'org.freedesktop.NetworkManager' && name == 'Connectivity'
          ? DBusGetPropertyResponse(DBusUint32(_connectivity))
          : DBusMethodErrorResponse.unknownProperty();
}
