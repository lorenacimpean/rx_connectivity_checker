abstract class ConnectivityCheckerConstants {
  static String defaultCheckUrl = "https://www.gstatic.com/generate_204";
  static const Duration defaultTimeout = Duration(seconds: 15);
  static const Duration defaultCheckFrequency = Duration(seconds: 15);
  static const Duration defaultThrottleTime = Duration(milliseconds: 300);
}
