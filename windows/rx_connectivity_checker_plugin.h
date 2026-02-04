#pragma once

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

#include "connectivity_stream_handler.h"

class RxConnectivityCheckerPlugin : public flutter::Plugin {
public:
    static void RegisterWithRegistrar(
            flutter::PluginRegistrarWindows* registrar);

    RxConnectivityCheckerPlugin();
    ~RxConnectivityCheckerPlugin() override;

private:
    void HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue>& call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
            method_channel_;

    std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
            event_channel_;

    std::unique_ptr<ConnectivityStreamHandler>
            stream_handler_;
};
