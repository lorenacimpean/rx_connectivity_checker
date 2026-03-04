import Cocoa
import FlutterMacOS
import Network

public class SwiftRxConnectivityCheckerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "io.github.lorenacimpean.rx_connectivity_checker.monitor")
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
        lastStatus = nil

        // Create a fresh monitor each subscription so that re-subscribing after
        // a cancel works correctly (a cancelled NWPathMonitor cannot be restarted).
        let newMonitor = NWPathMonitor()
        self.monitor = newMonitor

        newMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let currentStatus = path.status == .satisfied ? "available" : "lost"

            // Deduplication: only forward if the state actually changed.
            guard currentStatus != self.lastStatus else { return }
            self.lastStatus = currentStatus

            // NWPathMonitor fires on the background queue; Flutter's event sink
            // must be called on the main (platform) thread.
            DispatchQueue.main.async { [weak self] in
                self?.eventSink?(currentStatus)
            }
        }

        newMonitor.start(queue: queue)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        monitor?.cancel()
        monitor = nil
        eventSink = nil
        lastStatus = nil
        return nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getPlatformVersion" {
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}
