import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker_platform_interface.dart';
import 'package:rx_connectivity_checker/src/linux_rx_connectivity_checker.dart';

import 'helpers/fake_network_manager_bus.dart';
import 'helpers/mock_objects.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(Uri.parse('http://example.com'));
  });

  List<String> recordEvents(LinuxRxConnectivityChecker sut) {
    final events = <String>[];
    final subscription = sut.platformStatusStream.listen(events.add);
    addTearDown(subscription.cancel);
    return events;
  }

  group('platformStatusStream with a fake NetworkManager', () {
    test('emits available on listen when connectivity is full', () async {
      final bus = await FakeNetworkManagerBus.start(
        connectivity: NetworkManagerValues.connectivityFull,
      );
      final sut = LinuxRxConnectivityChecker(createClient: bus.connect);

      final events = recordEvents(sut);
      await eventually(() => events.isNotEmpty);

      expect(events, ['available']);
    });

    test('emits lost on listen when there is no connectivity', () async {
      final bus = await FakeNetworkManagerBus.start(
        connectivity: NetworkManagerValues.connectivityNone,
      );
      final sut = LinuxRxConnectivityChecker(createClient: bus.connect);

      final events = recordEvents(sut);
      await eventually(() => events.isNotEmpty);

      expect(events, ['lost']);
    });

    test('emits unknown on listen when connectivity checking is disabled',
        () async {
      final bus = await FakeNetworkManagerBus.start(
        connectivity: NetworkManagerValues.connectivityUnknown,
      );
      final sut = LinuxRxConnectivityChecker(createClient: bus.connect);

      final events = recordEvents(sut);
      await eventually(() => events.isNotEmpty);

      expect(events, ['unknown']);
    });

    test('reports Wi-Fi turned off and on through StateChanged signals',
        () async {
      final bus = await FakeNetworkManagerBus.start(
        connectivity: NetworkManagerValues.connectivityFull,
      );
      final sut = LinuxRxConnectivityChecker(createClient: bus.connect);
      final events = recordEvents(sut);
      await eventually(() => events.isNotEmpty);
      await wait(100);

      await bus.changeState(NetworkManagerValues.stateDisconnected);
      await bus.changeState(NetworkManagerValues.stateConnecting);
      await bus.changeState(NetworkManagerValues.stateConnectedGlobal);
      await eventually(() => events.length == 4);

      expect(events, ['available', 'lost', 'unknown', 'available']);
    });

    test('emits unknown when NetworkManager is not on the bus', () async {
      final bus = await FakeNetworkManagerBus.start();
      final sut = LinuxRxConnectivityChecker(createClient: bus.connect);

      final events = recordEvents(sut);
      await eventually(() => events.isNotEmpty);

      expect(events, ['unknown']);
    });

    test('emits unknown when the bus cannot be reached', () async {
      final sut = LinuxRxConnectivityChecker(
        createClient: () => DBusClient(
          DBusAddress.unix(
            path: '${Directory.systemTemp.path}/rxcc-missing-bus-socket',
          ),
        ),
      );

      final events = recordEvents(sut);
      await eventually(() => events.isNotEmpty);

      expect(events, ['unknown']);
    });

    test('opens a new connection when listened to again after a cancel',
        () async {
      final bus = await FakeNetworkManagerBus.start(
        connectivity: NetworkManagerValues.connectivityFull,
      );
      final sut = LinuxRxConnectivityChecker(createClient: bus.connect);
      final firstEvents = <String>[];
      final first = sut.platformStatusStream.listen(firstEvents.add);
      await eventually(() => firstEvents.isNotEmpty);
      await first.cancel();

      final events = recordEvents(sut);
      await eventually(() => events.isNotEmpty);

      expect(events, ['available']);
      expect(bus.connectionCount, 2);
    });
  });

  group('ConnectivityChecker on Linux', () {
    test('reports offline instantly and online again across a Wi-Fi toggle',
        () async {
      final bus = await FakeNetworkManagerBus.start(
        connectivity: NetworkManagerValues.connectivityFull,
      );
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final checker = ConnectivityChecker(
        platform: LinuxRxConnectivityChecker(createClient: bus.connect),
        client: client,
        checkFrequency: const Duration(hours: 1),
        offlineCheckFrequency: const Duration(hours: 1),
        recheckDelays: const [],
      );
      final emitted = recordEmissions(checker);
      await eventually(() =>
          emitted.isNotEmpty && emitted.last == ConnectivityStatus.online);
      await wait(100);

      await bus.changeState(NetworkManagerValues.stateDisconnected);
      await eventually(() =>
          emitted.isNotEmpty && emitted.last == ConnectivityStatus.offline);
      await bus.changeState(NetworkManagerValues.stateConnectedGlobal);
      await eventually(() => emitted.length == 4);

      expect(emitted, [
        ConnectivityStatus.unknown,
        ConnectivityStatus.online,
        ConnectivityStatus.offline,
        ConnectivityStatus.online,
      ]);
      verifyChecks(client, 2);
    });
  });

  group('statusFromConnectivity', () {
    test('maps NM_CONNECTIVITY_FULL to available', () {
      final result = LinuxRxConnectivityChecker.statusFromConnectivity(4);

      expect(result, 'available');
    });

    test('maps NM_CONNECTIVITY_NONE to lost', () {
      final result = LinuxRxConnectivityChecker.statusFromConnectivity(1);

      expect(result, 'lost');
    });

    test('maps UNKNOWN, PORTAL and LIMITED to unknown', () {
      final results =
          [0, 2, 3].map(LinuxRxConnectivityChecker.statusFromConnectivity);

      expect(results, everyElement('unknown'));
    });

    test('maps an undocumented value to unknown', () {
      final result = LinuxRxConnectivityChecker.statusFromConnectivity(99);

      expect(result, 'unknown');
    });
  });

  group('statusFromState', () {
    test('maps NM_STATE_CONNECTED_GLOBAL to available', () {
      final result = LinuxRxConnectivityChecker.statusFromState(70);

      expect(result, 'available');
    });

    test('maps NM_STATE_ASLEEP and NM_STATE_DISCONNECTED to lost', () {
      final results = [10, 20].map(LinuxRxConnectivityChecker.statusFromState);

      expect(results, everyElement('lost'));
    });

    test(
        'maps unknown, disconnecting, connecting, local and site states to unknown',
        () {
      final results =
          [0, 30, 40, 50, 60].map(LinuxRxConnectivityChecker.statusFromState);

      expect(results, everyElement('unknown'));
    });

    test('does not treat the connectivity value 4 as a connected state', () {
      final result = LinuxRxConnectivityChecker.statusFromState(4);

      expect(result, 'unknown');
    });
  });

  group('registerWith', () {
    test('installs the Linux implementation as the platform instance', () {
      LinuxRxConnectivityChecker.registerWith();

      expect(
        RxConnectivityCheckerPlatform.instance,
        isA<LinuxRxConnectivityChecker>(),
      );
    });
  });

  group('getPlatformVersion', () {
    test('reports the D-Bus based implementation', () async {
      final result = await LinuxRxConnectivityChecker().getPlatformVersion();

      expect(result, 'Linux (DBus)');
    });
  });
}
