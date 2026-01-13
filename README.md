# rx_connectivity_checker

[![Pub Version](https://img.shields.io/pub/v/rx_connectivity_checker.svg)](https://pub.dev/packages/rx_connectivity_checker)  
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

A **robust, reactive, and high-performance** federated Flutter library for monitoring network connectivity.

Beyond monitoring local connection states, this library verifies end-to-end internet access through active network probes. To ensure the connectivity status is always accurate, validation is triggered by three distinct events:

- **Platform Change Events**  
  A probe is initiated immediately when the system detects a change in the network interface (e.g., switching from Wi-Fi to Cellular).

- **Periodic Polling**  
  Automated checks occur at a configurable interval to detect “silent” connection losses (e.g., a router losing its uplink while Wi-Fi remains connected).

- **Manual Triggers**  
  One-off validations can be requested programmatically for critical operations, such as before a high-priority API submission.

## Features

- **Federated Architecture**: Native implementations for **Android, iOS, macOS, Windows, and Linux**.
- **True Reachability**: Distinguishes between being "connected to a network" and "having internet access."
- **Performance Optimized**: Minimizes unnecessary network activity and prevents UI instability by avoiding redundant connectivity checks.
- **Modern Web Support**: WASM-ready using `package:web` and `dart:js_interop` with CORS-safe `no-cors` probes.
- **Energy Efficient**: Leverages native system observers (`NWPathMonitor`, `ConnectivityManager`, `DBus`) to trigger checks only when necessary.
- **Cold Observables**: Internal timers and observers only start when the stream has active listeners.
- **Automatic Periodic Monitoring**: Runs background checks to detect “zombie” connections(cases where the device is connected locally but has no actual internet access).
- **Manual Check Support**: Offers a checkConnectivity() method to perform an immediate, one-off connectivity check for critical operations, like high-priority API requests.
- **Testing Friendly**: Supports complete unit testing through dependency injection and configurable reachability strategies, eliminating the need for real network access.
---

## Installation

Add `rx_connectivity_checker` to your `pubspec.yaml`:

```yaml
dependencies:
  rx_connectivity_checker: ^1.0.0
```

Then run:
```shell
flutter pub get
```
## Usage

Initialize the checker with a reliable endpoint. Google's generate_204 is the default as it is fast and lightweight.
```dart
final connectivityChecker = ConnectivityChecker(
  url: '[https://connectivitycheck.gstatic.com/generate_204](https://connectivitycheck.gstatic.com/generate_204)', 
  checkFrequency: const Duration(seconds: 30),
  checkSlowConnection: true, // Maps timeouts to ConnectivityStatus.slow
);
```
## Example

You can find a complete, runnable example in the `example` directory. This example demonstrates:

- Implementing a global connectivity listener
- Handling “Slow Connection” states
- Using manual triggers for form submissions

### To run the example

```bash
cd example
flutter run
````

# Reactive UI Updates

Use the connectivityStream to update your UI automatically when the network state changes.
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
# Manual One-Off Checks
For critical actions (like submitting a form), perform an immediate check:
```dart
final status = await connectivityChecker.checkConnectivity();
if (status == ConnectivityStatus.online) {
  await apiService.uploadData();
}
```
# Platform Support & Mechanisms
The library uses native platform features to provide fast and reliable detection of network connectivity changes:

| Platform | Mechanism | Details |
| :--- | :--- | :--- |
| **Android** | `ConnectivityManager` | Uses `NetworkCallback` for real-time state tracking. |
| **iOS / macOS** | `NWPathMonitor` | Native Swift implementation with event deduplication. |
| **Linux** | `DBus` / `NetworkManager` | Monitors system signals via the D-Bus bus. |
| **Windows** | `INetworkListManager` | C++ COM Interop for high-performance desktop tracking. |
| **Web** | `fetch` API | Uses `no-cors` mode to bypass browser security blocks. |

---
##  Important Notes

### macOS Sandboxing
For macOS apps, you must enable the network entitlement in `DebugProfile.entitlements` and `Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```
### Android Permissions
Ensure your AndroidManifest.xml includes the necessary permissions to monitor network state and access the internet:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```
### Windows Requirements

The Windows implementation relies on COM Interop. While no specific manifest changes are required for standard Win32 apps, ensure your build environment supports C++17 or later. For MSIX/Packaged apps, the internetClient capability must be declared in the Package.appxmanifest.


### Linux Dependencies

The Linux implementation monitors system signals via DBus. Most modern distributions (Ubuntu, Fedora, etc.) have NetworkManager installed by default, which is required for this package to receive real-time interface change events.

### CORS on Web
The web implementation uses mode: no-cors. This allows the reachability probe to succeed even if the target server does not send CORS headers, as the validator only checks for the presence of a response, not the content.
# Contributing
Contributions are welcome! If you encounter issues or have feature requests, please file them on the GitHub Issue Tracker.
