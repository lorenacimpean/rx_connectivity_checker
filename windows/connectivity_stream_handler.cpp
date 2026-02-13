#include "connectivity_stream_handler.h"

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
ConnectivityStreamHandler::OnListen(
        const flutter::EncodableValue* arguments,
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events) {
    event_sink_ = std::move(events);
    // TODO: send initial connectivity state if needed
    return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
ConnectivityStreamHandler::OnCancel(
        const flutter::EncodableValue* arguments) {
    event_sink_ = nullptr;
    return nullptr;
}
