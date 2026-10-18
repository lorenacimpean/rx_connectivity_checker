import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityChecker on a connected machine', () {
    testWidgets('reports online after the native startup event', (_) async {
      final checker = ConnectivityChecker(timeout: const Duration(seconds: 10));

      final status = await checker.connectivityStream
          .firstWhere((status) => status != ConnectivityStatus.unknown)
          .timeout(const Duration(seconds: 30));

      expect(status, ConnectivityStatus.online);
    });

    testWidgets('checkConnectivity returns online', (_) async {
      final checker = ConnectivityChecker(timeout: const Duration(seconds: 10));

      final status = await checker.checkConnectivity();

      expect(status, ConnectivityStatus.online);
    });
  });
}
