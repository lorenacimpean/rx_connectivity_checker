## 1.1.0
### Added
* **Federated Architecture**: Transitioned to a federated plugin model, adding native support for **macOS, Windows, and Linux**.
* **Modern Web Support**: Migrated web implementation to use `package:web` and `dart:js_interop` for WASM compatibility.
* **Multi-Trigger System**: Added Support for platform-native change events, periodic heartbeats, and manual on-demand checks.
* **MIT License**: Updated the project license from Apache 2.0 to MIT.

### Changed
* **Internal Strategy Pattern**: Introduced `ReachabilityValidator` abstraction with conditional imports to improve build-time platform resolution and testability.

### Fixed
* Corrected an issue where `throttleTime` was unintentionally tied to the `checkFrequency` interval.

## 0.3.0

### Added
* Added sample code for pub dev example

## 0.2.0

### Added
* Issue templates

## 0.1.1

### Fixed
* Corrected an issue where `throttleTime` was unintentionally tied to the `checkFrequency` interval.
  This caused manual connectivity checks to be suppressed when triggered shortly after a periodic
  check, making `checkConnectivity()` appear unresponsive.

## 0.1.0

### Added

* **Initial release** of the `rx_connectivity_checker` package.
* Provides a simple, stream-based API for monitoring real-time network status changes.
* Includes `RxConnectivityChecker.connectivityStream` which emits the latest `ConnectivityStatus`.
* Added support for Android and iOS platforms.