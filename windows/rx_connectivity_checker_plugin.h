#ifndef FLUTTER_PLUGIN_RX_CONNECTIVITY_CHECKER_PLUGIN_H_
#define FLUTTER_PLUGIN_RX_CONNECTIVITY_CHECKER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <netlistmgr.h>
#include <wrl/client.h> // Standard Windows Smart Pointers (No ATL required)
#include <memory>
#include <atomic>
#include <string>

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

    class RxConnectivityCheckerPlugin
            : public flutter::Plugin,
              public flutter::StreamHandler<flutter::EncodableValue> {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

        RxConnectivityCheckerPlugin();
        virtual ~RxConnectivityCheckerPlugin();

        RxConnectivityCheckerPlugin(const RxConnectivityCheckerPlugin&) = delete;
        RxConnectivityCheckerPlugin& operator=(const RxConnectivityCheckerPlugin&) = delete;

    private:
        // StreamHandler methods
        std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
                const flutter::EncodableValue* arguments,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override;

        std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
                const flutter::EncodableValue* arguments) override;

        void HandleMethodCall(
                const flutter::MethodCall<flutter::EncodableValue> &method_call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        void StartListening();
        void StopListening();
        void BroadcastStatus(NLM_CONNECTIVITY connectivity);

        // Use WRL ComPtr instead of ATL CComPtr
        Microsoft::WRL::ComPtr<INetworkListManager> network_list_manager_;
        Microsoft::WRL::ComPtr<IConnectionPoint> connection_point_;
        DWORD cookie_ = 0;

        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
    };

}  // namespace rx_connectivity_checker

#endif  // FLUTTER_PLUGIN_RX_CONNECTIVITY_CHECKER_PLUGIN_H_