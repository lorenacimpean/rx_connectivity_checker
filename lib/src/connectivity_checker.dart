import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker_platform_interface.dart';
import 'package:rx_connectivity_checker/src/validators/reachability_validator.dart';
import 'package:rxdart/rxdart.dart';

/// A reactive service that monitors internet connectivity by validating access to a remote URL.
///
/// Status updates come from three sources that share one stream:
///
/// - **Native platform events** — a "network lost" event is reported as
///   [ConnectivityStatus.offline] immediately, without a network request. Any
///   other event (network available or changed) triggers a check right away,
///   followed by quick re-checks ([recheckDelays]) until the network is
///   reachable.
/// - **Periodic checks** every [checkFrequency], paused while the app is hidden
///   (backgrounded or minimised) and resumed with an immediate check when it
///   becomes visible again.
/// - **Manual checks** via [checkConnectivity], which always run a fresh check
///   and restart the periodic timer.
///
/// The stream starts when the first listener subscribes and stops when the
/// last one cancels, so a single instance can back the whole app session or
/// only the screens that need it. New listeners immediately receive the last
/// known status.
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
  static const String _logName = 'RxConnectivityChecker';
  static const String _nativeLostStatus = 'lost';

  /// The maximum duration to wait for a connectivity check response.
  final Duration timeout;

  /// The interval between periodic background connectivity checks.
  final Duration checkFrequency;

  /// The URL used to validate internet access.
  final String _url;

  /// Whether a connection timeout should be reported as [ConnectivityStatus.slow]
  /// instead of [ConnectivityStatus.offline].
  final bool checkSlowConnection;

  /// Delays between follow-up checks after a native network change event.
  ///
  /// A network that has just come up often cannot carry traffic yet (DHCP,
  /// DNS), so the check fired by the change event can fail. Follow-up checks
  /// run after each delay until one reports [ConnectivityStatus.online] or a
  /// newer change event restarts the schedule.
  final List<Duration> recheckDelays;

  final RxConnectivityCheckerPlatform _platform;
  final ReachabilityValidator _validator;
  final IHttpClient? _client;
  final Map<String, String>? headers;

  late final BehaviorSubject<ConnectivityStatus> _status =
      BehaviorSubject.seeded(
    ConnectivityStatus.unknown,
    onListen: _start,
    onCancel: _stop,
  );

  StreamSubscription<String>? _nativeSubscription;
  StreamSubscription<ConnectivityStatus>? _recheckSubscription;
  AppLifecycleListener? _lifecycleListener;
  Timer? _periodicTimer;
  bool _isVisible = true;
  int _networkChangeCount = 0;
  int _checksInFlight = 0;

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
  /// - [recheckDelays]: Delays between follow-up checks after a native network
  ///   change, used until a check reports [ConnectivityStatus.online].
  /// - [client]: An optional HTTP client implementation for dependency injection.
  ConnectivityChecker({
    this.timeout = ConnectivityCheckerConstants.defaultTimeout,
    this.checkFrequency = ConnectivityCheckerConstants.defaultCheckFrequency,
    this.checkSlowConnection = false,
    this.recheckDelays = ConnectivityCheckerConstants.defaultRecheckDelays,
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
  /// Emits only when the status changes. A new listener immediately receives
  /// the last known status ([ConnectivityStatus.unknown] before the first
  /// check completes).
  ///
  /// Monitoring runs while at least one listener is subscribed and restarts
  /// when a listener subscribes again after all previous ones cancelled.
  Stream<ConnectivityStatus> get connectivityStream => _status.stream;

  /// Runs a fresh connectivity check immediately and restarts the periodic timer.
  ///
  /// The check is never throttled and never reuses an older in-flight check.
  /// Its result is returned and, if it differs from the current status and no
  /// network change happened meanwhile, emitted on [connectivityStream].
  Future<ConnectivityStatus> checkConnectivity() {
    dev.log('Manual check triggered', name: _logName);
    _restartPeriodicTimer();
    return _checkAndEmit();
  }

  void _start() {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isVisible = lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed ||
        lifecycleState == AppLifecycleState.inactive;
    _lifecycleListener = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    _nativeSubscription = _platform.platformStatusStream.listen(
      _onNativeStatus,
      onError: _onNativeError,
    );
    _restartPeriodicTimer();
  }

  Future<void> _stop() async {
    final recheckSubscription = _recheckSubscription;
    final nativeSubscription = _nativeSubscription;
    _recheckSubscription = null;
    _nativeSubscription = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    await recheckSubscription?.cancel();
    await nativeSubscription?.cancel();
  }

  void _onHide() {
    dev.log('App hidden, pausing periodic checks', name: _logName);
    _isVisible = false;
    _restartPeriodicTimer();
  }

  void _onShow() {
    dev.log('App visible again, checking', name: _logName);
    _isVisible = true;
    _restartPeriodicTimer();
    _checkAndEmit();
  }

  void _restartPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = _status.hasListener && _isVisible
        ? Timer.periodic(checkFrequency, (_) => _onPeriodicTick())
        : null;
  }

  void _onPeriodicTick() {
    if (_checksInFlight > 0) return;
    dev.log('Periodic check triggered', name: _logName);
    _checkAndEmit();
  }

  void _onNativeStatus(String status) {
    dev.log('Native platform status changed: $status', name: _logName);
    _networkChangeCount++;
    _recheckSubscription?.cancel();
    _recheckSubscription = null;
    if (status == _nativeLostStatus) {
      _emit(ConnectivityStatus.offline);
    } else {
      _recheckSubscription = _checkUntilOnline().listen(_emit);
    }
  }

  void _onNativeError(Object error) {
    dev.log('Native platform stream error: $error', name: _logName);
    _emit(ConnectivityStatus.unknown);
  }

  /// Checks immediately, then once after each of [recheckDelays], stopping at
  /// the first [ConnectivityStatus.online] result.
  Stream<ConnectivityStatus> _checkUntilOnline() =>
      Stream.fromIterable([Duration.zero, ...recheckDelays])
          .asyncExpand(
            (delay) => Rx.timer(null, delay).asyncMap((_) => _check()),
          )
          .takeWhileInclusive((status) => status != ConnectivityStatus.online);

  /// Runs a check and emits its result unless a native network change
  /// happened while it was in flight (its result would be stale).
  Future<ConnectivityStatus> _checkAndEmit() async {
    final networkChangeCount = _networkChangeCount;
    final status = await _check();
    if (networkChangeCount == _networkChangeCount) _emit(status);
    return status;
  }

  Future<ConnectivityStatus> _check() async {
    _checksInFlight++;
    try {
      return await _validator.validate(
        url: _url,
        timeout: timeout,
        checkSlowConnection: checkSlowConnection,
        headers: headers,
        client: _client,
      );
    } finally {
      _checksInFlight--;
    }
  }

  void _emit(ConnectivityStatus status) {
    if (_status.value != status) _status.add(status);
  }
}
