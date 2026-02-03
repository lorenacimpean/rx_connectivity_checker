#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/standard_method_codec.h>
#include <memory>

namespace rx_connectivity_checker {

    class ConnectivityStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
    public:
        ConnectivityStreamHandler() = default;
        virtual ~ConnectivityStreamHandler() = default;

        /// Called when a client starts listening to the EventChannel.
        ///
        /// - [arguments]: Optional arguments passed from Dart when subscribing.
        /// - [events]: The EventSink used to send events back to Dart.
        ///
        /// Returns nullptr on success, or a StreamHandlerError on failure.
        std::unique_ptr<flutter::StreamHandlerError> OnListen(
                const flutter::EncodableValue* arguments,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
            // Store the sink to send events later
            event_sink_ = std::move(events);

            // Optional: send initial connectivity state
            if (event_sink_) {
                flutter::EncodableValue initial_value("connected"); // example
                event_sink_->Success(initial_value);
            }

            return nullptr; // nullptr = success
        }

        /// Called when a client cancels their subscription to the EventChannel.
        ///
        /// - [arguments]: Optional arguments passed from Dart when canceling.
        ///
        /// Returns nullptr on success, or a StreamHandlerError on failure.
        std::unique_ptr<flutter::StreamHandlerError> OnCancel(
                const flutter::EncodableValue* arguments) override {
            // Release the sink
            event_sink_ = nullptr;
            return nullptr;
        }

    private:
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
    };

} // namespace rx_connectivity_checker
