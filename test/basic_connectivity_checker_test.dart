import 'dart:async';
import 'dart:io';

import 'package:basic_connectivity_checker/basic_connectivity_checker.dart';
import 'package:basic_connectivity_checker/http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  late MockHttpClient mockClient;

  setUp(() {
    mockClient = MockHttpClient();
    registerFallbackValue(Uri());
  });

  /// Helper to mock successful responses
  void mockResponse(int statusCode) {
    final r = MockResponse();
    when(() => r.statusCode).thenReturn(statusCode);
    when(() => mockClient.get(any())).thenAnswer((_) async => r);
  }

  /// Helper to mock errors
  void mockError(Object error) {
    when(() => mockClient.get(any())).thenThrow(error);
  }

  /// Helper to mock timeouts
  void mockTimeout() {
    when(() => mockClient.get(any())).thenThrow(TimeoutException('timeout'));
  }

  BasicConnectivityChecker create({
    bool slow = true,
    Duration freq = const Duration(milliseconds: 15),
    Duration timeout = const Duration(milliseconds: 100),
    BehaviorSubject<ConnectivityResult>? connectivitySubject,
  }) {
    return BasicConnectivityChecker(
      client: mockClient,
      checkSlowConnection: slow,
      checkFrequency: freq,
      timeout: timeout,
      connectivitySubject: connectivitySubject,
    );
  }

  // ---------------------------------------------------------------------------
  // UNIT TESTS: constructor
  // ---------------------------------------------------------------------------
  group('constructor tests', () {
    test(
      'constructor should emit initial unknown before any real checks',
      () async {
        mockResponse(500); // real check returns offline

        final checker = create();
        final stream = checker.connectivityStream;

        expectLater(
          stream,
          emitsInOrder([
            ConnectivityResult.unknown, // startWith
            ConnectivityResult.offline, // initial constructor check
          ]),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
    );
    test(
      'constructor should trigger exactly one automatic initial connectivity check',
      () async {
        final checker = create();
        final stream = checker.connectivityStream;

        // allow constructor async work to finish
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(() => mockClient.get(any())).called(1);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // UNIT TESTS: checkConnectivity()
  // ---------------------------------------------------------------------------
  group('checkConnectivity()', () {
    test('returns ONLINE for 200 OK', () async {
      mockResponse(200);
      final checker = create();

      // Wait for constructor check
      await pumpEventQueue();

      final result = await checker.checkConnectivity();
      expect(result, ConnectivityResult.online);

      verify(() => mockClient.get(any())).called(2);
    });

    test('returns OFFLINE for non-2xx', () async {
      mockResponse(404);
      final checker = create();

      await pumpEventQueue();
      final result = await checker.checkConnectivity();

      expect(result, ConnectivityResult.offline);
    });

    test('returns OFFLINE on SocketException', () async {
      mockError(const SocketException('no net'));
      final checker = create();

      await pumpEventQueue();
      final result = await checker.checkConnectivity();

      expect(result, ConnectivityResult.offline);
    });

    test('returns SLOW on timeout when slow detection enabled', () async {
      mockTimeout();
      final checker = create(slow: true);

      await pumpEventQueue();
      final result = await checker.checkConnectivity();

      expect(result, ConnectivityResult.slow);
    });

    test('returns OFFLINE on timeout when slow detection disabled', () async {
      mockTimeout();
      final checker = create(slow: false);

      await pumpEventQueue();
      final result = await checker.checkConnectivity();

      expect(result, ConnectivityResult.offline);
    });
  });

  // ---------------------------------------------------------------------------
  // STREAM TESTS
  // ---------------------------------------------------------------------------
  group('connectivityStream', () {
    test('emits initial + manual + periodic events', () async {
      // Sequence:
      //  1. constructor check     -> 200
      //  2. first periodic tick   -> 200
      //  3. manual check          -> 400
      //  4. next periodic tick    -> 200

      when(() => mockClient.get(any())).thenAnswer((_) async {
        return http.Response('', 200);
      });

      final checker = create(freq: Duration(milliseconds: 40));

      // Skip initial constructor event
      await pumpEventQueue(times: 3);

      // Now change mock to 400 for the manual check
      final r = MockResponse();
      when(() => r.statusCode).thenReturn(400);
      when(() => mockClient.get(any())).thenAnswer((_) async => r);

      final events = <ConnectivityResult>[];
      final sub = checker.connectivityStream.listen(events.add);

      // Trigger manual
      await checker.checkConnectivity();

      // Switch back to online for the next periodic
      mockResponse(200);

      await Future<void>.delayed(Duration(milliseconds: 80));
      await sub.cancel();

      expect(
        events,
        containsAllInOrder([
          ConnectivityResult.unknown,
          ConnectivityResult.online,
          ConnectivityResult.offline,
          ConnectivityResult.online,
        ]),
      );
    });

    test('stream handles timeout transitions', () async {
      mockResponse(200);
      final checker = create(slow: true);

      // Wait for constructor event
      await pumpEventQueue(times: 2);

      final captured = <ConnectivityResult>[];
      final sub = checker.connectivityStream.listen(captured.add);

      // Timeout occurs on manual check
      mockTimeout();
      await checker.checkConnectivity();

      // Recovery: periodic goes back to online
      mockResponse(200);

      await Future<void>.delayed(Duration(milliseconds: 80));
      await sub.cancel();

      expect(
        captured,
        containsAllInOrder([
          ConnectivityResult.online, // constructor
          ConnectivityResult.online, // first periodic
          ConnectivityResult.slow, // manual
          ConnectivityResult.online, // next periodic
        ]),
      );
    });

    test(
      'manual check should immediately emit its result into the stream',
      () async {
        mockResponse(200);
        final checker = create();

        expectLater(
          checker.connectivityStream,
          emits(ConnectivityResult.online), // result of manual check
        );

        await checker.checkConnectivity();
      },
    );
  });
  // ---------------------------------------------------------------------------
  // UNIT TESTS: _performCheck()
  // ---------------------------------------------------------------------------
  group('_performCheck()', () {
    test('returns OFFLINE for any non-timeout generic exception', () async {
      mockError(FormatException('bad format'));

      final checker = create();
      await pumpEventQueue();

      final result = await checker.checkConnectivity();
      expect(result, ConnectivityResult.offline);
    });

    test(
      'returns OFFLINE when URL is malformed and Uri.parse throws',
      () async {
        final checker = BasicConnectivityChecker(
          url: '%%%',
          // invalid URL
          client: mockClient,
          checkSlowConnection: true,
          checkFrequency: const Duration(milliseconds: 10),
          timeout: const Duration(milliseconds: 50),
        );

        await pumpEventQueue();
        final result = await checker.checkConnectivity();

        expect(result, ConnectivityResult.offline);
      },
    );

    test(
      'timeout with slow=false still returns OFFLINE (pure _performCheck branch)',
      () async {
        mockTimeout();

        final checker = create(slow: false);
        await pumpEventQueue();

        final result = await checker.checkConnectivity();
        expect(result, ConnectivityResult.offline);
      },
    );
  });
}

// -----------------------------------------------------------------------------
// MOCKS
// -----------------------------------------------------------------------------

class MockHttpClient extends Mock implements DefaultHttpClient {}

class MockResponse extends Mock implements http.Response {}
