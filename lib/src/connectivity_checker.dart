import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker_platform_interface.dart';
import 'package:rx_connectivity_checker/src/validators/reachability_validator.dart';
import 'package:rxdart/rxdart.dart';

/// A reactive service that monitors internet connectivity by validating access to a remote URL.
///
/// This service combines periodic polling, native platform updates, and manual triggers
/// to provide a robust stream of [ConnectivityStatus] updates. It employs throttling
/// and request concurrency control to minimize resource usage.
///
/// ## Platform-specific behaviour
///
/// | Platform        | Timeout maps to              | [checkSlowConnection] honoured | Native signal source          |
/// |-----------------|------------------------------|-------------------------------|-------------------------------|
/// | Android / iOS   | `slow` or `offline`          | Yes                           | ConnectivityManager           |
/// | **Windows**     | **always `offline`**         | **No — silently ignored**     | NLM (EventChannel)            |
/// | Linux           | `slow` or `offline`          | Yes                           | NetworkManager / D-Bus        |
/// | Web             | `slow` or `offline`          | Yes                           | `window` online/offline events|
///
/// > **Windows note:** The Windows networking stack rarely exhibits the degraded
/// > "slow" states typical of mobile connections. A request timeout on Windows
/// > strongly indicates an offline state or a blocked route. As a result,
/// > [ConnectivityStatus.slow] is never returned on Windows regardless of the
/// > value of [checkSlowConnection].
class ConnectivityChecker {
  /// The maximum duration to wait for a connectivity check response.
  final Duration timeout;

  /// The interval between periodic background connectivity checks.
  final Duration checkFrequency;

  /// The URL used to validate internet access.
  final String _url;

  /// Whether a connection timeout should be reported as [ConnectivityStatus.slow]
  /// instead of [ConnectivityStatus.offline].
  final bool checkSlowConnection;

  final RxConnectivityCheckerPlatform _platform;
  final ReachabilityValidator _validator;
  final IHttpClient? _client;
  final Map<String, String>? headers;

  // A dedicated subject for manual check triggers.
  late final PublishSubject<bool> _manualCheckTrigger = PublishSubject();

  // Internal multicasting stream.
  late final Stream<ConnectivityStatus> _internalStream =
      _buildStream().shareReplay(maxSize: 1);

  Future<ConnectivityStatus>? _pendingCheckFuture;

  /// Creates a [ConnectivityChecker] instance.
  ///
  /// - [timeout]: The maximum time to wait for the connectivity check request response.
  /// - [checkFrequency]: The interval at which the background check should occur.
  /// - [url]: The URL used for the connectivity check (defaults to a reliable external source).
  /// - [checkSlowConnection]: If true, a [TimeoutException] is mapped to
  ///   [ConnectivityStatus.slow]. Otherwise, it is mapped to [ConnectivityStatus.offline].
  ///   **Note:** This flag has no effect on Windows — timeouts always map to
  ///   [ConnectivityStatus.offline] on that platform. See the class-level docs
  ///   for the full platform-behaviour table.
  /// - [client]: An optional HTTP client implementation for dependency injection.
  ConnectivityChecker({
    this.timeout = ConnectivityCheckerConstants.defaultTimeout,
    this.checkFrequency = ConnectivityCheckerConstants.defaultCheckFrequency,
    this.checkSlowConnection = false,
    this.headers,
    String? url,
    RxConnectivityCheckerPlatform? platform,
    IHttpClient? client,
  })  : _url = url ?? ConnectivityCheckerConstants.defaultCheckUrl,
        _platform = platform ?? RxConnectivityCheckerPlatform.instance,
        _client = client ?? (kIsWeb ? null : DefaultHttpClient()),
        _validator = ReachabilityValidator();

  /// A shared stream of [ConnectivityStatus] updates.
  ///
  /// This stream is **cold** (starts polling only on subscription) and **multicast**
  /// (shares a single subscription source among multiple listeners).
  ///
  /// Emits [ConnectivityStatus.unknown] immediately upon subscription, followed
  /// by the actual status.
  Stream<ConnectivityStatus> get connectivityStream => _internalStream;

  /// triggers an immediate connectivity check and updates [connectivityStream].
  ///
  /// Returns a [Future] that completes with the result of the check.
  ///
  /// If a check (periodic or manual) is already in progress, this method awaits
  /// the existing check rather than starting a new one.
  Future<ConnectivityStatus> checkConnectivity() async {
    _manualCheckTrigger.add(true);
    return _performCheck();
  }

  /// Composes the connectivity monitoring pipeline.
  ///
  /// Merges periodic timers, manual triggers, and native platform events into
  /// a single stream that performs actual network validation.
  Stream<ConnectivityStatus> _buildStream() {
    final periodicStream = Stream.periodic(checkFrequency, (_) {
      dev.log('Periodic check triggered', name: 'RxConnectivityChecker');
      return true;
    });

    final nativeStream = _platform.platformStatusStream.map((status) {
      dev.log('Native platform status changed: $status',
          name: 'RxConnectivityChecker');
      return true;
    });

    final manualStream = _manualCheckTrigger.stream.map((_) {
      dev.log('Manual check triggered', name: 'RxConnectivityChecker');
      return true;
    });

    return Rx.merge([periodicStream, manualStream, nativeStream])
        .throttleTime(ConnectivityCheckerConstants.defaultThrottleTime)
        .exhaustMap((_) => Stream.fromFuture(_performCheck()))
        .onErrorReturn(ConnectivityStatus.unknown)
        .startWith(ConnectivityStatus.unknown);
  }

  /// Executes the network validation logic, ensuring only one check runs at a time.
  Future<ConnectivityStatus> _performCheck() async {
    if (_pendingCheckFuture != null) {
      return _pendingCheckFuture!;
    }

    final future = _validator.validate(
      url: _url,
      timeout: timeout,
      checkSlowConnection: checkSlowConnection,
      headers: headers,
      client: _client,
    );
    _pendingCheckFuture = future;

    try {
      return await future;
    } finally {
      _pendingCheckFuture = null;
    }
  }
}
