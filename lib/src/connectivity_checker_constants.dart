abstract class ConnectivityCheckerConstants {
  static const String defaultCheckUrl = 'https://www.gstatic.com/generate_204';
  static const Duration defaultTimeout = Duration(seconds: 15);
  static const Duration defaultCheckFrequency = Duration(seconds: 30);
  static const Duration defaultThrottleTime = Duration(milliseconds: 300);
  static const List<Duration> defaultRecheckDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];
}
