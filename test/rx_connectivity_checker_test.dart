import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker_platform_interface.dart';

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
    RxConnectivityCheckerPlatform? platform,
    Duration checkFrequency = const Duration(hours: 1),
  }) =>
      ConnectivityChecker(
        platform: platform ?? MockObjects.platform(platformEvents.stream),
        client: client,
        checkFrequency: checkFrequency,
        recheckDelays: const [],
      );

  group('constructor', () {
    test('uses the documented defaults when nothing is injected', () {
      final sut = ConnectivityChecker();

      expect(
        (
          sut.timeout,
          sut.checkFrequency,
          sut.checkSlowConnection,
          sut.recheckDelays,
        ),
        (
          ConnectivityCheckerConstants.defaultTimeout,
          ConnectivityCheckerConstants.defaultCheckFrequency,
          false,
          ConnectivityCheckerConstants.defaultRecheckDelays,
        ),
      );
    });
  });

  group('connectivityStream', () {
    test('emits unknown to the first listener before any check completes',
        () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(client);

      final emitted = recordEmissions(sut);
      await wait(10);

      expect(emitted, [ConnectivityStatus.unknown]);
      verifyNoChecks(client);
    });

    test('replays the last known status to a listener that subscribes later',
        () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(client);
      recordEmissions(sut);
      platformEvents.add('available');
      await wait(20);

      final lateEmitted = recordEmissions(sut);
      await wait(10);

      expect(lateEmitted, [ConnectivityStatus.online]);
      verifyChecks(client, 1);
    });

    test('emits only when the status changes', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(client);
      final emitted = recordEmissions(sut);

      platformEvents.add('available');
      await wait(20);
      platformEvents.add('available');
      await wait(20);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.online]);
      verifyChecks(client, 2);
    });

    test(
        'restarts monitoring when a listener subscribes after all listeners cancelled',
        () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final platform = MockObjects.platform(platformEvents.stream);
      final sut = buildChecker(client, platform: platform);
      await sut.connectivityStream.listen((_) {}).cancel();

      final emitted = recordEmissions(sut);
      platformEvents.add('lost');
      await wait(10);

      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.offline]);
      verify(() => platform.platformStatusStream).called(2);
      verifyNoChecks(client);
    });

    test('stops periodic checks when the last listener cancels', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(
        client,
        checkFrequency: const Duration(milliseconds: 20),
      );
      final subscription = sut.connectivityStream.listen((_) {});
      await wait(50);

      await subscription.cancel();
      clearInteractions(client);
      await wait(80);

      verifyNoChecks(client);
    });
  });

  group('checkConnectivity', () {
    test('returns and emits online for a 2xx response', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(client);
      final emitted = recordEmissions(sut);

      final result = await sut.checkConnectivity();
      await wait(0);

      expect(result, ConnectivityStatus.online);
      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.online]);
      verifyChecks(client, 1);
    });

    test('returns offline when the status code is 404', () async {
      final client = MockObjects.httpClient([MockObjects.response(404)]);
      final sut = buildChecker(client);

      final result = await sut.checkConnectivity();

      expect(result, ConnectivityStatus.offline);
      verifyChecks(client, 1);
    });

    test('returns offline when the status code is 301', () async {
      final client = MockObjects.httpClient([MockObjects.response(301)]);
      final sut = buildChecker(client);

      final result = await sut.checkConnectivity();

      expect(result, ConnectivityStatus.offline);
      verifyChecks(client, 1);
    });

    test('returns offline when the client throws', () async {
      final client = MockHttpClient();
      when(
        () => client.get(any(), headers: any(named: 'headers')),
      ).thenThrow(Exception('Generic Network Failure'));
      final sut = buildChecker(client);

      final result = await sut.checkConnectivity();

      expect(result, ConnectivityStatus.offline);
      verifyChecks(client, 1);
    });

    test('runs a fresh check for every call, without throttling', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(client);

      final results = await Future.wait([
        sut.checkConnectivity(),
        sut.checkConnectivity(),
        sut.checkConnectivity(),
      ]);

      expect(results, List.filled(3, ConnectivityStatus.online));
      verifyChecks(client, 3);
    });

    test('skips the periodic check that was due right after it', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(
        client,
        checkFrequency: const Duration(milliseconds: 200),
      );
      recordEmissions(sut);
      await wait(120);

      await sut.checkConnectivity();
      await wait(140);

      verifyChecks(client, 1);
    });

    test('runs the next periodic check one full interval after it', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);
      final sut = buildChecker(
        client,
        checkFrequency: const Duration(milliseconds: 200),
      );
      recordEmissions(sut);
      await wait(120);

      await sut.checkConnectivity();
      await wait(260);

      verifyChecks(client, 2);
    });

    test(
        'returns but does not emit a result that a native network change made stale',
        () async {
      final inFlight = Completer<Response>();
      final client = MockObjects.httpClient([inFlight.future]);
      final sut = buildChecker(client);
      final emitted = recordEmissions(sut);
      final pending = sut.checkConnectivity();

      platformEvents.add('lost');
      await wait(10);
      inFlight.complete(Response('', 204));
      final result = await pending;
      await wait(0);

      expect(result, ConnectivityStatus.online);
      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.offline]);
      verifyChecks(client, 1);
    });
  });
}
