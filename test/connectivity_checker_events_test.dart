import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';

import 'helpers/mock_objects.dart';

void main() {
  late StreamController<String> platformEvents;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(Uri.parse('http://example.com'));
  });

  setUp(() => platformEvents = StreamController<String>.broadcast());

  tearDown(() => platformEvents.close());

  ConnectivityChecker buildChecker(
    MockHttpClient client, {
    List<Duration> recheckDelays = const [],
    Duration checkFrequency = const Duration(hours: 1),
    Duration offlineCheckFrequency = const Duration(hours: 1),
  }) =>
      ConnectivityChecker(
        platform: MockObjects.platform(platformEvents.stream),
        client: client,
        checkFrequency: checkFrequency,
        offlineCheckFrequency: offlineCheckFrequency,
        recheckDelays: recheckDelays,
      );

  void hideApp() => WidgetsBinding.instance
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);

  void showApp() => WidgetsBinding.instance
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  group('native platform events', () {
    test('reports offline immediately on lost, without a network request',
        () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(client);
      final emitted = recordEmissions(sut);

      platformEvents.add('lost');
      await wait(0);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.offline]);
      verifyNoChecks(client);
    });

    test('checks immediately on available', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(client);
      final emitted = recordEmissions(sut);

      platformEvents.add('available');
      await wait(10);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.online]);
      verifyChecks(client, 1);
    });

    test('emits online from a follow-up check when the first check fails',
        () async {
      final client = MockObjects.httpClient([
        MockObjects.response(503),
        MockObjects.response(204),
      ]);
      final sut = buildChecker(
        client,
        recheckDelays: const [Duration(milliseconds: 10)],
      );
      final emitted = recordEmissions(sut);

      platformEvents.add('available');
      await wait(60);

      expect(emitted, [
        ConnectivityStatus.unknown,
        ConnectivityStatus.offline,
        ConnectivityStatus.online,
      ]);
      verifyChecks(client, 2);
    });

    test('stops re-checking after the first online result', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(
        client,
        recheckDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 10),
        ],
      );
      recordEmissions(sut);

      platformEvents.add('available');
      await wait(60);

      verifyChecks(client, 1);
    });

    test('stops after the last follow-up check when the network stays down',
        () async {
      final client = MockObjects.httpClient([MockObjects.response(503)]);
      final sut = buildChecker(
        client,
        recheckDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 10),
        ],
      );
      final emitted = recordEmissions(sut);

      platformEvents.add('available');
      await wait(100);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.offline]);
      verifyChecks(client, 3);
    });

    test('performs a single check when no re-check delays are configured',
        () async {
      final client = MockObjects.httpClient([MockObjects.response(503)]);
      final sut = buildChecker(client);
      recordEmissions(sut);

      platformEvents.add('available');
      await wait(30);

      verifyChecks(client, 1);
    });

    test(
        'a newer event cancels the pending follow-up checks of the previous one',
        () async {
      final client = MockObjects.httpClient([MockObjects.response(503)]);
      final sut = buildChecker(
        client,
        recheckDelays: const [Duration(milliseconds: 100)],
      );
      recordEmissions(sut);

      platformEvents.add('available');
      await wait(20);
      platformEvents.add('available');
      await wait(200);

      verifyChecks(client, 3);
    });

    test('lost cancels the pending follow-up checks', () async {
      final client = MockObjects.httpClient([MockObjects.response(503)]);
      final sut = buildChecker(
        client,
        recheckDelays: const [Duration(milliseconds: 50)],
      );
      final emitted = recordEmissions(sut);

      platformEvents.add('available');
      await wait(10);
      platformEvents.add('lost');
      await wait(100);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.offline]);
      verifyChecks(client, 1);
    });

    test('drops a check result that arrives after a newer event', () async {
      final inFlight = Completer<Response>();
      final client = MockObjects.httpClient([inFlight.future]);
      final sut = buildChecker(client);
      final emitted = recordEmissions(sut);

      platformEvents.add('available');
      await wait(10);
      platformEvents.add('lost');
      inFlight.complete(Response('', 204));
      await wait(10);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.offline]);
      verifyChecks(client, 1);
    });

    test('emits unknown when the platform stream reports an error', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(client);
      final emitted = recordEmissions(sut);
      platformEvents.add('available');
      await wait(10);

      platformEvents.addError(Exception('Critical Platform Error'));
      await wait(0);

      expect(emitted, [
        ConnectivityStatus.unknown,
        ConnectivityStatus.online,
        ConnectivityStatus.unknown,
      ]);
      verifyChecks(client, 1);
    });
  });

  group('periodic checks', () {
    test('check every checkFrequency while online', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(
        client,
        checkFrequency: const Duration(milliseconds: 30),
      );
      recordEmissions(sut);
      platformEvents.add('available');
      await wait(10);
      clearInteractions(client);

      await wait(110);

      verifyChecks(client, greaterThanOrEqualTo(2));
    });

    test('check every offlineCheckFrequency while not online', () async {
      final client = MockObjects.httpClient([MockObjects.response(503)]);
      final sut = buildChecker(
        client,
        offlineCheckFrequency: const Duration(milliseconds: 20),
      );

      final emitted = recordEmissions(sut);
      await wait(90);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.offline]);
      verifyChecks(client, greaterThanOrEqualTo(2));
    });

    test('switch to checkFrequency once online', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(
        client,
        offlineCheckFrequency: const Duration(milliseconds: 20),
      );

      final emitted = recordEmissions(sut);
      await wait(90);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.online]);
      verifyChecks(client, 1);
    });

    test('detect a reconnection the platform never reports', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(
        client,
        offlineCheckFrequency: const Duration(milliseconds: 20),
      );
      final emitted = recordEmissions(sut);
      platformEvents.add('available');
      await wait(10);

      platformEvents.add('lost');
      await wait(50);

      expect(emitted, [
        ConnectivityStatus.unknown,
        ConnectivityStatus.online,
        ConnectivityStatus.offline,
        ConnectivityStatus.online,
      ]);
      verifyChecks(client, 2);
    });

    test('skip a tick while a check is still in flight', () async {
      final inFlight = Completer<Response>();
      addTearDown(() => inFlight.complete(Response('', 204)));
      final client = MockObjects.httpClient([inFlight.future]);
      final sut = buildChecker(
        client,
        offlineCheckFrequency: const Duration(milliseconds: 20),
      );

      recordEmissions(sut);
      await wait(90);

      verifyChecks(client, 1);
    });
  });

  group('app lifecycle', () {
    test('pauses periodic checks while the app is hidden', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(
        client,
        checkFrequency: const Duration(milliseconds: 20),
        offlineCheckFrequency: const Duration(milliseconds: 20),
      );
      recordEmissions(sut);
      addTearDown(showApp);

      hideApp();
      await wait(80);

      verifyNoChecks(client);
    });

    test('checks immediately when the app becomes visible again', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(client);
      final emitted = recordEmissions(sut);
      hideApp();

      showApp();
      await wait(10);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.online]);
      verifyChecks(client, 1);
    });

    test('does not start periodic checks when subscribing while hidden',
        () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(
        client,
        checkFrequency: const Duration(milliseconds: 20),
        offlineCheckFrequency: const Duration(milliseconds: 20),
      );
      hideApp();
      addTearDown(showApp);

      recordEmissions(sut);
      await wait(80);

      verifyNoChecks(client);
    });
  });
}
