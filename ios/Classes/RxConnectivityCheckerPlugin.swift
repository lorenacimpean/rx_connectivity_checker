import Flutter
import UIKit
import Network

/// The main entry point for the RxConnectivityChecker Flutter plugin on iOS.
///
/// This class manages the lifecycle of the native channels and bridges the
/// iOS `NWPathMonitor` events to the Dart side.
///
/// It implements:
/// - `FlutterPlugin`: To hook into the Flutter registry.
public class SwiftRxConnectivityCheckerPlugin: NSObject, FlutterPlugin {

    // MARK: - Constants
    /// The base channel name. Must match the Android companion object constant.
    private static let channelName = "rx_connectivity_checker"

    // MARK: - Properties
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var streamHandler: ConnectivityStreamHandler?

    // MARK: - FlutterPlugin Protocol

    /// Registers the plugin with the Flutter registry.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftRxConnectivityCheckerPlugin()
        instance.setupChannels(with: registrar)
    }

    /// Sets up the MethodChannel and EventChannel.
    private func setupChannels(with registrar: FlutterPluginRegistrar) {
        // 1. Setup MethodChannel for one-off requests
        methodChannel = FlutterMethodChannel(name: SwiftRxConnectivityCheckerPlugin.channelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(self, channel: methodChannel!)

        // 2. Setup EventChannel for continuous network monitoring
        // logic: "$CHANNEL_NAME/events"
        let eventChannelName = "\(SwiftRxConnectivityCheckerPlugin.channelName)/events"
        eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())

        streamHandler = ConnectivityStreamHandler()
        eventChannel?.setStreamHandler(streamHandler)
    }

    /// Handles method calls from the Dart side.
    ///
    /// Currently supports:
    /// - `getPlatformVersion`: Returns the iOS system version.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getPlatformVersion" {
            result("iOS " + UIDevice.current.systemVersion)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    /// Cleanup logic if the plugin is detached.
    /// Note: `detachFromEngine` is available in newer Flutter iOS embedders.
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        eventChannel?.setStreamHandler(nil)
        streamHandler = nil
        methodChannel = nil
    }
}

/// A specialized handler that manages the iOS `NWPathMonitor` callbacks.
///
/// This class adheres to the Single Responsibility Principle (SRP) by isolating
/// the network monitoring logic from the plugin lifecycle.
class ConnectivityStreamHandler: NSObject, FlutterStreamHandler {

    /// The monitor responsible for observing network path changes.
    /// This is the iOS equivalent of Android's ConnectivityManager.
    private var monitor: NWPathMonitor?

    /// The queue on which the monitor runs.
    /// iOS Network monitoring requires a background queue to function correctly
    /// without blocking the main UI thread.
    private let monitorQueue = DispatchQueue(label: "io.github.lorenacimpean.rx_connectivity_checker.monitor")

    /// The sink to send events to Flutter.
    private var eventSink: FlutterEventSink?

    /**
     * Called when the Flutter side subscribes to the stream.
     *
     * @param arguments Arguments passed from Dart.
     * @param events The sink to send events to.
     */
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        self.monitor = NWPathMonitor()

        // Define the callback for path updates
        self.monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            // Map iOS specific path status to our generic event strings.
            // These strings act as triggers for the Dart side to run its robust checks.
            let status: String

            switch path.status {
            case .satisfied:
                // The network is usable (Internet accessible, Wifi connected, etc).
                // Equivalent to Android's `onAvailable` or `onCapabilitiesChanged`.
                status = "satisfied"
            case .unsatisfied:
                // No network route available (Airplane mode, no signal).
                // Equivalent to Android's `onLost`.
                status = "unsatisfied"
            case .requiresConnection:
                // Network is available but requires activation (e.g. VPN on demand).
                status = "requires_connection"
            @unknown default:
                status = "unknown"
            }

            // Send the event safely to Flutter
            self.sendEvent(status: status)
        }

        // Start monitoring on the dedicated background queue
        self.monitor?.start(queue: monitorQueue)

        return nil
    }

    /**
     * Called when the Flutter side cancels the subscription.
     *
     * We stop the monitor to save battery and resources.
     */
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.monitor?.cancel()
        self.monitor = nil
        self.eventSink = nil
        return nil
    }

    /**
     * Helper method to post events to the Main Thread safely.
     *
     * Flutter Platform Channels MUST be communicated with on the Main Thread,
     * but NWPathMonitor runs on a background queue.
     */
    private func sendEvent(status: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let sink = self.eventSink else { return }
            sink(status)
        }
    }
}