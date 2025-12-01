import 'dart:async';
import 'dart:io';

import 'package:basic_connectivity_checker/http_client.dart';
import 'package:project_starter_kit/common_utils.dart';
import 'package:rxdart/rxdart.dart';

/// A lightweight, reactive network connectivity checker that periodically
/// verifies whether a given remote endpoint is reachable.
///
/// This utility performs a simple HTTP GET request to the configured [url]
/// at a regular interval defined by [checkFrequency]. Consumers can subscribe
/// to [connectivityStream] to receive real-time connectivity status updates.
///
/// The checker:
/// - Identifies **online** status when the endpoint returns a 2xx HTTP code.
/// - Identifies **offline** status on any error or non-2xx response.
/// - Identifies **slow** status when a request exceeds [timeout] *and*
///   `checkSlowConnection == true`.
///
/// The class emits:
/// - Immediate connectivity status when [checkConnectivity] is invoked.
/// - Automatic periodic updates via an internal timer stream.
///
/// ## Features
/// - URL validation to prevent invalid endpoints.
/// - Optional retry/backoff mechanism for transient failures.
/// - Concurrency control: cancels/ignores overlapping manual checks.
/// - Optional HTTP headers/auth support.
/// - Reactive stream-based API via RxDart.
///
/// ## Usage Example
/// ```dart
/// final checker = BasicConnectivityChecker(
///   url: 'https://example.com',
///   checkFrequency: Duration(seconds: 5),
///   maxRetries: 2,
///   retryDelay: Duration(milliseconds: 500),
///   headers: {'Authorization': 'Bearer ...'},
/// );
///
/// checker.connectivityStream.listen((result) {
///   print('Connectivity: $result');
/// });
/// ```
///
/// ## Notes
/// - This class does **not** automatically dispose of streams; call [dispose]
///   when no longer needed.
/// - Only one URL per instance is supported.
/// - Heavy usage with very short [checkFrequency] may increase network traffic.
/// - Slow network detection depends on [timeout] and retry/backoff configuration.
class BasicConnectivityChecker {
  /// Maximum allowed time for a single connectivity check to complete.
  final Duration timeout;

  /// Interval at which periodic connectivity checks are executed.
  final Duration checkFrequency;

  /// The URL used to verify connectivity.
  final String url;

  /// When `true`, a timed-out request results in [ConnectivityResult.slow].
  final bool checkSlowConnection;

  /// Maximum number of retry attempts for transient failures (timeouts, socket errors).
  final int maxRetries;

  /// Delay between retry attempts for transient failures.
  final Duration retryDelay;

  /// Optional HTTP headers (e.g., for authentication).
  final Map<String, String>? headers;

  /// Internal subject capturing manual and periodic connectivity results.
  final BehaviorSubject<ConnectivityResult> _connectivitySubject;

  /// HTTP client used to execute connectivity checks.
  final DefaultHttpClient _client;

  /// Stream that emits connectivity results from periodic checks.
  /// Begins emitting as soon as the class is instantiated.
  late final Stream<ConnectivityResult> periodicCheckStream;

  /// Tracks the current ongoing manual request to prevent overlapping checks.
  Future<ConnectivityResult>? _currentRequest;

  /// Creates a new [BasicConnectivityChecker].
  ///
  /// - If no [client] is provided, a default HTTP client is used.
  /// - Constructs a periodic stream immediately.
  /// - Executes an initial connectivity check automatically.
  BasicConnectivityChecker({
    this.timeout = const Duration(seconds: 15),
    this.checkFrequency = const Duration(seconds: 10),
    this.url = 'https://www.google.com',
    this.checkSlowConnection = true,
    this.maxRetries = 0,
    this.retryDelay = const Duration(seconds: 1),
    this.headers,
    DefaultHttpClient? client,
    BehaviorSubject<ConnectivityResult>? connectivitySubject,
  }) : _client = client ?? DefaultHttpClient(),
       _connectivitySubject =
           connectivitySubject ?? BehaviorSubject<ConnectivityResult>() {
    _validateUrl();

    // Periodic check stream
    periodicCheckStream = Stream.periodic(
      checkFrequency,
    ).asyncMap((_) => checkConnectivity()).asBroadcastStream();

    // Initial check
    checkConnectivity();
  }

  /// Returns a merged stream combining manual and periodic checks.
  Stream<ConnectivityResult> get connectivityStream =>
      Rx.merge([_connectivitySubject.stream, periodicCheckStream]).map((
        result,
      ) {
        DebugLogger.logData('Result: ', result);
        return result;
      });

  /// Executes a manual connectivity check and emits the result.
  ///
  /// Uses concurrency control to prevent overlapping manual checks.
  Future<ConnectivityResult> checkConnectivity() async {
    if (_currentRequest != null) return _currentRequest!;

    final completer = Completer<ConnectivityResult>();
    _currentRequest = completer.future;

    final result = await _performCheck();
    _connectivitySubject.add(result);

    completer.complete(result);
    _currentRequest = null;

    return result;
  }

  /// Closes internal streams and cleans up resources.
  void dispose() {
    _connectivitySubject.close();
    // periodicCheckStream is derived; no need to close it explicitly
  }

  /// Performs a single HTTP-based connectivity check with retry/backoff.
  ///
  /// ### Behavior:
  /// - Returns **online** for 2xx status codes.
  /// - Returns **offline** for:
  ///   - Non-2xx responses
  ///   - Any exception other than timeout/socket errors
  /// - Returns **slow** if the operation times out and [checkSlowConnection] is true.
  Future<ConnectivityResult> _performCheck() async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await _client
            .get(Uri.parse(url), headers: headers)
            .timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ConnectivityResult.online;
        }
        return ConnectivityResult.offline;
      } on TimeoutException {
        DebugLogger.log('TimeoutException');
        if (checkSlowConnection) return ConnectivityResult.slow;
        if (attempts <= maxRetries) {
          await Future.delayed(retryDelay);
        } else {
          return ConnectivityResult.offline;
        }
      } on SocketException {
        DebugLogger.log('SocketException');
        if (attempts <= maxRetries) {
          await Future.delayed(retryDelay);
        } else {
          return ConnectivityResult.offline;
        }
      } catch (e) {
        DebugLogger.logError('Request failed', e);
        return ConnectivityResult.offline;
      }
    }
  }

  /// Validates the provided URL and throws [ArgumentError] if invalid.
  void _validateUrl() {
    try {
      Uri.parse(url);
    } catch (_) {
      final error = ArgumentError('Invalid URL: $url');
      DebugLogger.logError('Validation error', error);
    }
  }
}

/// Indicates the state of network reachability based on an HTTP request.
enum ConnectivityResult {
  /// The remote endpoint responded with a valid 2xx status code.
  online,

  /// The remote endpoint could not be reached or responded with a non-2xx code.
  offline,

  /// The request timed out, and slow-connection detection is enabled.
  slow,

  /// Unknown or uninitialized state.
  unknown,
}
