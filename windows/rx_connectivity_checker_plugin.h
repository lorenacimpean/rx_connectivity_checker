#include "rx_connectivity_checker_plugin.h"

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <VersionHelpers.h>
#include <netlistmgr.h>
#include <wrl/client.h>
#include <memory>
#include <sstream>

namespace rx_connectivity_checker {

    using Microsoft::WRL::ComPtr;

// ---------------------------------------------------------
// COM Sink for network change events
// ---------------------------------------------------------
    class ConnectivitySink : public INetworkListManagerEvents {
    public:
        explicit ConnectivitySink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink)
                : sink_(std::move(sink)), ref_count_(1) {}

        STDMETHODIMP ConnectivityChanged(NLM_CONNECTIVITY new_connectivity) override {
            if (sink_) {
                bool is_satisfied =
                        (new_connectivity & (NLM_CONNECTIVITY_IPV4_INTERNET | NLM_CONNECTIVITY_IPV6_INTERNET)) != 0;
                sink_->Success(flutter::EncodableValue(is_satisfied ? "satisfied" : "unsatisfied"));
            }
            return S_OK;
        }

        STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
            if (riid == IID_IUnknown || riid == IID_INetworkListManagerEvents) {
                *ppv = static_cast<INetworkListManagerEvents*>(this);
                AddRef();
                return S_OK;
            }
            *ppv = nullptr;
            return E_NOINTERFACE;
        }

        STDMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&ref_count_); }
        STDMETHODIMP_(ULONG) Release() override {
            ULONG res = InterlockedDecrement(&ref_count_);
            if (res == 0) delete this;
            return res;
        }

    private:
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
        long ref_count_;
    };

// ---------------------------------------------------------
// StreamHandler for Flutter EventChannel
// ---------------------------------------------------------
    class ConnectivityStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
    public:
        ConnectivityStreamHandler() = default;
        ~ConnectivityStreamHandler() override = default;

        std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListen(
                const flutter::EncodableValue* arguments,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {

            event_sink_ = std::move(events);

            // Initialize COM
            CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
            HRESULT hr = CoCreateInstance(CLSID_NetworkListManager, nullptr, CLSCTX_ALL, IID_INetworkListManager,
                    &network_manager_);

            if (SUCCEEDED(hr)) {
                sink_obj_ = new ConnectivitySink(std::move(event_sink_));

                ComPtr<IConnectionPointContainer> container;
                if (SUCCEEDED(network_manager_.As(&container))) {
                    if (SUCCEEDED(container->FindConnectionPoint(IID_INetworkListManagerEvents, &connection_point_))) {
                        connection_point_->Advise(sink_obj_, &cookie_);
                        sink_obj_->Release(); // relinquish ownership
                    }
                }

                // Send initial connectivity state
                NLM_CONNECTIVITY connectivity;
                if (SUCCEEDED(network_manager_->GetConnectivity(&connectivity))) {
                    sink_obj_->ConnectivityChanged(connectivity);
                }
            }

            return nullptr;
        }

        std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancel(
                const flutter::EncodableValue* arguments) override {

            if (connection_point_) {
                connection_point_->Unadvise(cookie_);
                connection_point_.Reset();
                cookie_ = 0;
            }
            network_manager_.Reset();
            sink_obj_ = nullptr;

            CoUninitialize();
            return nullptr;
        }

    private:
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
        ComPtr<INetworkListManager> network_manager_;
        ComPtr<IConnectionPoint> connection_point_;
        ConnectivitySink* sink_obj_ = nullptr;
        DWORD cookie_ = 0;
    };

// ---------------------------------------------------------
// Plugin class
// ---------------------------------------------------------
    RxConnectivityCheckerPlugin::RxConnectivityCheckerPlugin() = default;
    RxConnectivityCheckerPlugin::~RxConnectivityCheckerPlugin() = default;

    void RxConnectivityCheckerPlugin::HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue>& method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (method_call.method_name() == "getPlatformVersion") {
            std::ostringstream version_stream;
            version_stream << "Windows ";
            if (IsWindows10OrGreater()) {
                version_stream << "10+";
            } else if (IsWindows8OrGreater()) {
                version_stream << "8";
            } else if (IsWindows7OrGreater()) {
                version_stream << "7";
            }
            result->Success(flutter::EncodableValue(version_stream.str()));
        } else {
            result->NotImplemented();
        }
    }

    void RxConnectivityCheckerPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
        auto method_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                registrar->messenger(), "rx_connectivity_checker", &flutter::StandardMethodCodec::GetInstance());

        auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                registrar->messenger(), "rx_connectivity_checker/events", &flutter::StandardMethodCodec::GetInstance());

        auto plugin = std::make_unique<RxConnectivityCheckerPlugin>();

        method_channel->SetMethodCallHandler([plugin_ptr = plugin.get()](const auto& call, auto result) {
            plugin_ptr->HandleMethodCall(call, std::move(result));
        });

        event_channel->SetStreamHandler(std::make_unique<ConnectivityStreamHandler>());
        registrar->AddPlugin(std::move(plugin));
    }

}  // namespace rx_connectivity_checker
