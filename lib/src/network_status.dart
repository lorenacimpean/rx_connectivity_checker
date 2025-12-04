// Indicates the state of network reachability based on an HTTP request.
enum NetworkStatus {
  /// The remote endpoint responded with a valid 2xx status code.
  online,

  /// The remote endpoint could not be reached or responded with a non-2xx code.
  offline,

  /// The request timed out, and slow-connection detection is enabled.
  slow,

  /// The initial or uninitialized state of the checker before the first check completes.
  unknown,
}
