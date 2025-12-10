``` dart
// --------------------------------------------------------------------------
// 1. Initialization and Singleton/DI Setup
// --------------------------------------------------------------------------

// The ConnectivityChecker should be a singleton, managed by your DI layer (service/repository + provider).
// It must be initialized once at app startup to avoid duplicated streams and redundant network calls.
final connectivityChecker = ConnectivityChecker(
  // The URL should be a robust, high-availability endpoint that returns a 204 or 200.
  url: 'https://www.google.com/generate_204',
  // Check frequency set lower for demonstration, but typically 30 in production
  checkFrequency: const Duration(seconds: 10),
  // Enable the 'slow' state detection
  checkSlowConnection: true,
  // Max time to wait before classifying as 'slow' or 'offline'
  timeout: const Duration(seconds: 3),
);

class ConnectivityStatusWidget extends StatelessWidget {
  const ConnectivityStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Subscribe to the connectivityStream
    return StreamBuilder<ConnectivityStatus>(
      stream: connectivityChecker.connectivityStream,
      initialData: ConnectivityStatus.unknown,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectivityStatus.unknown;

        // 2. Map the status to UI feedback
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Current Status:',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              _buildStatusIndicator(status),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // 3. Manual check, which also updates the stream
                  connectivityChecker.checkConnectivity();
                },
                child: const Text('Check Now'),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // --- Utility Method for UI Logic ---

  Widget _buildStatusIndicator(ConnectivityStatus status) {
    String text;
    Color color;

    switch (status) {
      case ConnectivityStatus.online:
        text = 'Online';
        color = Colors.green;
        break;
      case ConnectivityStatus.slow:
        text = 'Slow Connection';
        color = Colors.orange;
        break;
      case ConnectivityStatus.offline:
        text = 'Offline';
        color = Colors.red;
        break;
      case ConnectivityStatus.unknown:
        text = 'Checking...';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connectivity Checker Example',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: const ConnectivityScreen(),
    );
  }
}
```