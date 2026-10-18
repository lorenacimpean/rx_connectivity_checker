import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:rx_connectivity_checker/src/validators/native_reachability_validator.dart';
import 'package:rx_connectivity_checker/src/validators/reachability_validator.dart';

import 'helpers/mock_objects.dart';

void main() {
  setUpAll(() => registerFallbackValue(Uri.parse('http://example.com')));

  group('NativeReachabilityValidator.validate', () {
    late NativeReachabilityValidator sut;

    setUp(() => sut = NativeReachabilityValidator());

    Future<ConnectivityStatus> validate(
      MockHttpClient? client, {
      Duration timeout = const Duration(seconds: 1),
      Duration? slowThreshold,
    }) =>
        sut.validate(
          url: 'http://127.0.0.1:1',
          timeout: timeout,
          slowThreshold: slowThreshold,
          client: client,
        );

    test('returns online for a fast 2xx response', () async {
      final client = MockObjects.httpClient([MockObjects.response(204)]);

      final result = await validate(
        client,
        slowThreshold: const Duration(seconds: 1),
      );

      expect(result, ConnectivityStatus.online);
      verifyChecks(client, 1);
    });

    test('returns offline for a non-2xx response', () async {
      final client = MockObjects.httpClient([MockObjects.response(500)]);

      final result = await validate(client);

      expect(result, ConnectivityStatus.offline);
      verifyChecks(client, 1);
    });

    test(
        'returns offline, not slow, when no response arrives within the timeout',
        () async {
      final client = MockObjects.unresponsiveHttpClient();

      final result = await validate(
        client,
        timeout: const Duration(milliseconds: 20),
        slowThreshold: const Duration(milliseconds: 5),
      );

      expect(result, ConnectivityStatus.offline);
      verifyChecks(client, 1);
    });

    test('returns slow for a 2xx response slower than the threshold', () async {
      final client = MockObjects.delayedHttpClient(
        statusCode: 204,
        delay: const Duration(milliseconds: 40),
      );

      final result = await validate(
        client,
        slowThreshold: const Duration(milliseconds: 10),
      );

      expect(result, ConnectivityStatus.slow);
      verifyChecks(client, 1);
    });

    test('returns online for a slow 2xx response when slow detection is off',
        () async {
      final client = MockObjects.delayedHttpClient(
        statusCode: 204,
        delay: const Duration(milliseconds: 40),
      );

      final result = await validate(client);

      expect(result, ConnectivityStatus.online);
      verifyChecks(client, 1);
    });

    test('returns offline when the client throws a SocketException', () async {
      final client = MockHttpClient();
      when(
        () => client.get(any(), headers: any(named: 'headers')),
      ).thenThrow(const SocketException('Network is unreachable'));

      final result = await validate(client);

      expect(result, ConnectivityStatus.offline);
      verifyChecks(client, 1);
    });

    test('falls back to the default client when none is injected', () async {
      final result = await validate(null);

      expect(result, ConnectivityStatus.offline);
    });
  });

  group('statusForReachedServer', () {
    test('returns online when slow detection is off', () {
      final result = statusForReachedServer(
        elapsed: const Duration(seconds: 10),
        slowThreshold: null,
      );

      expect(result, ConnectivityStatus.online);
    });

    test('returns slow when the elapsed time exceeds the threshold', () {
      final result = statusForReachedServer(
        elapsed: const Duration(milliseconds: 301),
        slowThreshold: const Duration(milliseconds: 300),
      );

      expect(result, ConnectivityStatus.slow);
    });

    test('returns online when the elapsed time equals the threshold', () {
      final result = statusForReachedServer(
        elapsed: const Duration(milliseconds: 300),
        slowThreshold: const Duration(milliseconds: 300),
      );

      expect(result, ConnectivityStatus.online);
    });
  });
}
