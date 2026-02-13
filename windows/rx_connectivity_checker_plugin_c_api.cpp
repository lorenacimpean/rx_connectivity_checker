#include "rx_connectivity_checker/windows_rx_connectivity_checker.h"

#include <flutter/plugin_registrar_windows.h>

#include "rx_connectivity_checker_plugin.h"

void RxConnectivityCheckerPluginCApiRegisterWithRegistrar(
        FlutterDesktopPluginRegistrarRef registrar) {
    rx_connectivity_checker::RxConnectivityCheckerPlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarManager::GetInstance()
                    ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}