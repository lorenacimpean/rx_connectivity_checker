import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rx_connectivity_checker/rx_connectivity_checker_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const String methodChannelName = 'rx_connectivity_checker';
  const String eventChannelName = 'rx_connectivity_checker/events';
  const MethodChannel methodChannel = MethodChannel(methodChannelName);
  const MethodChannel eventChannelMethods = MethodChannel(eventChannelName);

  late MethodChannelRxConnectivityChecker platform;

  setUp(() {
    platform = MethodChannelRxConnectivityChecker();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
          if (methodCall.method == 'getPlatformVersion') {
            return '42';
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannelMethods, (
          MethodCall methodCall,
        ) async {
          switch (methodCall.method) {
            case 'listen':
              // The native side "accepted" the listener.
              return null;
            case 'cancel':
              // The native side "accepted" the cancellation.
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannelMethods, null);
  });

  test('getPlatformVersion returns correct value', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('platformStatusStream receives events from native platform', () async {
    final expectation = expectLater(
      platform.platformStatusStream,
      emits('online'),
    );

    await Future.delayed(Duration.zero);

    await _sendPlatformMessage(eventChannelName, 'online');

    await expectation;
  });
}

/// Helper to simulate the OS sending a message to Flutter
Future<void> _sendPlatformMessage(String channelName, String payload) {
  final ByteData message = const StandardMethodCodec().encodeSuccessEnvelope(
    payload,
  );

  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channelName, message, (ByteData? data) {});
}
