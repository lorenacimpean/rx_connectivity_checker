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
        // Setup MethodChannel for one-off requests
        methodChannel = FlutterMethodChannel(
            name: SwiftRxConnectivityCheckerPlugin.channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(self, channel: methodChannel!)

        // Setup EventChannel for continuous network monitoring
        // logic: "$CHANNEL_NAME/events"
        let eventChannelName = "\(SwiftRxConnectivityCheckerPlugin.channelName)/events"
        eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())

        streamHandler = ConnectivityStreamHandler()
        eventChannel?.setStreamHandler(streamHandler)
    }

    /// Handles method calls from the Dart side.
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
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        eventChannel?.setStreamHandler(nil)
        streamHandler = nil
        methodChannel = nil
    }
}

/// A specialized handler that manages the iOS `NWPathMonitor` callbacks.
///
/// Responsibilities:
/// - Translates `NWPath.Status` to string tokens consumed by Dart.
/// - Applies a **unified debounce** to every status transition so that rapid
///   bursts (e.g. WiFi → unsatisfied → cellular handoff) collapse into a
///   single emission of the final stable state.
/// - Suppresses duplicate consecutive emissions via `lastEmittedStatus`.
class ConnectivityStreamHandler: NSObject, FlutterStreamHandler {

    // MARK: - Private state

    /// The monitor responsible for observing network path changes.
    private var monitor: NWPathMonitor?

    /// Dedicated background queue for `NWPathMonitor`.
    /// Must not be the main queue — the monitor blocks its queue while running.
    private let monitorQueue = DispatchQueue(
        label: "io.github.lorenacimpean.rx_connectivity_checker.monitor",
        qos: .utility
    )

    /// The sink used to forward events to Dart.
    private var eventSink: FlutterEventSink?

    /// The last status successfully forwarded to Dart.
    /// Used to suppress duplicate emissions after debounce settles.
    private var lastEmittedStatus: String?

    /// A single pending work item shared by ALL status transitions.
    ///
    /// **Why a unified work item?**
    ///
    /// `NWPathMonitor` can fire multiple rapid callbacks during any network
    /// change — including handoffs between interfaces (WiFi → cellular) that
    /// produce an intermediate `.unsatisfied` pulse before re-settling on
    /// `.satisfied`. With separate paths for "available" vs "lost":
    ///
    ///   satisfied → unsatisfied → satisfied
    ///        ↓             ↓            ↓
    ///   (debounced)  (immediate ❌)  (debounced)
    ///
    /// The "lost" fires immediately, producing a false offline event.
    ///
    /// With a single shared work item every incoming status **replaces** the
    /// previous pending one, so only the final stable state in a burst is
    /// emitted — for both "available" and "lost" transitions.
    private var pendingWork: DispatchWorkItem?

    /// How long to wait after the last raw callback before forwarding the
    /// resolved status to Dart. 300 ms comfortably covers WiFi→cellular
    /// handoffs without being perceptible to the user.
    private static let debounceInterval: TimeInterval = 0.3

    // MARK: - FlutterStreamHandler

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events
        self.monitor = NWPathMonitor()

        self.monitor?.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let status: String
            switch path.status {
            case .satisfied:         status = "available"
            case .unsatisfied:       status = "lost"
            case .requiresConnection: status = "requires_connection"
            @unknown default:        status = "lost"
            }

            // Transition to main thread before touching shared state.
            DispatchQueue.main.async { [weak self] in
                self?.scheduleEmission(of: status)
            }
        }

        self.monitor?.start(queue: monitorQueue)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        cancelPending()
        monitor?.cancel()
        monitor = nil
        eventSink = nil
        lastEmittedStatus = nil
        return nil
    }

    // MARK: - Debounce logic (main thread only)

    /// Replaces any pending work item with a new one that will emit `status`
    /// after `debounceInterval` seconds — unless superseded by a later call.
    ///
    /// Must be called on the main thread.
    private func scheduleEmission(of status: String) {
        cancelPending()

        let work = DispatchWorkItem { [weak self] in
            self?.emit(status: status)
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ConnectivityStreamHandler.debounceInterval,
            execute: work
        )
    }

    /// Cancels and discards the current pending work item.
    private func cancelPending() {
        pendingWork?.cancel()
        pendingWork = nil
    }

    /// Forwards `status` to Dart only when it differs from the last emission.
    ///
    /// Must be called on the main thread.
    private func emit(status: String) {
        guard status != lastEmittedStatus, let sink = eventSink else { return }
        lastEmittedStatus = status
        sink(status)
    }
}