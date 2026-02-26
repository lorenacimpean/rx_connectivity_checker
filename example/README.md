# rx_connectivity_checker

A reactive, production-ready Flutter connectivity checker that supports **Windows (COM / NLM)**, **Android**, and **iOS** with a unified `ConnectivityStatus` stream.

---

## Installation

```yaml
dependencies:
  rx_connectivity_checker: ^<latest>
```

---

## Quick Start

```dart
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';

// Instantiate once — treat it as a singleton owned by your DI layer.
// Never recreate it on hot-reload or widget rebuild.
final connectivityChecker = ConnectivityChecker(
  // High-availability endpoint: returns HTTP 204, no body, minimal overhead.
  url: 'https://www.google.com/generate_204',

  // How often the background timer fires a proactive check.
  // 10 s in this example; prefer 30 s in production to conserve battery.
  checkFrequency: const Duration(seconds: 10),

  // Emit ConnectivityStatus.slow when a response arrives but exceeds [timeout].
  checkSlowConnection: true,

  // If no response within 3 s → ConnectivityStatus.offline (or .slow if partial).
  // On Windows, route-unreachable errors are also mapped to offline here.
  timeout: const Duration(seconds: 3),
);
```

---

## Usage with `StreamBuilder`

```dart
class ConnectivityStatusWidget extends StatelessWidget {
  const ConnectivityStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityStatus>(
      stream: connectivityChecker.connectivityStream,
      initialData: ConnectivityStatus.unknown,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectivityStatus.unknown;
        return _buildStatusIndicator(status);
      },
    );
  }

  Widget _buildStatusIndicator(ConnectivityStatus status) {
    final (text, color) = switch (status) {
      ConnectivityStatus.online  => ('Online',           Colors.green),
      ConnectivityStatus.slow    => ('Slow Connection',  Colors.orange),
      ConnectivityStatus.offline => ('Offline',          Colors.red),
      ConnectivityStatus.unknown => ('Checking…',        Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
      ),
    );
  }
}
```

---

## Usage with Riverpod 3.x (recommended)

Wire the checker into your dependency graph once using a `Provider` and consume it everywhere via `StreamProvider`:

```dart
// core/connectivity_service.dart
class ConnectivityService {
  ConnectivityService._()
      : _checker = ConnectivityChecker(
          url: 'https://www.google.com/generate_204',
          checkFrequency: const Duration(seconds: 10),
          checkSlowConnection: true,
          timeout: const Duration(seconds: 3),
        );

  static final ConnectivityService instance = ConnectivityService._();
  final ConnectivityChecker _checker;

  Stream<ConnectivityStatus> get statusStream => _checker.connectivityStream;
}

// core/connectivity_provider.dart
final connectivityServiceProvider = Provider<ConnectivityService>(
  (_) => ConnectivityService.instance,
);

final connectivityStatusProvider = StreamProvider<ConnectivityStatus>(
  (ref) => ref.watch(connectivityServiceProvider).statusStream,
);
```

```dart
// In any ConsumerWidget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityStatusProvider).valueOrNull
                ?? ConnectivityStatus.unknown;
    return Text(status.name);
  }
}
```

---

## Manual check

```dart
// Triggers an immediate check; result is emitted on connectivityStream.
// Useful for "pull to refresh" or a manual retry button.
await connectivityChecker.checkConnectivity();
```

---

## Platform behaviour

| Platform | Implementation | Notes |
|----------|---------------|-------|
| **Windows** | `INetworkListManagerEvents` (COM / NLM) | Fires on network topology changes. Route-unreachable scenarios (captive portals, VPN drops) are mapped to `offline` via the HTTP timeout. |
| **Android** | `connectivity_plus` + HTTP validation | Handles metered / VPN networks correctly. |
| **iOS** | `connectivity_plus` + HTTP validation | Reachability validated against `url`. |
| **macOS / Linux / Web** | `connectivity_plus` + HTTP validation | Same HTTP-based path. |

### Windows-specific: timeout-as-offline

On Windows, the COM channel reports network *topology* changes instantly.
However a connected interface does not guarantee internet reachability
(e.g. captive portals, corporate proxies). The HTTP validator catches this:
if the request to `url` times out, the status is demoted to `offline`.
Set `timeout` conservatively (2–4 s) in enterprise environments.

---

## `ConnectivityStatus` values

| Value | Meaning |
|-------|---------|
| `online` | HTTP 200/204 received within `timeout` |
| `slow` | HTTP response arrived but exceeded `timeout` (only when `checkSlowConnection: true`) |
| `offline` | Request timed out, DNS failed, or route unreachable |
| `unknown` | Initial state; first check pending |

---

## Production checklist

- [ ] Use a single `ConnectivityChecker` instance (singleton / DI).
- [ ] Set `checkFrequency` ≥ 30 s in production to avoid battery drain.
- [ ] Choose a `url` that returns a minimal response (HTTP 204 is ideal).
- [ ] Tune `timeout` for your target network environment (3–5 s is typical).
- [ ] Subscribe to `connectivityStream` and cancel the subscription in `dispose()`.
- [ ] Never call `checkConnectivity()` in a tight loop; the stream handles debouncing.

---

## Example app

The `example/` directory contains a production-grade showcase app using:

- **Riverpod 3.0** state management with a clean `Provider → StreamProvider` architecture
- **Glassmorphism UI** with `flutter_animate` transitions
- A **live connectivity halo** that pulses green / amber / red based on status
- A **network telemetry card** showing platform, validator endpoint, latency, and last event
- A **platform badge** that identifies the active implementation (Windows COM/NLM vs mobile native)
- **Two reachability test buttons**: standard and tight-timeout (500 ms) to demonstrate the Windows route-unreachable → offline mapping

Run with:

```bash
cd example
flutter run -d windows   # Windows: COM / NLM path
flutter run -d android   # Android: native path
flutter run -d ios       # iOS: native path
```
