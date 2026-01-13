import Cocoa
import FlutterMacOS
import Network

public class SwiftRxConnectivityCheckerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "RxConnectivityMonitor")

    /// Optimization: This variable must be declared here to be in scope.
    /// It tracks the last emitted status to prevent duplicate events across the bridge.
    private var lastStatus: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "rx_connectivity_checker", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "rx_connectivity_checker/events", binaryMessenger: registrar.messenger)

        let instance = SwiftRxConnectivityCheckerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        // Reset lastStatus on a new subscription to ensure the current state is sent immediately
        lastStatus = nil

        monitor.pathUpdateHandler = { [weak self] path in
            let currentStatus = path.status == .satisfied ? "satisfied" : "unsatisfied"

            // Deduplication logic: Only send to Dart if the state actually changed
            if currentStatus != self?.lastStatus {
                self?.lastStatus = currentStatus

                // Ensure the event is sent back to the Flutter event sink
                self?.eventSink?(currentStatus)
            }
        }

        monitor.start(queue: queue)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        monitor.cancel()
        eventSink = nil
        lastStatus = nil
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