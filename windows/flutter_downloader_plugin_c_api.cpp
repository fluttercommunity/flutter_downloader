#include "include/flutter_downloader/flutter_downloader_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_downloader_plugin.h"

void FlutterDownloaderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_downloader::FlutterDownloaderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
