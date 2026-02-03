#include "rx_connectivity_checker_plugin.h"

#include <windows.h>
#include <VersionHelpers.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <netlistmgr.h>
#include <wrl/client.h>

#include <memory>
#include <sstream>

namespace rx_connectivity_checker {

    using Microsoft::WRL::ComPtr;

/// COM Sink class that listens for Network List Manager events.
/// Adheres to the Observer Pattern by bridging OS callbacks to Flutter.
    class ConnectivitySink : public INetworkListManagerEvents {
    public:
        ConnectivitySink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink)
                : sink_(std::move(sink)), ref_count_(1) {}

        // INetworkListManagerEvents Implementation
        STDMETHODIMP ConnectivityChanged(NLM_CONNECTIVITY new_connectivity) override {
            if (sink_) {
                // Check for IPv4 or IPv6 internet connectivity
                bool is_satisfied = (new_connectivity & (NLM_CONNECTIVITY_IPV4_INTERNET | NLM_CONNECTIVITY_IPV6_INTERNET)) != 0;
                sink_->Success(flutter::EncodableValue(is_satisfied ? "satisfied" : "unsatisfied"));
            }
            return S_OK;
        }

        // IUnknown Implementation
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

    class ConnectivityStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
    public:
        ConnectivityStreamHandler() {}

    protected:
        std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListen(
                const flutter::EncodableValue* arguments,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {

            // Initialize COM for the current thread
            HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

            // Create the Network List Manager instance
            hr = CoCreateInstance(CLSID_NetworkListManager, nullptr, CLSCTX_ALL, IID_INetworkListManager, &network_manager_);

            if (SUCCEEDED(hr)) {
                sink_obj_ = new ConnectivitySink(std::move(events));

                // Establish the connection point for events (Observer Pattern)
                ComPtr<IConnectionPointContainer> container;
                network_manager_.As(&container);
                container->FindConnectionPoint(IID_INetworkListManagerEvents, &connection_point_);
                connection_point_->Advice(sink_obj_, &cookie_);

                // Push initial state immediately
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
            }
            network_manager_.Reset();
            return nullptr;
        }

    private:
        ComPtr<INetworkListManager> network_manager_;
        ComPtr<IConnectionPoint> connection_point_;
        ConnectivitySink* sink_obj_ = nullptr;
        DWORD cookie_ = 0;
    };

    void RxConnectivityCheckerPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
        auto method_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                registrar->messenger(), "rx_connectivity_checker", &flutter::StandardMethodCodec::GetInstance());

        auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                registrar->messenger(), "rx_connectivity_checker/events", &flutter::StandardMethodCodec::GetInstance());

        auto plugin = std::make_unique<RxConnectivityCheckerPlugin>();

        method_channel->SetMethodCallHandler([plugin_pointer = plugin.get()](const auto &call, auto result) {
            plugin_pointer->HandleMethodCall(call, std::move(result));
        });

        event_channel->SetStreamHandler(std::make_unique<ConnectivityStreamHandler>());
        registrar->AddPlugin(std::move(plugin));
    }

    RxConnectivityCheckerPlugin::RxConnectivityCheckerPlugin() {}
    RxConnectivityCheckerPlugin::~RxConnectivityCheckerPlugin() {}

    void RxConnectivityCheckerPlugin::HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue> &method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (method_call.method_name().compare("getPlatformVersion") == 0) {
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

}//namespace rx_connectivity_checker
