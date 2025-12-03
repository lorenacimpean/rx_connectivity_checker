import 'dart:async';
import 'dart:io';

import 'package:basic_connectivity_checker/basic_connectivity_checker.dart';
import 'package:project_starter_kit/common_utils.dart';
import 'package:rxdart/rxdart.dart';

/// A robust, reactive service that continuously checks network connectivity
/// by attempting to access a specific URL.
///
/// This service provides two methods for checking connectivity: a primary
/// [connectivityStream] for reactive state management, and a [checkConnectivity]
/// method for one-off checks.
///
/// The service uses internal throttling and multicasting (`shareReplay`)
/// to ensure only one network request is active at any time, preventing
/// resource waste and redundant calls.
class ConnectivityChecker {
  final Duration timeout;
  final Duration checkFrequency;
  final String _url;
  final bool checkSlowConnection;
  final IHttpClient _client;
  final Map<String, String>? headers;

  // A dedicated subject for manual check triggers.
  late final PublishSubject<bool> _manualCheckTrigger = PublishSubject();

  // The single, cold, multicasting source of truth.
  // This stream only starts its periodic checks when the first listener subscribes.
  late final Stream<ConnectivityResult> _internalStream = _buildStream()
      //  Must be last for multicasting to work.
      .shareReplay(maxSize: 1);
  Future<ConnectivityResult>? _pendingCheckFuture;

  /// Creates a [ConnectivityChecker] instance.
  ///
  /// - [timeout]: The maximum time to wait for the connectivity check request.
  /// - [checkFrequency]: The interval at which the background check should occur.
  /// - [url]: The URL used for the connectivity check (defaults to a reliable external source).
  /// - [checkSlowConnection]: If true, a [TimeoutException] is mapped to
  ///   [ConnectivityResult.slow]. Otherwise, it is mapped to [ConnectivityResult.offline].
  /// - [client]: An optional HTTP client implementation for dependency injection.
  ConnectivityChecker({
    this.timeout = ConnectivityCheckerConstants.defaultTimeout,
    this.checkFrequency = ConnectivityCheckerConstants.defaultCheckFrequency,
    String? url,
    this.checkSlowConnection = false,
    IHttpClient? client,
    this.headers,
  }) : _url = url ?? ConnectivityCheckerConstants.defaultCheckUrl,
       _client = client ?? DefaultHttpClient();

  /// A cold, multicasting stream that emits the current [ConnectivityResult].
  ///
  /// The stream is **cold** (network checks only run when subscribed) and
  /// **multicasting** (the expensive periodic check runs only once, sharing
  /// results with all listeners).
  ///
  /// The stream provides an immediate result of [ConnectivityResult.unknown]
  /// upon subscription, followed by the actual state. It only emits a new value
  /// when the connectivity status changes.
  Stream<ConnectivityResult> get connectivityStream => _internalStream;

  /// Performs a manual, one-off connectivity check and updates the
  /// [connectivityStream] for all listeners.
  ///
  /// This method is gated by internal concurrency control: if a check is already
  /// running (periodic or manual), it will wait for the current check's result
  /// instead of starting a new network request.
  ///
  /// Returns the immediate result of the connectivity check.
  Future<ConnectivityResult> checkConnectivity() async {
    // Triggers the stream and returns the result of the immediate check.
    _manualCheckTrigger.add(true);
    return _performCheck();
  }

  // Private method to define the entire, complex stream pipeline.
  Stream<ConnectivityResult> _buildStream() {
    // 1. Periodic Stream (Cold Trigger)
    final periodicStream = Stream.periodic(checkFrequency, (_) => true);

    // 2. Merge all triggers (Periodic + Manual)
    return Rx.merge([periodicStream, _manualCheckTrigger.stream])
        // Prevents rapid fire from manual calls and periodic ticks
        .throttleTime(checkFrequency)
        // CRITICAL: Ensures only one network request is active at a time.
        .exhaustMap((_) => Stream.fromFuture(_performCheck()))
        // Provides immediate initial state
        .startWith(ConnectivityResult.unknown)
        // Maps errors to a connectivity result
        .onErrorReturn(ConnectivityResult.unknown);
  }

  // Executes the actual HTTP check against the configured URL.
  Future<ConnectivityResult> _callAPI() async {
    try {
      final response = await _client
          .get(Uri.parse(_url), headers: headers)
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ConnectivityResult.online;
      }
      return ConnectivityResult.offline;
    } on TimeoutException {
      return checkSlowConnection
          ? ConnectivityResult.slow
          : ConnectivityResult.offline;
    } on SocketException {
      return ConnectivityResult.offline;
    } catch (e) {
      DebugLogger.logError('Request failed permanently', e);
      return ConnectivityResult.offline;
    }
  }

  /// Executes the underlying network connectivity check ([_callAPI]), acting as
  /// a **Concurrency Gate** to prevent duplicate API calls.
  ///
  /// This method implements the **Check-Then-Act** pattern using the private
  /// [_pendingCheckFuture] lock.
  ///
  /// If multiple threads or stream events trigger this method simultaneously:
  /// 1. The first call executes [_callAPI()] and sets [_pendingCheckFuture].
  /// 2. Subsequent concurrent calls immediately return the stored [_pendingCheckFuture],
  ///    ensuring only one active network request is ever launched at a time.
  ///
  /// Once the internal API call completes (either successfully or with an error),
  /// the [_pendingCheckFuture] lock is released in the `finally` block, allowing
  /// subsequent checks to proceed.
  Future<ConnectivityResult> _performCheck() async {
    // 1. If a check is already running, return the existing Future.
    if (_pendingCheckFuture != null) {
      return _pendingCheckFuture!;
    }

    // 2. Initiate a new check and store the future.
    final future = _callAPI();
    _pendingCheckFuture = future;

    try {
      // 3. Wait for the API call to complete.
      final result = await future;
      return result;
    } finally {
      // 4. Release the lock when the Future completes (success or failure).
      _pendingCheckFuture = null;
    }
  }
}
