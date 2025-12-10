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