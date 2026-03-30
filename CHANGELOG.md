# Changelog

All notable changes to this project will be documented in this file.

## 1.0.0

### Added

- **Federated Architecture** — transitioned to a federated plugin model, adding native support for macOS, Windows, and Linux.
- **Modern Web Support** — migrated web implementation to use `package:web` and `dart:js_interop` for WASM compatibility.
- **Multi-Trigger System** — added support for platform-native change events, periodic heartbeats, and manual on-demand checks.
- **Platform Behaviour Documentation** — added a platform-behaviour table to the README and `ConnectivityChecker` class doc clearly stating that `checkSlowConnection` is silently ignored on Windows (timeouts always map to `offline` on that platform).
- **Dependency Injection** — `IHttpClient` is now a documented public interface, enabling full unit-test coverage without real network access.
- **MIT License** — updated the project license from Apache 2.0 to MIT.

### Changed

- **Internal Strategy Pattern** — introduced `ReachabilityValidator` abstraction with conditional imports to improve build-time platform resolution and testability.
- **`defaultCheckUrl` is now immutable** — changed from a mutable `static String` to `static const String` in `ConnectivityCheckerConstants` to prevent accidental global mutation by consumers.
- **Windows `platformStatusStream` is now cached** — `WindowsRxConnectivityChecker` now lazily initialises a single broadcast stream (matching the behaviour of `MethodChannelRxConnectivityChecker`) to prevent multiple redundant native channel subscriptions.
- **Linux D-Bus client lifecycle** — `LinuxRxConnectivityChecker` now closes the `DBusClient` socket when the stream is cancelled, preventing file-descriptor leaks on hot-restart or widget disposal.

### Fixed

- **Null-safety crash in `NativeReachabilityValidator`** — replaced the force-unwrap `client!` with a null-coalescing fallback (`client ?? DefaultHttpClient()`). Callers who construct `NativeReachabilityValidator` directly without passing a client no longer receive a `Null check operator used on a null value` crash at runtime.
- **Removed internal `project_starter_kit` dependency** — replaced `DebugLogger` (from a private monorepo package) with `dart:developer`'s `log()` function so the package builds correctly as a standalone pub.dev library.
- **Web validator parameter contract** — `WebReachabilityValidator` now asserts (in debug mode) that `client` and `headers` are null, making the previously silent no-op explicit and discoverable during development.
- Corrected an issue where `throttleTime` was unintentionally tied to the `checkFrequency` interval. This caused manual connectivity checks to be suppressed when triggered shortly after a periodic check, making `checkConnectivity()` appear unresponsive.

---

## 0.3.0

### Added

- Added sample code for the pub.dev example tab.

---

## 0.2.0

### Added

- Added GitHub issue templates.

---

## 0.1.1

### Fixed

- Corrected an issue where `throttleTime` was unintentionally tied to the `checkFrequency` interval. This caused manual connectivity checks to be suppressed when triggered shortly after a periodic check, making `checkConnectivity()` appear unresponsive.

---

## 0.1.0

### Added

- **Initial release** of the `rx_connectivity_checker` package.
- Provides a simple, stream-based API for monitoring real-time network status changes.
- Includes `ConnectivityChecker.connectivityStream` which emits the latest `ConnectivityStatus`.
- Added support for Android and iOS platforms.