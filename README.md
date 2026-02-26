# rx_connectivity_checker

[![Pub Version](https://img.shields.io/pub/v/rx_connectivity_checker.svg)](https://pub.dev/packages/rx_connectivity_checker)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-Android%20|%20iOS%20|%20macOS%20|%20Linux%20|%20Windows%20|%20Web-lightgrey)](#)
[![Pub Points](https://img.shields.io/pub/points/rx_connectivity_checker)](https://pub.dev/packages/rx_connectivity_checker)

A **robust, reactive, and high-performance** federated Flutter library for monitoring network connectivity.

Beyond monitoring local connection states, this library verifies end-to-end internet access through active network probes. Validation is triggered by three distinct events:

- **Platform Change Events** — a probe fires immediately when the system detects a network interface change (e.g. switching from Wi-Fi to Cellular).
- **Periodic Polling** — automated checks run at a configurable interval to catch "silent" losses (e.g. a router losing its uplink while Wi-Fi remains connected).
- **Manual Triggers** — one-off checks can be requested programmatically for critical operations such as a high-priority API submission.

---

## Features

- **Federated Architecture** — native implementations for Android, iOS, macOS, Windows, and Linux.
- **True Reachability** — distinguishes between "connected to a network" and "having internet access."
- **Performance Optimised** — throttled pipeline and single-check-at-a-time concurrency guard prevent redundant probes.
- **Modern Web Support** — WASM-ready using `package:web` and `dart:js_interop` with CORS-safe `no-cors` probes.
- **Energy Efficient** — leverages native system observers (`NWPathMonitor`, `ConnectivityManager`, `DBus`, NLM) to trigger checks only when necessary.
- **Cold Observables** — internal timers and observers only start when the stream has active listeners.
- **Zombie-Connection Detection** — periodic background checks catch cases where a device is locally connected but has no actual internet access.
- **Manual Check Support** — `checkConnectivity()` performs an immediate one-off check and deduplicates against any in-flight periodic check.
- **Testing Friendly** — full dependency injection via `IHttpClient` and `ReachabilityValidator` eliminates the need for real network access in tests.

---

## Installation

Add `rx_connectivity_checker` to your `pubspec.yaml`:

```yaml
dependencies:
  rx_connectivity_checker: ^1.1.0
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

Use `connectivityStream` to rebuild your UI whenever the network state changes. The stream always emits `ConnectivityStatus.unknown` immediately on subscription, followed by the first real result.

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

### Manual one-off checks

For critical actions (like submitting a form), perform an immediate check. If a periodic check is already in flight, this awaits that result rather than firing a duplicate probe.

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
| **Android** | `ConnectivityManager` | Uses `NetworkCallback` for real-time state tracking. |
| **iOS / macOS** | `NWPathMonitor` | Native Swift implementation with event deduplication. |
| **Linux** | D-Bus / `NetworkManager` | Subscribes to `StateChanged` signals on the system bus. |
| **Windows** | `INetworkListManager` | C++ COM interop for high-performance desktop tracking. |
| **Web** | `fetch` API | Uses `no-cors` mode to bypass browser CORS restrictions. |

---

## Platform setup

### Android

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS / macOS

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

Ensure your build environment targets **C++17 or later**.

### Linux

The Linux implementation communicates with `NetworkManager` via D-Bus. Most modern distributions (Ubuntu, Fedora, etc.) ship `NetworkManager` by default — no additional setup is required.

### Web (CORS)

The web implementation uses `mode: no-cors`. This allows the reachability probe to succeed even if the target server does not send CORS headers, because the validator only checks for the presence of a response, not its content.

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

Contributions are welcome. For bugs or feature requests, please file them on the [GitHub Issue Tracker](https://github.com/your-org/rx_connectivity_checker/issues).