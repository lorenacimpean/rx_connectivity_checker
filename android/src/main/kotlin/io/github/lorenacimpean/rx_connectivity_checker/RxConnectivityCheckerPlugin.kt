package io.github.lorenacimpean.rx_connectivity_checker

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * The main entry point for the RxConnectivityChecker Flutter plugin.
 *
 * This class manages the lifecycle of the native channels and bridges the
 * Android `ConnectivityManager` events to the Dart side.
 *
 * It implements:
 * - [FlutterPlugin]: To hook into the Flutter engine lifecycle.
 * - [MethodCallHandler]: To handle one-off method calls (like `getPlatformVersion`).
 */
class RxConnectivityCheckerPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "rx_connectivity_checker"
    }

    /// The channel used for Method calls (Request -> Response).
    private lateinit var methodChannel: MethodChannel

    /// The channel used for streaming network events (Native -> Dart).
    private lateinit var eventChannel: EventChannel

    /// The application context, required to access system services safely.
    private lateinit var context: Context


    /**
     * Called when the plugin is attached to the Flutter engine.
     * @param binding The binding that provides access to the binary messenger and context.
     */
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        // Setup MethodChannel for one-off requests
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        // Setup EventChannel for continuous network monitoring
        eventChannel = EventChannel(binding.binaryMessenger, "$CHANNEL_NAME/events")
        eventChannel.setStreamHandler(ConnectivityStreamHandler(context))
    }

    /**
     * Handles method calls from the Dart side.
     *
     * Currently supports:
     * - `getPlatformVersion`: Returns the Android OS version.
     *
     * @param call The method call object containing the method name and arguments.
     * @param result The result object to send the response back to Dart.
     */
    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    /**
     * Called when the plugin is detached from the Flutter engine.
     *
     * We clean up our references here to prevent memory leaks.
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}

/**
 * A specialized handler that manages the Android `ConnectivityManager` callbacks.
 *
 * This class adheres to the Single Responsibility Principle (SRP) by isolating
 * the network monitoring logic from the plugin lifecycle.
 *
 * It listens for:
 * - Network availability ([onAvailable])
 * - Network loss ([onLost])
 * - Capability changes (e.g., Wifi -> Cellular, Internet Validated) ([onCapabilitiesChanged])
 *
 * @property context The application context used to retrieve the ConnectivityService.
 */
class ConnectivityStreamHandler(private val context: Context) : EventChannel.StreamHandler {

    /// The callback object required by the Android Connectivity API.
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    /// A handler bound to the Main Looper.
    /// Flutter Platform Channels MUST be communicated with on the Main Thread.
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Called when the Flutter side subscribes to the stream.
     *
     * @param arguments Arguments passed from Dart (unused here).
     * @param events The sink to send events to.
     */
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            /**
             * Fired when a new network (Wifi, Data, VPN) connects.
             */
            override fun onAvailable(network: Network) {
                sendEvent(events, "available")
            }

            /**
             * Fired when a network disconnects.
             */
            override fun onLost(network: Network) {
                sendEvent(events, "lost")
            }

            /**
             * Fired when network capabilities change.
             *
             * Examples:
             * - Signal strength changes (ignored by our simplified logic).
             * - Captive portal is authenticated (Internet becomes valid).
             * - Transport type changes (Wifi -> Cellular).
             *
             * This ensures we catch edge cases where "Connected" does not mean "Internet Access".
             */
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: android.net.NetworkCapabilities
            ) {
                sendEvent(events, "capabilities_changed")
            }

            /**
             * Fired when the network is about to disconnect.
             * Allows for proactive UI updates.
             */
            override fun onLosing(network: Network, maxMsToLive: Int) {
                sendEvent(events, "losing")
            }

            /**
             * Fired when the requested network is unavailable.
             */
            override fun onUnavailable() {
                sendEvent(events, "unavailable")
            }
        }

        // Register the callback to listen for ALL network changes.
        manager.registerNetworkCallback(
            NetworkRequest.Builder().build(),
            networkCallback!!
        )
    }

    /**
     * Called when the Flutter side cancels the subscription.
     *
     * We strictly unregister the callback here to prevent battery drain and leaks.
     */
    override fun onCancel(arguments: Any?) {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        networkCallback?.let {
            manager.unregisterNetworkCallback(it)
        }
        networkCallback = null
    }

    /**
     * Helper method to post events to the Main Thread safely.
     *
     * @param events The sink to write to.
     * @param status The string status to emit.
     */
    private fun sendEvent(events: EventChannel.EventSink?, status: String) {
        mainHandler.post {
            try {
                events?.success(status)
            } catch (e: Exception) {
                // Determine if this exception should be logged or ignored based on app lifecycle state.
            }
        }
    }
}