import 'package:flutter/foundation.dart';

abstract class Constants {
  /// Connectivity test endpoint used by `ConnectivityChecker`.
  ///
  /// Flutter Web requires a CORS-enabled URL; otherwise the browser
  /// blocks the request and `package:http` throws `ClientException:
  /// Failed to fetch`. Most common endpoints (Google, Cloudflare,
  /// etc.) do NOT allow cross-origin requests.
  ///
  /// `https://api.ipify.org?format=json` is used on Web because it
  /// explicitly enables CORS and works reliably in all browsers.
  ///
  /// Mobile/Desktop do not enforce CORS, so a faster lightweight
  /// endpoint (`https://www.gstatic.com/generate_204`) is used there.
  ///
  /// Summary:
  ///   • Web → requires CORS → use ipify
  ///   • Mobile/Desktop → no CORS → use gstatic 204
  static String defaultCheckUrl = kIsWeb
      ? "https://api.ipify.org?format=json"
      : "https://www.gstatic.com/generate_204";
}
