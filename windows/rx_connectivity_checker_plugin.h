#ifndef FLUTTER_PLUGIN_RX_CONNECTIVITY_CHECKER_PLUGIN_H_
#define FLUTTER_PLUGIN_RX_CONNECTIVITY_CHECKER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace rx_connectivity_checker {

class RxConnectivityCheckerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  RxConnectivityCheckerPlugin();

  virtual ~RxConnectivityCheckerPlugin();

  // Disallow copy and assign.
  RxConnectivityCheckerPlugin(const RxConnectivityCheckerPlugin&) = delete;
  RxConnectivityCheckerPlugin& operator=(const RxConnectivityCheckerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace rx_connectivity_checker

#endif  // FLUTTER_PLUGIN_RX_CONNECTIVITY_CHECKER_PLUGIN_H_
