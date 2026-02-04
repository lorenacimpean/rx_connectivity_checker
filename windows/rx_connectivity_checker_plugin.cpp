#include "rx_connectivity_checker_plugin.h"

#include <flutter/standard_method_codec.h>

using flutter::EncodableValue;

RxConnectivityCheckerPlugin::RxConnectivityCheckerPlugin() = default;

RxConnectivityCheckerPlugin::~RxConnectivityCheckerPlugin() = default;

void RxConnectivityCheckerPluginRegisterWithRegistrar(
        FlutterDesktopPluginRegistrarRef registrar) {

    auto plugin = std::make_unique<RxConnectivityCheckerPlugin>();

    // Method Channel
    plugin->method_channel_ =
            std::make_unique<flutter::MethodChannel<EncodableValue>>(
                    registrar->messenger(),
                            "rx_connectivity_checker",
                            &flutter::StandardMethodCodec::GetInstance());

    plugin->method_channel_->SetMethodCallHandler(
            [plugin_ptr = plugin.get()](auto&& call, auto&& result) {
                plugin_ptr->HandleMethodCall(call, std::move(result));
            });

    // Event Channel
    plugin->event_channel_ =
            std::make_unique<flutter::EventChannel<EncodableValue>>(
                    registrar->messenger(),
                            "rx_connectivity_checker/events",
                            &flutter::StandardMethodCodec::GetInstance());

    plugin->stream_handler_ =
            std::make_unique<ConnectivityStreamHandler>(
                    registrar->messenger());

    plugin->event_channel_->SetStreamHandler(
            std::move(plugin->stream_handler_));

    registrar->AddPlugin(std::move(plugin));
}

void RxConnectivityCheckerPlugin::HandleMethodCall(
        const flutter::MethodCall<EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {

    if (call.method_name() == "getPlatformVersion") {
        result->Success(EncodableValue("Windows"));
        return;
    }

    result->NotImplemented();
}
