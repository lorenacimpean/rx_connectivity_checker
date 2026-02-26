//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <rx_connectivity_checker/linux_rx_connectivity_checker.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) rx_connectivity_checker_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "LinuxRxConnectivityChecker");
  linux_rx_connectivity_checker_register_with_registrar(rx_connectivity_checker_registrar);
}
