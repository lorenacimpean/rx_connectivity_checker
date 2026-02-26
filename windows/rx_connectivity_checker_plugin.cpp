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

// ---------------------------------------------------------------------------
// StreamHandlerDelegate
//
// A thin StreamHandler that forwards OnListen/OnCancel to the plugin via a
// shared_ptr. This lets SetStreamHandler take unique ownership of this object
// while the plugin itself is kept alive independently via the registrar.
// ---------------------------------------------------------------------------
    class StreamHandlerDelegate
            : public flutter::StreamHandler<flutter::EncodableValue> {
    public:
        explicit StreamHandlerDelegate(
                std::shared_ptr<RxConnectivityCheckerPlugin> plugin)
                : plugin_(std::move(plugin)) {}

    protected:
        std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
        OnListenInternal(
                const flutter::EncodableValue* arguments,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
        override {
            if (auto p = plugin_.lock()) {
                return p->OnListenInternal(arguments, std::move(events));
            }
            return nullptr;
        }

        std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
        OnCancelInternal(const flutter::EncodableValue* arguments) override {
            if (auto p = plugin_.lock()) {
                return p->OnCancelInternal(arguments);
            }
            return nullptr;
        }

    private:
        std::weak_ptr<RxConnectivityCheckerPlugin> plugin_;
    };

// --- Plugin Implementation ---

    void RxConnectivityCheckerPlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarWindows *registrar) {


        auto plugin = std::make_shared<RxConnectivityCheckerPlugin>(
                registrar->GetTaskRunner());

        // Method channel — lambda holds a weak_ptr to avoid a dangling raw ptr.
        auto method_channel =
                std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                        registrar->messenger(), "rx_connectivity_checker",
                        &flutter::StandardMethodCodec::GetInstance());

        std::weak_ptr<RxConnectivityCheckerPlugin> weak_plugin = plugin;
        method_channel->SetMethodCallHandler(
                [weak_plugin](const auto &call, auto result) {
                    if (auto p = weak_plugin.lock()) {
                        p->HandleMethodCall(call, std::move(result));
                    } else {
                        result->Error("PLUGIN_GONE", "Plugin has been destroyed");
                    }
                });

        // Event channel — delegate owns a weak_ptr; SetStreamHandler takes the
        // delegate by unique_ptr without touching the plugin's own lifetime.
        auto event_channel =
                std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                        registrar->messenger(), "rx_connectivity_checker/events",
                        &flutter::StandardMethodCodec::GetInstance());

        event_channel->SetStreamHandler(
                std::make_unique<StreamHandlerDelegate>(plugin));

        // Hand the plugin to the registrar so it stays alive for the engine's
        // lifetime (registrar keeps a unique_ptr<Plugin> internally).
        registrar->AddPlugin(std::move(plugin));
    }

    // Flutter's Windows runner already initialises the COM apartment on the
    // platform thread before any plugin is registered. Calling it again here
    // either has no effect or triggers RPC_E_CHANGED_MODE.
    RxConnectivityCheckerPlugin::RxConnectivityCheckerPlugin(
            flutter::TaskRunner* task_runner)
            : task_runner_(task_runner),
              alive_(std::make_shared<bool>(true)) {}

    RxConnectivityCheckerPlugin::~RxConnectivityCheckerPlugin() {
        *alive_ = false;
        StopListening();
    }

    void RxConnectivityCheckerPlugin::HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue> &method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        if (method_call.method_name().compare("getPlatformVersion") == 0) {
            // Return the real Windows version via RtlGetVersion.
            // GetVersionEx lies on Windows 10+ for processes without a manifest;
            // RtlGetVersion always returns the true build number.
            OSVERSIONINFOEXW osvi = {};
            osvi.dwOSVersionInfoSize = sizeof(osvi);

            auto* RtlGetVersion =
                    reinterpret_cast<NTSTATUS(WINAPI*)(LPOSVERSIONINFOEXW)>(
                            GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));

            std::ostringstream version_stream;
            version_stream << "Windows";
            if (RtlGetVersion && RtlGetVersion(&osvi) == 0) {
                version_stream << " " << osvi.dwMajorVersion
                               << "." << osvi.dwMinorVersion
                               << " (Build " << osvi.dwBuildNumber << ")";
            }
            result->Success(flutter::EncodableValue(version_stream.str()));
        } else {
            result->NotImplemented();
        }
    }

    void RxConnectivityCheckerPlugin::StartListening() {
        HRESULT hr = CoCreateInstance(
                CLSID_NetworkListManager,
                nullptr,
                CLSCTX_ALL,
                IID_PPV_ARGS(&network_list_manager_));

        if (FAILED(hr) || !network_list_manager_) {
            std::lock_guard<std::mutex> lock(sink_mutex_);
            if (event_sink_) {
                event_sink_->Error("COM_ERROR", "Failed to init NetworkListManager");
            }
            return;
        }

        // Emit the current connectivity state immediately on subscribe.
        NLM_CONNECTIVITY connectivity;
        if (SUCCEEDED(network_list_manager_->GetConnectivity(&connectivity))) {
            BroadcastStatus(connectivity);
        }

        // Subscribe to change events.
        Microsoft::WRL::ComPtr<IConnectionPointContainer> cpc;
        if (SUCCEEDED(network_list_manager_.As(&cpc))) {
            HRESULT hr_cp = cpc->FindConnectionPoint(
                    IID_INetworkListManagerEvents, &connection_point_);

            if (FAILED(hr_cp)) {
                // Propagate partial-init failures to the Dart side.
                std::lock_guard<std::mutex> lock(sink_mutex_);
                if (event_sink_) {
                    event_sink_->Error("COM_ERROR",
                            "Failed to find INetworkListManagerEvents connection point");
                }
                return;
            }

            std::weak_ptr<bool> weak_alive = alive_;
            auto* events = new NetworkManagerEvents(
                    [this, weak_alive](NLM_CONNECTIVITY c) {
                        // We are on a COM background thread here.
                        auto guard = weak_alive.lock();
                        if (!guard) return;  // plugin already gone

                        task_runner_->PostTask([this, weak_alive, c]() {
                            // Now on the Flutter platform thread.
                            auto g2 = weak_alive.lock();
                            if (!g2 || !*g2) return;
                            BroadcastStatus(c);
                        });
                    });

            HRESULT hr_adv = connection_point_->Advise(events, &cookie_);
            events->Release();  // connection_point_ holds the ref from here on

            if (FAILED(hr_adv)) {
                cookie_ = 0;
                std::lock_guard<std::mutex> lock(sink_mutex_);
                if (event_sink_) {
                    event_sink_->Error("COM_ERROR",
                            "Failed to subscribe to connectivity events");
                }
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

    std::string RxConnectivityCheckerPlugin::ConnectivityToString(
            NLM_CONNECTIVITY connectivity) {
        if (connectivity == NLM_CONNECTIVITY_DISCONNECTED) {
            return "lost";
        }
        if ((connectivity & NLM_CONNECTIVITY_IPV4_INTERNET) ||
            (connectivity & NLM_CONNECTIVITY_IPV6_INTERNET)) {
            return "available";
        }
        if ((connectivity & NLM_CONNECTIVITY_IPV4_LOCALNETWORK) ||
            (connectivity & NLM_CONNECTIVITY_IPV6_LOCALNETWORK) ||
            (connectivity & NLM_CONNECTIVITY_IPV4_SUBNET) ||
            (connectivity & NLM_CONNECTIVITY_IPV6_SUBNET)) {
            return "local_only";
        }
        return "capabilities_changed";
    }

    void RxConnectivityCheckerPlugin::BroadcastStatus(NLM_CONNECTIVITY connectivity) {
        // Must be called on the platform thread (guaranteed by PostTask in the
        // COM callback lambda). The mutex is still here as a belt-and-suspenders
        // guard around event_sink_ access.
        std::lock_guard<std::mutex> lock(sink_mutex_);
        if (!event_sink_) return;
        event_sink_->Success(
                flutter::EncodableValue(ConnectivityToString(connectivity)));
    }

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    RxConnectivityCheckerPlugin::OnListenInternal(
            const flutter::EncodableValue* arguments,
            std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
        {
            std::lock_guard<std::mutex> lock(sink_mutex_);
            event_sink_ = std::move(events);
        }
        StartListening();
        return nullptr;
    }

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    RxConnectivityCheckerPlugin::OnCancelInternal(
            const flutter::EncodableValue* arguments) {
        StopListening();
        std::lock_guard<std::mutex> lock(sink_mutex_);
        event_sink_ = nullptr;
        return nullptr;
    }

}  // namespace rx_connectivity_checker
