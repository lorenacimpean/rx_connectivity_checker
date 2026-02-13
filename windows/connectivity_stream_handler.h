#pragma once

#include <flutter/event_channel.h>
#include <flutter/encodable_value.h>
#include <memory>

class ConnectivityStreamHandler
        : public flutter::StreamHandler<flutter::EncodableValue> {
public:
    ConnectivityStreamHandler() = default;
    ~ConnectivityStreamHandler() override = default;

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListen(
            const flutter::EncodableValue* arguments,
            std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events) override;

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancel(
            const flutter::EncodableValue* arguments) override;

private:
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
};
