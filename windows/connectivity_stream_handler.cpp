#include "connectivity_stream_handler.h"

#include <flutter/fml/logging.h>

using namespace winrt;
using namespace Windows::Networking::Connectivity;
using namespace Windows::System::Power;
using flutter::EncodableValue;

// ------------------------------------------------------------
// Constructor / Destructor
// ------------------------------------------------------------

ConnectivityStreamHandler::ConnectivityStreamHandler(
        std::shared_ptr<flutter::BinaryMessenger> messenger)
        : messenger_(std::move(messenger)) {

    // Initialize COM / WinRT apartment (required)
    winrt::init_apartment(winrt::apartment_type::single_threaded);
}

ConnectivityStreamHandler::~ConnectivityStreamHandler() {
    StopMonitoring();
}

// ------------------------------------------------------------
// Stream Lifecycle
// ------------------------------------------------------------

std::unique_ptr<flutter::StreamHandlerError<EncodableValue>>
ConnectivityStreamHandler::OnListenInternal(
        const EncodableValue*,
        std::unique_ptr<flutter::EventSink<EncodableValue>>&& events) {

    {
        std::lock_guard<std::mutex> lock(mutex_);
        event_sink_ = std::move(events);
    }

    StartMonitoring();

    // Emit initial state
    EmitStatus();

#ifndef NDEBUG
    FML_LOG(INFO) << "Connectivity stream started";
#endif

    return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<EncodableValue>>
ConnectivityStreamHandler::OnCancelInternal(
        const EncodableValue*) {

    StopMonitoring();

    {
        std::lock_guard<std::mutex> lock(mutex_);
        event_sink_.reset();
    }

#ifndef NDEBUG
    FML_LOG(INFO) << "Connectivity stream stopped";
#endif

    return nullptr;
}

// ------------------------------------------------------------
// Monitoring Control
// ------------------------------------------------------------

void ConnectivityStreamHandler::StartMonitoring() {

    StopMonitoring();

    // Weak reference for lifetime safety
    auto weak = weak_from_this();

    network_token_ =
            NetworkInformation::NetworkStatusChanged(
                    [weak](auto&&) {

                        if (auto self = weak.lock()) {
                            self->EmitStatus();
                        }
                    });

    suspend_token_ =
            PowerManager::SuspendStateChanged(
                    [weak](auto&&, auto&&) {

                        if (auto self = weak.lock()) {
                            self->EmitStatus();
                        }
                    });
}

void ConnectivityStreamHandler::StopMonitoring() {

    std::lock_guard<std::mutex> lock(mutex_);

    if (network_token_.value) {
        NetworkInformation::NetworkStatusChanged(network_token_);
        network_token_.value = 0;
    }

    if (suspend_token_.value) {
        PowerManager::SuspendStateChanged(suspend_token_);
        suspend_token_.value = 0;
    }
}

// ------------------------------------------------------------
// Status Handling
// ------------------------------------------------------------

void ConnectivityStreamHandler::EmitStatus() {

    const auto status = GetStatus();

    PostToUI(status);
}

std::string ConnectivityStreamHandler::GetStatus() {

    auto profile =
            NetworkInformation::GetInternetConnectionProfile();

    if (!profile) {
        return "unavailable";
    }

    const auto level =
            profile.GetNetworkConnectivityLevel();

    switch (level) {

        case NetworkConnectivityLevel::InternetAccess:
            return "available";

        case NetworkConnectivityLevel::ConstrainedInternetAccess:
            return "losing";

        case NetworkConnectivityLevel::LocalAccess:
            return "capabilities_changed";

        default:
            return "lost";
    }
}

// ------------------------------------------------------------
// UI Thread Dispatch
// ------------------------------------------------------------

void ConnectivityStreamHandler::PostToUI(std::string status) {

    flutter::EventSink<EncodableValue>* sink = nullptr;
    std::shared_ptr<flutter::BinaryMessenger> messenger;

    {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!event_sink_ || !messenger_) {
            return;
        }

        sink = event_sink_.get();
        messenger = messenger_;
    }

    messenger->PostTask(
            [sink, status = std::move(status)]() {

                try {

                    sink->Success(EncodableValue(status));

#ifndef NDEBUG
                    FML_LOG(INFO)
                            << "Connectivity event: " << status;
#endif

                } catch (...) {

                    FML_LOG(ERROR)
                            << "Failed to emit connectivity event";
                }
            });
}
