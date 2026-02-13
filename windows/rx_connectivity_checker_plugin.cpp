#include "rx_connectivity_checker_plugin.h"

#include <windows.h>
#include <netlistmgr.h>
#include <sstream>

namespace rx_connectivity_checker {

// --- COM Event Listener Implementation ---

    IFACEMETHODIMP NetworkManagerEvents::QueryInterface(REFIID riid, void** ppv) {
        if (!ppv) return E_POINTER;
        if (riid == IID_IUnknown || riid == IID_INetworkListManagerEvents) {
            *ppv = static_cast<INetworkListManagerEvents*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    IFACEMETHODIMP_(ULONG) NetworkManagerEvents::AddRef() {
        return ++ref_count_;
    }

    IFACEMETHODIMP_(ULONG) NetworkManagerEvents::Release() {
        ULONG uCount = --ref_count_;
        if (uCount == 0) delete this;
        return uCount;
    }

    IFACEMETHODIMP NetworkManagerEvents::ConnectivityChanged(NLM_CONNECTIVITY newConnectivity) {
        if (callback_) callback_(newConnectivity);
        return S_OK;
    }

// --- Plugin Implementation ---

    void RxConnectivityCheckerPlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarWindows *registrar) {

        auto plugin = std::make_unique<RxConnectivityCheckerPlugin>();

        auto method_channel =
                std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                        registrar->messenger(), "rx_connectivity_checker",
                                &flutter::StandardMethodCodec::GetInstance());

        method_channel->SetMethodCallHandler(
                [plugin_pointer = plugin.get()](const auto &call, auto result) {
                    plugin_pointer->HandleMethodCall(call, std::move(result));
                });

        auto event_channel =
                std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                        registrar->messenger(), "rx_connectivity_checker/events",
                                &flutter::StandardMethodCodec::GetInstance());

        event_channel->SetStreamHandler(std::move(plugin));
    }

    RxConnectivityCheckerPlugin::RxConnectivityCheckerPlugin() {
        CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    }

    RxConnectivityCheckerPlugin::~RxConnectivityCheckerPlugin() {
        StopListening();
        CoUninitialize();
    }

    void RxConnectivityCheckerPlugin::HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue> &method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        if (method_call.method_name().compare("getPlatformVersion") == 0) {
            std::ostringstream version_stream;
            version_stream << "Windows";
            result->Success(flutter::EncodableValue(version_stream.str()));
        } else {
            result->NotImplemented();
        }
    }

    void RxConnectivityCheckerPlugin::StartListening() {
        // WRL: Use global CoCreateInstance with IID_PPV_ARGS helper
        HRESULT hr = CoCreateInstance(
                CLSID_NetworkListManager,
                nullptr,
                CLSCTX_ALL,
                IID_PPV_ARGS(&network_list_manager_));

        if (FAILED(hr) || !network_list_manager_) {
            if (event_sink_) event_sink_->Error("COM_ERROR", "Failed to init NetworkListManager");
            return;
        }

        // Initial Check
        NLM_CONNECTIVITY connectivity;
        if (SUCCEEDED(network_list_manager_->GetConnectivity(&connectivity))) {
            BroadcastStatus(connectivity);
        }

        // Hook up listener
        Microsoft::WRL::ComPtr<IConnectionPointContainer> cpc;
        if (SUCCEEDED(network_list_manager_.As(&cpc))) {
            if (SUCCEEDED(cpc->FindConnectionPoint(IID_INetworkListManagerEvents, &connection_point_))) {
                auto* events = new NetworkManagerEvents(
                        [this](NLM_CONNECTIVITY c) { this->BroadcastStatus(c); });

                connection_point_->Advise(events, &cookie_);
                events->Release();
            }
        }
    }

    void RxConnectivityCheckerPlugin::StopListening() {
        if (connection_point_ && cookie_) {
            connection_point_->Unadvise(cookie_);
            cookie_ = 0;
        }
        connection_point_.Reset();
        network_list_manager_.Reset();
    }

    void RxConnectivityCheckerPlugin::BroadcastStatus(NLM_CONNECTIVITY connectivity) {
        if (!event_sink_) return;

        std::string status;
        if (connectivity == NLM_CONNECTIVITY_DISCONNECTED) {
            status = "lost";
        } else if ((connectivity & NLM_CONNECTIVITY_IPV4_INTERNET) ||
                (connectivity & NLM_CONNECTIVITY_IPV6_INTERNET)) {
            status = "available";
        } else {
            status = "capabilities_changed";
        }

        event_sink_->Success(flutter::EncodableValue(status));
    }

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    RxConnectivityCheckerPlugin::OnListenInternal(
            const flutter::EncodableValue* arguments,
            std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
        event_sink_ = std::move(events);
        StartListening();
        return nullptr;
    }

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    RxConnectivityCheckerPlugin::OnCancelInternal(
            const flutter::EncodableValue* arguments) {
        StopListening();
        event_sink_ = nullptr;
        return nullptr;
    }

}  // namespace rx_connectivity_checker