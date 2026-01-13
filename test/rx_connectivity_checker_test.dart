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
}

class MockHttpClient extends Mock implements IHttpClient {}

class MockRxConnectivityCheckerPlatform extends Mock
    implements RxConnectivityCheckerPlatform {}
