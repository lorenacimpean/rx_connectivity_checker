# rx_connectivity_checker

[![Pub Version](https://img.shields.io/pub/v/rx_connectivity_checker.svg)](https://pub.dev/packages/rx_connectivity_checker)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-Android%20|%20iOS%20|%20macOS%20|%20Linux%20|%20Windows%20|%20Web-lightgrey)](#)
[![Pub Points](https://img.shields.io/pub/points/rx_connectivity_checker)](https://pub.dev/packages/rx_connectivity_checker)

A **robust, reactive, and high-performance** federated Flutter library for monitoring network connectivity.

Beyond monitoring local connection states, this library verifies end-to-end internet access through active network probes. Validation is triggered by three distinct events:

- **Platform Change Events** — when the system reports that the network is gone (e.g. Wi-Fi and mobile data turned off), `offline` is emitted instantly, without a probe. When a network becomes available or changes, a probe fires immediately; if it fails, follow-up probes run on a short back-off (250 ms, 500 ms, 1 s, 2 s, 4 s by default, configurable via `recheckDelays`) until the network is reachable — a link that has just come up often cannot carry traffic yet.
- **Periodic Polling** — automated checks run at a configurable interval to catch "silent" losses (e.g. a router losing its uplink while Wi-Fi remains connected). Polling pauses while the app is hidden and resumes with an immediate check when it becomes visible again.
- **Manual Triggers** — `checkConnectivity()` runs a fresh probe right away and restarts the periodic timer.

---

## Features

- **Federated Architecture** — native implementations for Android, iOS, macOS, Windows, and Linux.
- **True Reachability** — distinguishes between "connected to a network" and "having internet access."
- **Performance Optimised** — periodic probes are skipped while another probe is in flight, and results made stale by a newer network change are discarded.
- **Modern Web Support** — WASM-ready using `package:web` and `dart:js_interop` with intelligent CORS-aware probes.
- **Energy Efficient** — leverages native system observers (`NWPathMonitor`, `ConnectivityManager`, `DBus`, NLM) to trigger checks only when necessary.
- **Shared, Restartable Stream** — one checker can back the whole app session or only some screens: monitoring starts with the first listener, stops with the last, restarts when a screen listens again, and new listeners immediately receive the last known status.
- **Zombie-Connection Detection** — periodic background checks catch cases where a device is locally connected but has no actual internet access.
- **Manual Check Support** — `checkConnectivity()` always runs a fresh, unthrottled check and restarts the periodic timer.
- **Testing Friendly** — full dependency injection via `IHttpClient` and `ReachabilityValidator` eliminates the need for real network access in tests.

---

## Installation

Add `rx_connectivity_checker` to your `pubspec.yaml`:

```yaml
dependencies:
  rx_connectivity_checker: ^2.0.0
```

Then run:

```shell
flutter pub get
```

---

## Usage

### Basic setup

Initialise the checker with a reliable endpoint. Google's `generate_204` is the default — it is fast, lightweight, and returns no body.

```dart
final connectivityChecker = ConnectivityChecker(
  url: 'https://connectivitycheck.gstatic.com/generate_204',
  checkFrequency: const Duration(seconds: 30),
  checkSlowConnection: true, // maps timeouts to ConnectivityStatus.slow (see platform notes below)
);
```

### Reactive UI updates

Use `connectivityStream` to rebuild your UI whenever the network state changes. A new listener immediately receives the last known status (`ConnectivityStatus.unknown` before the first check completes); after that the stream emits only when the status changes.

```dart
StreamBuilder<ConnectivityStatus>(
  stream: connectivityChecker.connectivityStream,
  initialData: ConnectivityStatus.unknown,
  builder: (context, snapshot) {
    final status = snapshot.data ?? ConnectivityStatus.unknown;
    return Column(
      children: [
        Icon(
          status == ConnectivityStatus.online ? Icons.wifi : Icons.wifi_off,
          color: status == ConnectivityStatus.online ? Colors.green : Colors.red,
        ),
        Text('Status: ${status.name}'),
      ],
    );
  },
)
```

### Sharing one checker across the app or across screens

Create a single `ConnectivityChecker` (e.g. in your dependency-injection setup) and listen to the same `connectivityStream` wherever you need it:

- **Whole app session** — keep one long-lived listener (e.g. at the app root). Monitoring runs for the entire session, pausing periodic checks while the app is hidden.
- **Only some screens** — listen from those screens only. Monitoring stops when the last screen stops listening and restarts, with the last known status replayed, when another screen listens.

### Manual one-off checks

For critical actions (like submitting a form), perform an immediate check. Every call runs a fresh probe — it never reuses an older in-flight one — and restarts the periodic timer.

```dart
final status = await connectivityChecker.checkConnectivity();
if (status == ConnectivityStatus.online) {
  await apiService.uploadData();
}
```

### Dependency injection (testing)

`ConnectivityChecker` accepts an `IHttpClient` so you can swap in a mock during tests:

```dart
class MockHttpClient implements IHttpClient {
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return http.Response('', 204);
  }
}

final checker = ConnectivityChecker(client: MockHttpClient());
```

---

## ConnectivityStatus

| Value | Meaning |
| :--- | :--- |
| `online` | Remote endpoint responded with a 2xx status code. |
| `offline` | Endpoint unreachable or returned a non-2xx response. |
| `slow` | Request timed out and `checkSlowConnection` is `true` (not available on Windows — see below). |
| `unknown` | Initial state before the first check completes. |

---

## Platform-specific behaviour

> **Important:** platform behaviour differs in one significant way. Read the Windows row carefully if you set `checkSlowConnection: true`.

| Platform | Timeout maps to | `checkSlowConnection` honoured | Native signal source |
| :--- | :--- | :--- | :--- |
| Android | `slow` or `offline` | ✅ Yes | `ConnectivityManager` / `NetworkCallback` |
| iOS / macOS | `slow` or `offline` | ✅ Yes | `NWPathMonitor` |
| Linux | `slow` or `offline` | ✅ Yes | `NetworkManager` via D-Bus |
| **Windows** | **always `offline`** | ❌ No — silently ignored | `INetworkListManager` (NLM COM) |
| Web | `slow` or `offline` | ✅ Yes | `window` `online`/`offline` events |

**Windows rationale:** The Windows networking stack rarely exhibits the degraded "slow" states typical of mobile connections. A request timeout on Windows strongly indicates an offline state or a blocked route. Consequently, `ConnectivityStatus.slow` is never emitted on Windows regardless of the `checkSlowConnection` setting.

**Web limitation:** The web implementation uses the browser's native `fetch()` API. `IHttpClient` injection and custom `headers` are **not supported** on web — passing either has no effect. Use a native platform build if you need header or client injection.

---

## Platform support & native mechanisms

| Platform | Mechanism | Details |
| :--- | :--- | :--- |
| **Android** | `ConnectivityManager` | Follows the system default network via `registerDefaultNetworkCallback`. |
| **iOS / macOS** | `NWPathMonitor` | Native Swift implementation with event deduplication. |
| **Linux** | D-Bus / `NetworkManager` | Subscribes to `StateChanged` signals on the system bus. |
| **Windows** | `INetworkListManager` | C++ COM interop for high-performance desktop tracking. |
| **Web** | `fetch` API | Uses `cors` mode; a CORS rejection is treated as reachable since the server responded. |

---

## Platform setup

### Android

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS / macOS

The plugin supports both **Swift Package Manager** and **CocoaPods** — no extra setup is needed for either. Swift Package Manager integration requires Flutter 3.44 or later; on older Flutter versions keep it disabled and CocoaPods is used.

No additional permissions are required for iOS.

For macOS, enable the network client entitlement in both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Windows

The Windows implementation uses COM interop. No manifest changes are required for standard Win32 apps. For MSIX / packaged apps, declare the `internetClient` capability in `Package.appxmanifest`:

```xml
<Capability Name="internetClient" />
```

Ensure your build environment targets **C++20 or later** (required by the plugin's CMakeLists.txt).

### Linux

The Linux implementation communicates with `NetworkManager` via D-Bus. Most modern distributions (Ubuntu, Fedora, etc.) ship `NetworkManager` by default — no additional setup is required.

### Web (CORS)

The web implementation uses `mode: cors`. If the fetch succeeds the endpoint is reachable. If the server responds with a CORS rejection (e.g. `TypeError`), the browser still contacted the server — the validator treats this as `online`. A true network failure (DNS error, no route) sets `navigator.onLine` to `false` and is correctly reported as `offline`.

---

## Example

A complete, runnable example is in the `example/` directory. It demonstrates:

- implementing a global connectivity listener
- handling `ConnectivityStatus.slow` states
- using manual triggers before form submissions

```bash
cd example
flutter run
```

---

## Contributing

Contributions are welcome. For bugs or feature requests, please file them on the [GitHub Issue Tracker](https://github.com/lorenacimpean/rx_connectivity_checker/issues).