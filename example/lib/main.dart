import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'connectivity_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const RxConnectivityExampleApp());
}

class RxConnectivityExampleApp extends StatelessWidget {
  const RxConnectivityExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'rx_connectivity_checker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const ConnectivityScreen(),
      );
}
