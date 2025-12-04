# rx_connectivity_checker

[![Pub Version](https://img.shields.io/pub/v/rx_connectivity_checker.svg)](https://pub.dev/packages/rx_connectivity_checker)  
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

A **robust, reactive, and high-performance** Dart/Flutter library for monitoring network
connectivity via **dedicated HTTP health checks**. Built with **RxDart**, it uses **cold observables
** and **multicasting** to minimize resource usage and prevent redundant network calls.

---

## What it does:

`rx_connectivity_checker` helps you monitor network connectivity in real time for Dart and
Flutter apps. You can react to connectivity changes, detect slow connections, and combine immediate
and continuous connectivity checks.

**Who can use it:**  
Any Dart or Flutter developer who needs reliable network status detection.  
**License:** Apache License 2.0 – see the [LICENSE](LICENSE) file for details.

---

## ✨ Features

- **Reactive Monitoring**: Provides a `Stream` (`connectivityStream`) for real-time connectivity
  updates.
- **Performance Optimized**: Uses `shareReplay` and `exhaustMap` to ensure only one active network
  request runs at a time, avoiding redundant calls.
- **Cold Observable**: Network checks only run when the stream is actively subscribed to (e.g.,
  Flutter `StreamBuilder`).
- **Service-Level Checks**: Use `checkConnectivity()` for immediate, non-reactive status in services
  or repositories.
- **Customizable**: Configure check frequency, timeout, URL, and headers.
- **Testable & Mockable**: Built on the `IHttpClient` interface for dependency inversion.

---

## 🚀 Getting Started

### Dependencies

- [`http`](https://pub.dev/packages/http) for HTTP requests
- [`rxdart`](https://pub.dev/packages/rxdart) for reactive stream management

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  rx_connectivity_checker: ^1.0.0
```

```shell
dart pub add rx_connectivity_checker
```

Import in your Dart/Flutter code

```dart
import 'package:rx_connectivity_checker/connectivity_checker.dart';
```

## Initialization

```dart

final connectivityChecker = ConnectivityChecker(
  url: 'https://api.my-service.com/health', // Custom health check endpoint
  checkFrequency: const Duration(seconds: 30), // Periodic check interval
  timeout: const Duration(seconds: 5), // Quick failure detection
  checkSlowConnection: true, // Treat timeouts as 'slow'
);
```

## Environment & SDK Constraints

```yaml
environment:
sdk: ">=3.2.0 <4.0.0"
```

This package requires Dart SDK >=3.2.0 <4.0.0 (as specified in [pubspec.yaml](pubspec.yaml)).

## 📌 Usage

### 1. Reactive UI (Flutter StreamBuilder)

import 'package:flutter/material.dart';
import 'package:rx_connectivity_checker/network_status.dart';

``` dart
import 'package:flutter/material.dart';
import 'package:rx_connectivity_checker/network_status.dart';

StreamBuilder<ConnectivityResult>(
  stream: connectivityChecker.connectivityStream,
  initialData: ConnectivityResult.unknown,
  builder: (context, snapshot) {
    switch (snapshot.data) {
      case ConnectivityResult.online:
        return const Text('🟢 Online!');
      case ConnectivityResult.offline:
        return const Text('🔴 Offline.');
      case ConnectivityResult.slow:
        return const Text('🟡 Slow connection');
      default:
        return Text('Status: ${snapshot.data}');
    }
  },
)

```

### Examples

``` dart
void main() {
final checker = ConnectivityChecker(url: 'https://api.my-service.com/health');

checker.connectivityStream.listen((status) {
print('Current status: $status');
});
}
```

### Immediate Check (Service/Repository Layer)

```dart 
import 'package:rx_connectivity_checker/connectivity_status.dart';

Future<User> fetchUserData(String userId) async {
// 1. Check connectivity immediately
  final status = await connectivityChecker.checkConnectivity();

  if (status != ConnectivityResult.online) {
    throw Exception('Not connected to the internet.');
  }

// 2. Proceed with API call
  return _apiClient.getUser(userId);
}
```

## ℹ️ Notes & Advanced Usage

- Forward Streams: connectivityStream can be forwarded to other streams or state management
  solutions (e.g., Bloc, Riverpod) for centralized connectivity tracking.

- Single Active Request: Ensures only one network check is active at a time, even with multiple
  subscribers.

- Combine Immediate & Continuous Checks: Use checkConnectivity() for instant status alongside
  connectivityStream for reactive updates.

## 🤝 Contributing

- Issues: File any bugs on the GitHub repository's issue tracker.
- Pull Requests: Contributions are welcome! Include clear commit messages and unit tests.
