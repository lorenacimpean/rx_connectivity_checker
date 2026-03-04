import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import '../../rx_connectivity_checker_platform_interface.dart';

class WebRxConnectivityChecker extends RxConnectivityCheckerPlatform {
  Stream<String>? _platformStream;

  @override
  Stream<String> get platformStatusStream {
    _platformStream ??= _buildStream();
    return _platformStream!;
  }

  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }

  Stream<String> _buildStream() {
    late StreamController<String> controller;
    JSFunction? onlineHandler;
    JSFunction? offlineHandler;

    controller = StreamController<String>.broadcast(
      onListen: () {
        controller.add(web.window.navigator.onLine ? 'available' : 'lost');

        onlineHandler = ((web.Event _) => controller.add('available')).toJS;
        offlineHandler = ((web.Event _) => controller.add('lost')).toJS;

        web.window.addEventListener('online', onlineHandler!);
        web.window.addEventListener('offline', offlineHandler!);
      },
      onCancel: () {
        if (onlineHandler != null) {
          web.window.removeEventListener('online', onlineHandler!);
        }
        if (offlineHandler != null) {
          web.window.removeEventListener('offline', offlineHandler!);
        }
      },
    );

    return controller.stream;
  }

  static void registerWith(Registrar registrar) {
    RxConnectivityCheckerPlatform.instance = WebRxConnectivityChecker();
  }
}
