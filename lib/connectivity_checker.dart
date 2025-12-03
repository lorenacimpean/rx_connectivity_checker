import 'dart:async';
import 'dart:io';

import 'package:basic_connectivity_checker/connectivity_status.dart';
import 'package:project_starter_kit/common_utils.dart';
import 'package:rxdart/rxdart.dart';

import 'constants.dart';
import 'http_client.dart';

class ConnectivityChecker {
  final Duration timeout;
  final Duration checkFrequency;
  final String _url;
  final bool checkSlowConnection;
  final IHttpClient _client;
  final Map<String, String>? headers;
  late final PublishSubject<bool> _connectivitySubject = PublishSubject();

  ConnectivityChecker({
    this.timeout = const Duration(seconds: 15),
    this.checkFrequency = const Duration(seconds: 10),
    String? url,
    this.checkSlowConnection = false,
    IHttpClient? client,
    this.headers,
  }) : _url = url ?? Constants.defaultCheckUrl,
       _client = client ?? DefaultHttpClient() {
    // 2. Start the trigger loop
    _startPeriodicChecks();
  }

  Stream<ConnectivityResult> get connectivityStream {
    final Stream<bool> periodicStream = Stream.periodic(
      checkFrequency,
      (_) => true,
    );
    final Stream<bool> manualTrigger = _connectivitySubject.stream;

    return Rx.merge([periodicStream, manualTrigger])
        .asyncMap((_) => _performCheck())
        .startWith(ConnectivityResult.unknown)
        .onErrorReturn(ConnectivityResult.offline);
  }

  Future<ConnectivityResult> checkConnectivity() async {
    _connectivitySubject.add(true);
    return _performCheck();
  }

  void dispose() {
    _connectivitySubject.close();
  }

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

  Future<ConnectivityResult> _performCheck() async => await _callAPI();

  void _startPeriodicChecks() => Stream.periodic(
    checkFrequency,
    (count) => count,
  ).asyncMap((_) async => _performCheck());
}
