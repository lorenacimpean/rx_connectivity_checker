#include "connectivity_stream_handler.h"

// Called when Dart subscribes to the event stream
std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
ConnectivityStreamHandler::OnListen(
        const flutter::EncodableValue* arguments,
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events) {
    // Store the event sink for sending events later
    event_sink_ = std::move(events);

    // TODO: Initialize connectivity monitoring and send initial state if needed

    return nullptr; // No error
}

// Called when Dart cancels the event stream
std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
ConnectivityStreamHandler::OnCancel(
        const flutter::EncodableValue* arguments) {
    // Stop monitoring if needed
    event_sink_ = nullptr;
    return nullptr;
}
