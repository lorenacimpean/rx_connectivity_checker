package io.github.lorenacimpean.rx_connectivity_checker

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class RxConnectivityCheckerPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "rx_connectivity_checker"
        private const val TAG = "RxConnectivityChecker"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "$CHANNEL_NAME/events")
        eventChannel.setStreamHandler(ConnectivityStreamHandler(context))
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}

/**
 * Streams the state of the system default network to Dart.
 *
 * - "available" is sent whenever a default network appears or the default
 *   network changes (e.g. Wi-Fi → mobile data), so Dart re-validates access.
 * - "lost" is sent when there is no default network at all. It is delayed by
 *   [LOST_DEBOUNCE_MS] so a handover between networks does not report a false
 *   loss, and it is ignored for networks that are no longer the default.
 *
 * The current state is sent as soon as Dart starts listening.
 */
class ConnectivityStreamHandler(private val context: Context) : EventChannel.StreamHandler {
    companion object {
        private const val TAG = "RxConnectivityChecker"
        private const val LOST_DEBOUNCE_MS = 300L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private val connectivityManager: ConnectivityManager by lazy {
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private var eventSink: EventChannel.EventSink? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var defaultNetwork: Network? = null
    private val sendLost = Runnable { send("lost") }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        defaultNetwork = null
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                mainHandler.post { onDefaultNetworkAvailable(network) }
            }

            override fun onLost(network: Network) {
                mainHandler.post { onDefaultNetworkLost(network) }
            }
        }
        try {
            connectivityManager.registerDefaultNetworkCallback(callback)
            networkCallback = callback
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register default network callback", e)
            events?.error("REGISTRATION_FAILED", e.message, null)
            return
        }
        // onAvailable fires immediately when a default network exists; without
        // one nothing fires, so report the "lost" state explicitly.
        if (connectivityManager.activeNetwork == null) send("lost")
    }

    override fun onCancel(arguments: Any?) {
        mainHandler.removeCallbacks(sendLost)
        networkCallback?.let {
            try {
                connectivityManager.unregisterNetworkCallback(it)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to unregister network callback", e)
            }
        }
        networkCallback = null
        defaultNetwork = null
        eventSink = null
    }

    private fun onDefaultNetworkAvailable(network: Network) {
        mainHandler.removeCallbacks(sendLost)
        defaultNetwork = network
        send("available")
    }

    private fun onDefaultNetworkLost(network: Network) {
        if (network != defaultNetwork) return
        defaultNetwork = null
        mainHandler.removeCallbacks(sendLost)
        mainHandler.postDelayed(sendLost, LOST_DEBOUNCE_MS)
    }

    private fun send(status: String) {
        try {
            eventSink?.success(status)
        } catch (e: Exception) {
            Log.w(TAG, "Could not send event '$status' — sink may be closed: ${e.message}")
        }
    }
}
