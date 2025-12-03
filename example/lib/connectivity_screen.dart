import 'dart:async';

import 'package:basic_connectivity_checker/connectivity_checker.dart';
import 'package:basic_connectivity_checker/connectivity_status.dart';
import 'package:flutter/material.dart';

class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({super.key});

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  // 1. Service and Subscription Management
  late final ConnectivityChecker _checker;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // 2. Local State
  ConnectivityResult _currentStatus = ConnectivityResult.unknown;
  String _log = 'Status: UNKNOWN (Initializing...)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reactive Connectivity Demo'),
        backgroundColor: _getStatusColor(_currentStatus),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildStatusIndicator(),
              const SizedBox(height: 30),
              Text(
                _log,
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Manual Check Now'),
                onPressed: _manualCheck,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Status is also updated automatically every 5 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 4. Crucial Cleanup
    _connectivitySubscription?.cancel();
    // _checker.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeChecker();
  }

  Widget _buildStatusIndicator() {
    return Column(
      children: [
        Icon(
          _getStatusIcon(_currentStatus),
          size: 100,
          color: _getStatusColor(_currentStatus),
        ),
        const SizedBox(height: 10),
        Text(
          _currentStatus.name.toUpperCase(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: _getStatusColor(_currentStatus),
          ),
        ),
      ],
    );
  }

  // --- Helper Functions ---

  Color _getStatusColor(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.online:
        return Colors.green;
      case ConnectivityResult.offline:
        return Colors.red;
      case ConnectivityResult.slow:
        return Colors.orange;
      case ConnectivityResult.unknown:
        return Colors.blueGrey;
    }
  }

  IconData _getStatusIcon(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.online:
        return Icons.wifi;
      case ConnectivityResult.offline:
        return Icons.signal_wifi_off;
      case ConnectivityResult.slow:
        return Icons.network_check;
      case ConnectivityResult.unknown:
        return Icons.help_outline;
    }
  }

  void _initializeChecker() {
    // Configuration: Check every 5 seconds, allow 2 retries (with backoff/jitter)
    _checker = ConnectivityChecker(
      checkFrequency: const Duration(seconds: 5),
      timeout: const Duration(seconds: 5),
      checkSlowConnection: true,
    );

    // 3. Subscribe to the Stream
    _connectivitySubscription = _checker.connectivityStream.listen((result) {
      if (_currentStatus != result) {
        setState(() {
          _currentStatus = result;
          _log =
              '${DateTime.now().second}s: Status changed to ${result.name.toUpperCase()}';
        });
      } else {
        setState(() {
          _log =
              '${DateTime.now().second}s: Status confirmed ${result.name.toUpperCase()}';
        });
      }
    });
  }

  void _manualCheck() async {
    // The result is added to the stream and will update the UI via the listener
    await _checker.checkConnectivity();
    setState(() {
      _log = 'Initiating manual check...';
    });
  }
}
