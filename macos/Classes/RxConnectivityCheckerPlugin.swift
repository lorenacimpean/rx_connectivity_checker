import Cocoa
import FlutterMacOS
import Network

/// macOS implementation of the RxConnectivityChecker.
///
/// Reuses the NWPathMonitor logic to provide high-performance,
/// power-efficient network monitoring on desktop.
public class SwiftRxConnectivityCheckerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "RxConnectivityMonitor")

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "rx_connectivity_checker", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "rx_connectivity_checker/events", binaryMessenger: registrar.messenger)

        let instance = SwiftRxConnectivityCheckerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        monitor.pathUpdateHandler = { [weak self] path in
            // Map native status to our unified plugin protocol
            let status = path.status == .satisfied ? "satisfied" : "unsatisfied"
            self?.eventSink?(status)
        }

        monitor.start(queue: queue)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        monitor.cancel()
        eventSink = nil
        return nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (call.method == "getPlatformVersion") {
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}