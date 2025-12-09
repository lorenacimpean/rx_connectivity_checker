---
name: "🚀 New Feature Request: rx_connectivity_checker"
about: Suggest an idea or enhancement for the reactive connectivity monitoring package.
title: "[FEATURE] Concise and descriptive title of the requested feature"
labels: 'feature, enhancement, rxdart, needs triage'
assignees: ''
---

## 🚀 Feature Summary

### 1. The Problem

Is this feature request related to a problem or limitation you're currently facing with `rx_connectivity_checker`?

* [ ] Yes
* [ ] No

If **Yes**, please describe the problem clearly. Why is the current configuration or API insufficient for your use case?

> **Example:** "I need to perform a different type of health check (e.g., a HEAD request instead of a GET) but the current `ConnectivityChecker` only supports configuring the URL, not the HTTP method."

### 2. Proposed Solution / API Design

Describe the feature you'd like to see added. Focus on how it integrates with the existing reactive model.

### 3. Expected Behavior and Dart/RxDart Usage

How would a top Dart/Flutter engineer use this new feature?

* What new **methods**, **parameters**, or **classes** do you suggest on `ConnectivityChecker`?
* If related to streams, how should the new feature affect the existing `connectivityStream`?
* Provide a minimal, reproducible **code example** demonstrating the desired usage:

```dart
// Desired implementation example:

final checker = ConnectivityChecker(
  url: '[https://my-backend.com/health](https://my-backend.com/health)',
  // Suggested new configuration parameter:
  httpMethod: HttpMethod.head, 
);

// How the stream (RxDart) would react:
// checker.connectivityStream
//   .where((status) => status == ConnectivityResult.online)
//   .listen((_) {
//     // Perform high-priority task
//   });