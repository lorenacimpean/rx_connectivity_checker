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

// Instantiate once — treat as a singleton owned by your DI layer.
// Never recreate on hot-reload or widget rebuild.
final connectivityChecker = ConnectivityChecker(
  // High-availability endpoint: returns HTTP 204, no body, minimal overhead.
  url: 'https://www.google.com/generate_204',

  // How often the background timer fires a proactive check.
  // 10 s here for demo; prefer 30 s in production to conserve battery.
  checkFrequency: const Duration(seconds: 10),

  // Emit ConnectivityStatus.slow when a response arrives but exceeds [timeout].
  checkSlowConnection: true,

  // No response within 3 s → ConnectivityStatus.offline.
  // On Windows, route-unreachable errors are also mapped here.
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
      ConnectivityStatus.online  => ('Online',          Colors.green),
      ConnectivityStatus.slow    => ('Slow Connection', Colors.orange),
      ConnectivityStatus.offline => ('Offline',         Colors.red),
      ConnectivityStatus.unknown => ('Checking…',       Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorwithValues(alpha:(0.1),
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

## Usage with `StatefulWidget` (recommended for most apps)

Subscribe in `initState`, cancel in `dispose`:

```dart
class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({super.key});

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  ConnectivityStatus _status = ConnectivityStatus.unknown;
  StreamSubscription<ConnectivityStatus>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = connectivityChecker.connectivityStream.listen((status) {
      setState(() => _status = status);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_status.name);
  }
}
```

---

## Manual check

```dart
// Triggers an immediate check; result is emitted on connectivityStream.
// Useful for a "retry" button or pull-to-refresh.
await connectivityChecker.checkConnectivity();
```

---

## `ConnectivityStatus` values

| Value | Meaning |
|-------|---------|
| `online`  | HTTP 200/204 received within `timeout` |
| `slow`    | Response arrived but exceeded `timeout` (requires `checkSlowConnection: true`) |
| `offline` | Request timed out, DNS failed, or route unreachable |
| `unknown` | Initial state; first check pending |

---

## Platform behaviour

| Platform | Implementation | Notes |
|----------|---------------|-------|
| **Windows** | `INetworkListManagerEvents` (COM / NLM) | Fires on network topology changes. Route-unreachable scenarios (captive portals, VPN drops) are mapped to `offline` via the HTTP timeout. |
| **Android** | `Connectivity` + HTTP validation | Handles metered / VPN networks correctly. |
| **iOS**     | `Connectivity` + HTTP validation | Reachability validated against `url`. |
| **macOS / Linux / Web** | `Connectivity` + HTTP validation | Same HTTP-based path. |

### Windows: timeout-as-offline

The COM channel reports network *topology* changes instantly, but a connected interface does not guarantee internet reachability (e.g. captive portals, corporate proxies). The HTTP validator catches this: if the request to `url` times out, the status is demoted to `offline`. Set `timeout` conservatively (2–4 s) in enterprise environments.

---

## Production checklist

- [ ] Keep a single `ConnectivityChecker` instance (singleton / DI).
- [ ] Set `checkFrequency` ≥ 30 s in production to avoid battery drain.
- [ ] Choose a `url` that returns a minimal response (HTTP 204 is ideal).
- [ ] Tune `timeout` for your target network environment (3–5 s is typical).
- [ ] Cancel the `StreamSubscription` in `dispose()`.
- [ ] Never call `checkConnectivity()` in a tight loop; the stream handles debouncing.

---

## Example app

The `example/` directory contains a showcase app with no extra state-management dependencies — just plain `StatefulWidget`:

```
example/
  lib/
    main.dart                        ← single StatefulWidget owns all state
    ui/
      theme/app_theme.dart           ← colours, glass helpers
      widgets/
        connectivity_halo.dart       ← animated glow orb (CustomPainter + flutter_animate)
        telemetry_card.dart          ← frosted-glass card, platform badge, live dot
```

Run with:

```bash
cd example
flutter run -d windows   # Windows: COM / NLM path
flutter run -d android   # Android: native path
flutter run -d ios       # iOS: native path
```
