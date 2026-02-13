#include "rx_connectivity_checker_plugin.h"

// Make sure to include the implementation file here
#include "connectivity_stream_handler.h"
#include <flutter/standard_method_codec.h>
#include <memory>

// Register the plugin with the registrar
void RxConnectivityCheckerPlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarWindows* registrar) {
    auto plugin = std::make_unique<RxConnectivityCheckerPlugin>(registrar);
    registrar->AddPlugin(std::move(plugin));
}

// Constructor to initialize the plugin
RxConnectivityCheckerPlugin::RxConnectivityCheckerPlugin(flutter::PluginRegistrarWindows* registrar)
        : registrar_(registrar) {

    // Initialize MethodChannel
    method_channel_ =
            std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                    registrar_->messenger(), "rx_connectivity_checker",
                            &flutter::StandardMethodCodec::GetInstance());

    // Set the method call handler
    method_channel_->SetMethodCallHandler(
            [this](const auto& call, auto result) {
                this->HandleMethodCall(call, std::move(result));
            });

    // Initialize EventChannel
    event_channel_ =
            std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                    registrar_->messenger(), "rx_connectivity_checker_stream",
                            &flutter::StandardMethodCodec::GetInstance());

    // Initialize and set the stream handler
    stream_handler_ = std::make_unique<ConnectivityStreamHandler>();
    event_channel_->SetStreamHandler(std::move(stream_handler_));
}

// Destructor
RxConnectivityCheckerPlugin::~RxConnectivityCheckerPlugin() = default;

// Handle incoming method calls
void RxConnectivityCheckerPlugin::HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    // Implementation of your method calls goes here
    result->NotImplemented();
}
