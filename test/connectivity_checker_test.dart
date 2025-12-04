import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:test/test.dart';

void main() {
  late MockHttpClient mockClient;
  late ConnectivityChecker checker;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://example.com'));
  });

  setUp(() {
    mockClient = MockHttpClient();
    // Initialize the checker with the mock client and speed up the frequency for testing
    checker = ConnectivityChecker(
      client: mockClient,
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
        expectLater(
          checker.connectivityStream,
          emitsInOrder([ConnectivityStatus.unknown, ConnectivityStatus.online]),
        );

        // 2. Start a manual check, which blocks the stream via exhaustMap
        final Future<ConnectivityStatus> manualCall = checker
            .checkConnectivity();

        // 3. Wait long enough for the periodic timer (50ms) to fire (it should be ignored by exhaustMap)
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // 4. Complete the single pending request
        completer.complete(Response('', 200));

        // Wait for all futures/streams to complete their processing
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(await manualCall, ConnectivityStatus.online);

        // The HTTP client must only be called once
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

        // 1. Start listening to connectivityStream (starts the periodic timer)
        await expectLater(
          checker.connectivityStream,
          emitsInOrder([ConnectivityStatus.unknown, ConnectivityStatus.online]),
        );

        // VERIFY: HTTP client was called once
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
  });
}

class MockHttpClient extends Mock implements IHttpClient {}
