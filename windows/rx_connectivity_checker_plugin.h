#pragma once

#include <flutter/event_channel.h>#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

// Forward-declare the class instead of including the header
// This breaks the circular dependency.
class ConnectivityStreamHandler;

class RxConnectivityCheckerPlugin : public flutter::Plugin {
public:
    static void RegisterWithRegistrar(
            flutter::PluginRegistrarWindows* registrar);

    explicit RxConnectivityCheckerPlugin(flutter::PluginRegistrarWindows* registrar);
    ~RxConnectivityCheckerPlugin() override;

private:
    void HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue>& call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // Keep a pointer to the registrar
    flutter::PluginRegistrarWindows* registrar_;

    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
            method_channel_;

    std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
            event_channel_;

    std::unique_ptr<ConnectivityStreamHandler>
            stream_handler_;
};
