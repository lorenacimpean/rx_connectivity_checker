using namespace winrt;
using namespace Windows::Networking::Connectivity;
using namespace Windows::System::Power;

ConnectivityStreamHandler::ConnectivityStreamHandler(
        flutter::BinaryMessenger* messenger)
        : messenger_(messenger) {}

ConnectivityStreamHandler::~ConnectivityStreamHandler() {
    StopMonitoring();
}

std::unique_ptr<
flutter::StreamHandlerError<flutter::EncodableValue>>
ConnectivityStreamHandler::OnListenInternal(
        const flutter::EncodableValue*,
        std::unique_ptr<
        flutter::EventSink<flutter::EncodableValue>>&& events) {

    std::lock_guard lock(mutex_);

    event_sink_ = std::move(events);

    StartMonitoring();
    EmitStatus();

    return nullptr;
}

std::unique_ptr<
flutter::StreamHandlerError<flutter::EncodableValue>>
ConnectivityStreamHandler::OnCancelInternal(
        const flutter::EncodableValue*) {

    std::lock_guard lock(mutex_);

    StopMonitoring();
    event_sink_.reset();

    return nullptr;
}

void ConnectivityStreamHandler::StartMonitoring() {

    try {
        auto profile = NetworkInformation::GetInternetConnectionProfile();

        network_token_ =
                NetworkInformation::NetworkStatusChanged(
                        [this](auto&&) {
                            EmitStatus();
                        });

        suspend_token_ =
                PowerManager::Suspending(
                        [this](auto&&, auto&&) {
                            EmitStatus();
                        });
    }
    catch (...) {
        // Silently ignore WinRT failures
    }
}

void ConnectivityStreamHandler::StopMonitoring() {

    try {
        if (network_token_.value) {
            NetworkInformation::NetworkStatusChanged(network_token_);
            network_token_ = {};
        }

        if (suspend_token_.value) {
            PowerManager::Suspending(suspend_token_);
            suspend_token_ = {};
        }
    }
    catch (...) {
    }
}

void ConnectivityStreamHandler::EmitStatus() {

    std::lock_guard lock(mutex_);

    if (!event_sink_) {
        return;
    }

    const auto status = GetStatus();

    event_sink_->Success(
            flutter::EncodableValue(status));
}

std::string ConnectivityStreamHandler::GetStatus() {

    try {
        auto profile =
                NetworkInformation::GetInternetConnectionProfile();

        if (!profile) {
            return "none";
        }

        if (profile.GetNetworkConnectivityLevel() ==
                NetworkConnectivityLevel::InternetAccess) {
            return "connected";
        }

        return "limited";
    }
    catch (...) {
        return "unknown";
    }
}
