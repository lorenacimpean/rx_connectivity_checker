import 'dart:async';

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

    when(
      () => mockPlatform.platformStatusStream,
    ).thenAnswer((_) => const Stream.empty());

    checker = ConnectivityChecker(
      platform: mockPlatform,
      checkSlowConnection: true,
      checkFrequency: const Duration(milliseconds: 20),
      client: mockClient,
    );
  });

  group('ConnectivityChecker - Initialization and Disposal', () {
    test(
      'connectivityStream provides ConnectivityStatus.unknown as the initial value',
      () {
        expect(checker.connectivityStream, emits(ConnectivityStatus.unknown));
      },
    );
  });

  group('ConnectivityChecker - HTTP Response Variations', () {
    test(
      'returns ConnectivityStatus.offline when status code is 404',
      () async {
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => Response('Not Found', 404));

        final result = await checker.checkConnectivity();

        expect(result, ConnectivityStatus.offline);
      },
    );

    test(
      'returns ConnectivityStatus.offline when status code is 301',
      () async {
        // Connectivity is typically validated only on 2xx status codes
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => Response('Redirect', 301));

        final result = await checker.checkConnectivity();

        expect(result, ConnectivityStatus.offline);
      },
    );
  });

  group('ConnectivityChecker - Advanced Error Scenarios', () {
    test(
      'Stream emits unknown state when an unhandled error occurs in the pipeline',
      () async {
        // Re-initialize with a platform that throws an error
        final errorController = StreamController<String>();
        when(
          () => mockPlatform.platformStatusStream,
        ).thenAnswer((_) => errorController.stream);

        checker = ConnectivityChecker(
          platform: mockPlatform,
          client: mockClient,
        );

        final expectation = expectLater(
          checker.connectivityStream,
          emitsInOrder([
            ConnectivityStatus.unknown,
            ConnectivityStatus.unknown, // Emitted by onErrorReturn
          ]),
        );

        errorController.addError(Exception('Critical Platform Error'));

        await expectation;
        await errorController.close();
      },
    );

    test(
      'returns ConnectivityStatus.offline when a generic Exception is thrown during callAPI',
      () async {
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Generic Network Failure'));

        final result = await checker.checkConnectivity();

        expect(result, ConnectivityStatus.offline);
      },
    );
  });

  group('ConnectivityChecker - Throttling and exhaustMap Behavior', () {
    test(
      'Rapid manual triggers within the throttle window result in only one validation call',
      () async {
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => Response('', 200));

        // Trigger multiple calls immediately
        await Future.wait([
          checker.checkConnectivity(),
          checker.checkConnectivity(),
          checker.checkConnectivity(),
        ]);

        // Throttle window prevents subsequent calls from reaching the validator
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );
  });

  group('ConnectivityChecker - Re-checks after a native network change', () {
    late StreamController<String> platformEvents;

    setUp(() {
      platformEvents = StreamController<String>();
      when(
        () => mockPlatform.platformStatusStream,
      ).thenAnswer((_) => platformEvents.stream);
    });

    tearDown(() => platformEvents.close());

    ConnectivityChecker buildChecker(List<Duration> recheckDelays) =>
        ConnectivityChecker(
          platform: mockPlatform,
          client: mockClient,
          checkFrequency: const Duration(hours: 1),
          recheckDelays: recheckDelays,
        );

    void stubResponses(List<Future<Response>> responses) {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) => responses.length > 1 ? responses.removeAt(0) : responses.first,
      );
    }

    test(
      'emits online from a follow-up check when the check fired by the event fails',
      () async {
        final sut = buildChecker(const [Duration(milliseconds: 10)]);
        stubResponses([
          Future.value(Response('', 503)),
          Future.value(Response('', 204)),
        ]);
        final expectation = expectLater(
          sut.connectivityStream,
          emitsInOrder([
            ConnectivityStatus.unknown,
            ConnectivityStatus.offline,
            ConnectivityStatus.online,
          ]),
        );

        platformEvents.add('available');

        await expectation;
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(2);
      },
    );

    test('stops re-checking after the first online result', () async {
      final sut = buildChecker(const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 10),
      ]);
      stubResponses([Future.value(Response('', 204))]);
      final expectation = expectLater(
        sut.connectivityStream,
        emitsInOrder([ConnectivityStatus.unknown, ConnectivityStatus.online]),
      );

      platformEvents.add('available');
      await expectation;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).called(1);
    });

    test(
      'stops after the last follow-up check when the network stays unreachable',
      () async {
        final sut = buildChecker(const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 10),
        ]);
        stubResponses([Future.value(Response('', 503))]);
        final expectation = expectLater(
          sut.connectivityStream,
          emitsInOrder([
            ConnectivityStatus.unknown,
            ConnectivityStatus.offline,
            ConnectivityStatus.offline,
            ConnectivityStatus.offline,
          ]),
        );

        platformEvents.add('lost');
        await expectation;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(3);
      },
    );

    test(
      'performs a single check when no re-check delays are configured',
      () async {
        final sut = buildChecker(const []);
        stubResponses([Future.value(Response('', 503))]);
        final expectation = expectLater(
          sut.connectivityStream,
          emitsInOrder(
              [ConnectivityStatus.unknown, ConnectivityStatus.offline]),
        );

        platformEvents.add('lost');
        await expectation;
        await Future<void>.delayed(const Duration(milliseconds: 30));

        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );

    test(
      'a newer native event cancels the pending follow-up checks of the previous one',
      () async {
        final sut = buildChecker(const [Duration(milliseconds: 100)]);
        stubResponses([Future.value(Response('', 503))]);
        final emitted = <ConnectivityStatus>[];
        final subscription = sut.connectivityStream.listen(emitted.add);

        platformEvents.add('lost');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        platformEvents.add('available');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await subscription.cancel();

        expect(emitted, [
          ConnectivityStatus.unknown,
          ConnectivityStatus.offline,
          ConnectivityStatus.offline,
          ConnectivityStatus.offline,
        ]);
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(3);
      },
    );

    test(
      'a native event during an in-flight check still leads to an online result',
      () async {
        final sut = buildChecker(const [Duration(milliseconds: 10)]);
        final inFlightResponse = Completer<Response>();
        stubResponses([
          inFlightResponse.future,
          Future.value(Response('', 204)),
        ]);
        final expectation = expectLater(
          sut.connectivityStream,
          emitsInOrder([
            ConnectivityStatus.unknown,
            ConnectivityStatus.offline,
            ConnectivityStatus.online,
          ]),
        );

        platformEvents.add('lost');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        platformEvents.add('available');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlightResponse.complete(Response('', 503));

        await expectation;
        verify(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).called(2);
      },
    );
  });
}

class MockHttpClient extends Mock implements IHttpClient {}

class MockRxConnectivityCheckerPlatform extends Mock
    implements RxConnectivityCheckerPlatform {}
