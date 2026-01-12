import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker_platform_interface.dart';

void main() {
  late MockHttpClient mockClient;
  late MockRxConnectivityCheckerPlatform mockPlatform;
  late ConnectivityChecker checker;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(Uri.parse('http://example.com'));
  });

  setUp(() {
    mockClient = MockHttpClient();
    mockPlatform = MockRxConnectivityCheckerPlatform();

    // 2. Default Stub: Ensure platform stream is empty by default so it doesn't interfere with basic tests
    when(
      () => mockPlatform.platformStatusStream,
    ).thenAnswer((_) => const Stream.empty());

    // 3. Initialize with dependencies
    checker = ConnectivityChecker(
      client: mockClient,
      platform: mockPlatform, // Injected the mock platform
      checkSlowConnection: true,
      checkFrequency: const Duration(milliseconds: 20),
    );
  });

  // --- POSITIVE SCENARIOS (Happy Path) ---

  group('ConnectivityChecker - Positive Scenarios', () {
    test(
      'checkConnectivity returns online on successful 200 response (AAA)',
      () async {
        // Arrange
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => Response('', 200));

        // Act
        final result = await checker.checkConnectivity();

        // Assert
        expect(result, ConnectivityStatus.online);
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );

    test(
      'connectivityStream emits unknown then online on successful manual check',
      () async {
        // Arrange
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => Response('', 200));

        // Assert
        expect(
          checker.connectivityStream,
          emitsInOrder([ConnectivityStatus.unknown, ConnectivityStatus.online]),
        );

        // Manually trigger the first check for the stream to update its state
        await checker.checkConnectivity();

        // VERIFY: HTTP client was called
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );
  });

  // --- NEGATIVE SCENARIOS (Error Handling) ---

  group('ConnectivityChecker - Negative Scenarios', () {
    test('checkConnectivity returns offline on 500 status code', () async {
      // Arrange
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => Response('Server Error', 500));

      // Act
      final result = await checker.checkConnectivity();

      // Assert
      expect(result, ConnectivityStatus.offline);
      expect(
        checker.connectivityStream,
        emitsInOrder([ConnectivityStatus.unknown, ConnectivityStatus.offline]),
      );

      // VERIFY: HTTP client was called once
      verify(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).called(1);
    });

    test(
      'checkConnectivity returns offline on SocketException (no internet)',
      () async {
        // Arrange
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(const SocketException('No Internet'));

        // Act
        final result = await checker.checkConnectivity();

        // Assert
        expect(result, ConnectivityStatus.offline);

        // VERIFY: HTTP client was called once
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );

    test(
      'checkConnectivity returns slow when checkSlowConnection is true and timeout occurs',
      () async {
        // Arrange
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(TimeoutException('Request timed out'));

        // Act
        final result = await checker.checkConnectivity();

        // Assert
        expect(result, ConnectivityStatus.slow);

        // VERIFY: HTTP client was called once
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );

    test(
      'checkConnectivity returns offline when checkSlowConnection is false and timeout occurs',
      () async {
        // Arrange
        final offlineChecker = ConnectivityChecker(
          client: mockClient,
          platform: mockPlatform, // Injected mock
          checkSlowConnection: false, // Override the default true setup
        );
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(TimeoutException('Request timed out'));

        // Act
        final result = await offlineChecker.checkConnectivity();

        // Assert
        expect(result, ConnectivityStatus.offline);

        // VERIFY: HTTP client was called once
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );
  });

  // --- CONCURRENCY & STREAM EDGE CASES (exhaustMap/Multicasting) ---

  group('ConnectivityChecker - Concurrency & Stream Behavior', () {
    test(
      'Concurrent checkConnectivity calls result in only one HTTP request',
      () async {
        // Arrange
        final completer = Completer<Response>();
        // Mock returns a future that is not completed yet
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) => completer.future);

        // Act
        // Fire three calls simultaneously
        final Future<ConnectivityStatus> call1 = checker.checkConnectivity();
        final Future<ConnectivityStatus> call2 = checker.checkConnectivity();
        final Future<ConnectivityStatus> call3 = checker.checkConnectivity();

        // Complete the single pending request
        completer.complete(Response('', 200));

        // Assert
        final results = await Future.wait([call1, call2, call3]);

        // All results must be online, proving they all waited for the single successful call
        expect(results, everyElement(ConnectivityStatus.online));

        // CRITICAL ASSERTION: The HTTP client must only be called once
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );

    test(
      'Periodic check is ignored while manual check is running (exhaustMap)',
      () async {
        // Arrange
        final completer = Completer<Response>();
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) => completer.future);

        // Act
        // 1. Start listening to connectivityStream (starts the periodic timer)
        final expectation = expectLater(
          checker.connectivityStream,
          emitsInOrder([ConnectivityStatus.unknown, ConnectivityStatus.online]),
        );

        // 2. Start a manual check, which blocks the stream via exhaustMap
        final Future<ConnectivityStatus> manualCall = checker
            .checkConnectivity();

        // 3. Wait long enough for the periodic timer (20ms) to fire (it should be ignored by exhaustMap)
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // 4. Complete the single pending request
        completer.complete(Response('', 200));

        await expectation;

        // Assert
        expect(await manualCall, ConnectivityStatus.online);

        // CRITICAL ASSERTION: The HTTP client must only be called once
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );

    test(
      'Subsequent listeners receive the cached state immediately (shareReplay)',
      () async {
        // Arrange
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => Response('', 200));

        // 1. Start listening to connectivityStream
        await expectLater(
          checker.connectivityStream,
          emitsInOrder([ConnectivityStatus.unknown, ConnectivityStatus.online]),
        );

        // 2. Add a new listener immediately
        // It should receive the *last* emitted value (online) without triggering a new call
        await expectLater(
          checker.connectivityStream,
          emits(ConnectivityStatus.online),
        );

        // VERIFY: HTTP client was called only once (from the first listener)
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );
  });

  // --- NEW: PLATFORM INTEGRATION TESTS ---

  group('ConnectivityChecker - Platform Integration', () {
    test(
      'Emitting an event on platformStatusStream triggers a connectivity check',
      () async {
        // Arrange
        final platformController = StreamController<String>();

        // Re-stub the platform stream to return our controller
        when(
          () => mockPlatform.platformStatusStream,
        ).thenAnswer((_) => platformController.stream);

        // Re-initialize checker to pick up the new stub
        checker = ConnectivityChecker(
          client: mockClient,
          platform: mockPlatform,
          checkSlowConnection: true,
          checkFrequency: const Duration(
            seconds: 100,
          ), // Long delay to ensure only platform triggers it
        );

        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => Response('', 200));

        // Act
        final expectation = expectLater(
          checker.connectivityStream,
          emitsInOrder([ConnectivityStatus.unknown, ConnectivityStatus.online]),
        );

        // Emit an event from the "native" platform
        platformController.add('network_changed_event');

        // Assert
        await expectation;
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);

        await platformController.close();
      },
    );
  });
}

// 1. Define Mocks
class MockHttpClient extends Mock implements IHttpClient {}

class MockRxConnectivityCheckerPlatform extends Mock
    implements RxConnectivityCheckerPlatform {}
