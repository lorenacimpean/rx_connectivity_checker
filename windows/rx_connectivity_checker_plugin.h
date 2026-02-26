#ifndef FLUTTER_PLUGIN_RX_CONNECTIVITY_CHECKER_PLUGIN_H_
#define FLUTTER_PLUGIN_RX_CONNECTIVITY_CHECKER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <netlistmgr.h>
#include <wrl/client.h>
#include <memory>
#include <atomic>
#include <mutex>
#include <string>
#include <functional>

namespace rx_connectivity_checker {

// Listener for Windows Network List Manager events.
    class NetworkManagerEvents : public INetworkListManagerEvents {
    public:
        NetworkManagerEvents(std::function<void(NLM_CONNECTIVITY)> callback)
                : callback_(callback), ref_count_(1) {}

        // IUnknown boilerplate
        IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override;
        IFACEMETHODIMP_(ULONG) AddRef() override;
        IFACEMETHODIMP_(ULONG) Release() override;

        // INetworkListManagerEvents implementation
        IFACEMETHODIMP ConnectivityChanged(NLM_CONNECTIVITY newConnectivity) override;

    private:
        std::atomic<ULONG> ref_count_;
        std::function<void(NLM_CONNECTIVITY)> callback_;
    };

    class RxConnectivityCheckerPlugin : public flutter::Plugin {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

        explicit RxConnectivityCheckerPlugin(flutter::TaskRunner* task_runner);
        virtual ~RxConnectivityCheckerPlugin();

        RxConnectivityCheckerPlugin(const RxConnectivityCheckerPlugin&) = delete;
        RxConnectivityCheckerPlugin& operator=(const RxConnectivityCheckerPlugin&) = delete;

        // Exposed as public so StreamHandlerDelegate (defined in the .cpp) can
        // forward calls to these without friendship gymnastics.
        std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
                const flutter::EncodableValue* arguments,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events);

        std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
                const flutter::EncodableValue* arguments);

    private:
        // MethodChannel handler
        void HandleMethodCall(
                const flutter::MethodCall<flutter::EncodableValue> &method_call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        // Internal helpers
        void StartListening();
        void StopListening();
        void BroadcastStatus(NLM_CONNECTIVITY connectivity);
        std::string ConnectivityToString(NLM_CONNECTIVITY connectivity);

        // Task runner for marshalling COM callbacks back to the platform thread.
        flutter::TaskRunner* task_runner_;

        // WRL Smart Pointers
        Microsoft::WRL::ComPtr<INetworkListManager> network_list_manager_;
        Microsoft::WRL::ComPtr<IConnectionPoint> connection_point_;
        DWORD cookie_ = 0;

        // Protects event_sink_, which is written on the platform thread but
        // guarded against the (now-PostTask'd) COM callback thread.
        std::mutex sink_mutex_;
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

        // Lifetime guard: flipped to false in the destructor *before* StopListening.
        // The COM callback lambda holds a weak_ptr so it can bail out safely if
        // the plugin is already being torn down (fix #2).
        std::shared_ptr<bool> alive_;
    };

}  // namespace rx_connectivity_checker

#endif  // FLUTTER_PLUGIN_RX_CONNECTIVITY_CHECKER_PLUGIN_H_
