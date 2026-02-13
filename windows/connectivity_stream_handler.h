#pragma once

// C++ and WinRT headers
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Networking.Connectivity.h>
#include <winrt/Windows.System.Power.h>

// Flutter headers
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler.h>
#include <flutter/standard_method_codec.h>

// Standard library headers
#include <memory>
#include <mutex>

class ConnectivityStreamHandler
        : public flutter::EventStreamHandler<flutter::EncodableValue> {
public:
    ConnectivityStreamHandler();
    ~ConnectivityStreamHandler() override;

protected:
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListen(
            const flutter::EncodableValue* arguments,
            std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override;

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancel(
            const flutter::EncodableValue* arguments) override;

private:
    void StartMonitoring();
    void StopMonitoring();
    void EmitStatus(const std::string& status);
    std::string GetStatus();

    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
    std::mutex mutex_;

    // Tokens for event registration
    winrt::event_token network_token_{};
    winrt::event_token suspend_token_{};
};
