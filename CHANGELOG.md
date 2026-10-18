# Changelog

All notable changes to this project will be documented in this file.

## 2.0.0

### Breaking changes

- **Requires Flutter 3.44 or later.** Needed for Android Gradle Plugin 9 with built-in Kotlin (see "Changed") and for Swift Package Manager.
- **`connectivityStream` emits only when the status changes**, except for `checkConnectivity()` results, which are always emitted. Repeated identical results (e.g. `online` from every periodic check) are no longer re-emitted. A new listener immediately receives the last known status instead of always starting from `unknown`.
- **`checkConnectivity()` always runs a fresh check.** It is no longer throttled and no longer returns the result of an older in-flight check; it also restarts the periodic timer.
- **`slow` now means a slow successful response, and a timeout is always `offline`.** Previously, with `checkSlowConnection` enabled, a request that never got a response was reported as `slow` (except on Windows). Now a 2xx response slower than `slowConnectionThreshold` is `slow`, and no response within `timeout` is `offline` on every platform.
- **A native "network lost" event emits `offline` immediately**, without an HTTP probe.
- **Periodic checks pause while the app is hidden** (backgrounded or minimised) and resume with an immediate check when it becomes visible again.
- `ConnectivityCheckerConstants.defaultThrottleTime` is deprecated and unused.

### Added

- **Swift Package Manager support** — the iOS and macOS implementations now ship a `Package.swift`, removing the "does not have Swift Package Manager support" warning. CocoaPods remains fully supported.
- **`recheckDelays`** — new optional `ConnectivityChecker` parameter controlling the follow-up checks after a native network change (default: 250 ms, 500 ms, 1 s, 2 s, 4 s).
- **`offlineCheckFrequency`** — interval between periodic checks while not online (default: 5 s); `checkFrequency` now applies while online.
- **`slowConnectionThreshold`** — response time above which a successful check is `slow` when `checkSlowConnection` is enabled (default: 3 s).

### Fixed

- **Reconnection not detected when the platform does not report it** — after a "lost" event, recovery depended entirely on a native "available" event, which the iOS Simulator often never sends. Periodic checks now run every `offlineCheckFrequency` while not online.
- **`slow` reported on networks without internet access** — e.g. an Android emulator whose Wi-Fi has no upstream: requests hang until the timeout, which was mapped to `slow`. A timeout is now `offline`.
- **Manual checks could leave no trace on the stream** — a `checkConnectivity()` result equal to the current status was not emitted. It now always is.
- **Stream stopped working after every listener cancelled** — `connectivityStream` used `shareReplay`, which closes for good once the last listener cancels, so a screen subscribing later received one stale value and then nothing. Monitoring now starts with the first listener, stops with the last and restarts when a new listener subscribes.
- **Slow reaction to native network changes** — every native event waited for an HTTP probe before anything was emitted (on "lost", up to `timeout`). "Lost" is now reported instantly; "available" triggers an immediate probe with quick follow-up re-checks until `online`, since a link that has just come up often cannot carry traffic yet. A native event arriving while a check is in flight is no longer dropped, and results made stale by a newer event are discarded.
- **Android reported per-network events** — the plugin listened to every network, so turning off Wi-Fi reported "lost" even when mobile data took over, and signal-strength changes triggered constant probes. It now follows the system default network only, reports "lost" at startup when there is no network, and debounces loss by 300 ms to absorb network handovers.
- **Linux reported "lost" for anything short of full connectivity** — including NetworkManager's `UNKNOWN` connectivity (checking disabled, the default on some distributions), captive portals, limited and transitional states, and machines without a reachable NetworkManager. It now reports "lost" only when there is no network at all (`NM_CONNECTIVITY_NONE`, `NM_STATE_ASLEEP`, `NM_STATE_DISCONNECTED`) and lets the Dart side verify access over HTTP in every other case.
- **Linux lost updates after a quick unsubscribe/subscribe** — e.g. navigating from one listening screen to another: cleanup of the old D-Bus session could close the new session's connection. Each session now owns its connection.
- **Native builds failing with `Undefined name 'LinuxRxConnectivityChecker'`** — the Linux plugin declaration used `fileName` instead of `dartFileName`, so the generated plugin registrant imported the public library, which no longer exports the Linux implementation. The registrant now imports `src/linux_rx_connectivity_checker.dart` directly.
- **Privacy manifest is now bundled** — `PrivacyInfo.xcprivacy` was present but never included by the podspecs. It is now packaged via `resource_bundles` (CocoaPods) and `resources` (SwiftPM) on both iOS and macOS.

### Changed

- **Android: migrated to built-in Kotlin** — the plugin no longer applies the Kotlin Gradle Plugin itself, which Android Gradle Plugin 9 rejects when built-in Kotlin is enabled and Flutter flags with "plugins that apply KGP" warnings. Flutter 3.44+ applies Kotlin when the app does not use built-in Kotlin. The Android build script is now `android/build.gradle.kts`.
- **Example app** — upgraded to Gradle 9.3.1, Android Gradle Plugin 9.1.0 and Kotlin 2.4.0, the versions of the Flutter 3.47 templates (removes the "support for your project's Gradle version will soon be dropped" warning).
- **Native source layout** — Swift sources and privacy manifests moved from `ios|macos/Classes` and `ios|macos/Resources` to `ios|macos/rx_connectivity_checker/Sources/rx_connectivity_checker/`, as required by SwiftPM.
- **macOS minimum deployment target** raised from 10.14 to 10.15 in the podspec to match Flutter's own minimum and the SwiftPM manifest.
- Podspec versions are now kept in sync with the package version (were `1.0.1`).

---

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