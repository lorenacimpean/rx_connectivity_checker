package io.github.lorenacimpean.rx_connectivity_checker

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
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

class ConnectivityStreamHandler(private val context: Context) : EventChannel.StreamHandler {
    companion object {
        private const val TAG = "RxConnectivityChecker"  // ← added
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    private val connectivityManager: ConnectivityManager by lazy {
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var isRegistered = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        networkCallback = object : ConnectivityManager.NetworkCallback() {

            override fun onAvailable(network: Network) {
                sendEvent(events, "available")
            }

            override fun onLost(network: Network) {
                sendEvent(events, "lost")
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                sendEvent(events, "capabilities_changed")
            }

            override fun onLosing(network: Network, maxMsToLive: Int) {
                sendEvent(events, "losing")
            }

            override fun onUnavailable() {
                sendEvent(events, "unavailable")
            }
        }

        try {
            connectivityManager.registerNetworkCallback(request, networkCallback!!)
            isRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register network callback", e)
            events?.error("REGISTRATION_FAILED", e.message, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        if (isRegistered) {
            try {
                networkCallback?.let { connectivityManager.unregisterNetworkCallback(it) }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to unregister network callback", e)
            } finally {
                isRegistered = false
            }
        }
        networkCallback = null
    }

    private fun sendEvent(events: EventChannel.EventSink?, status: String) {
        mainHandler.post {
            try {
                events?.success(status)
            } catch (e: Exception) {
                Log.w(TAG, "Could not send event '$status' — sink may be closed: ${e.message}")
            }
        }
    }
}
