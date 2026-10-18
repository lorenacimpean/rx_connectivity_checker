// Indicates the state of network reachability based on an HTTP request.
enum ConnectivityStatus {
  /// The remote endpoint responded with a valid 2xx status code.
  online,

  /// The remote endpoint could not be reached, did not respond within the
  /// timeout, or responded with a non-2xx code.
  offline,

  /// The remote endpoint responded with a 2xx code, but slower than the
  /// slow-connection threshold, and slow-connection detection is enabled.
  slow,

  /// The initial or uninitialized state of the checker before the first check completes.
  unknown,
}
