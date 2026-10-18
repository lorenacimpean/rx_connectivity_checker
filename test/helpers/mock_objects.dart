import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker_platform_interface.dart';

class MockHttpClient extends Mock implements IHttpClient {}

class MockRxConnectivityCheckerPlatform extends Mock
    implements RxConnectivityCheckerPlatform {}

/// Pre-configured mocks shared by the [ConnectivityChecker] tests.
abstract final class MockObjects {
  /// A client answering with [responses] in order, then repeating the last one.
  static MockHttpClient httpClient(List<Future<Response>> responses) {
    final queue = [...responses];
    final client = MockHttpClient();
    when(
      () => client.get(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) => queue.length > 1 ? queue.removeAt(0) : queue.first);
    return client;
  }

  /// A platform whose native events are read from [events].
  static MockRxConnectivityCheckerPlatform platform(Stream<String> events) {
    final platform = MockRxConnectivityCheckerPlatform();
    when(() => platform.platformStatusStream).thenAnswer((_) => events);
    return platform;
  }

  static Future<Response> response(int statusCode) =>
      Future.value(Response('', statusCode));
}

/// Listens to [checker] until the end of the test and returns its emissions.
List<ConnectivityStatus> recordEmissions(ConnectivityChecker checker) {
  final emitted = <ConnectivityStatus>[];
  final subscription = checker.connectivityStream.listen(emitted.add);
  addTearDown(subscription.cancel);
  return emitted;
}

Future<void> wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void verifyChecks(MockHttpClient client, Object count) => verify(
      () => client.get(any(), headers: any(named: 'headers')),
    ).called(count);

void verifyNoChecks(MockHttpClient client) => verifyNever(
      () => client.get(any(), headers: any(named: 'headers')),
    );
