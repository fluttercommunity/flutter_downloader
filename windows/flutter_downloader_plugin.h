#ifndef FLUTTER_PLUGIN_FLUTTER_DOWNLOADER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_DOWNLOADER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_downloader {

class FlutterDownloaderPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterDownloaderPlugin();

  virtual ~FlutterDownloaderPlugin();

  // Disallow copy and assign.
  FlutterDownloaderPlugin(const FlutterDownloaderPlugin&) = delete;
  FlutterDownloaderPlugin& operator=(const FlutterDownloaderPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_downloader

#endif  // FLUTTER_PLUGIN_FLUTTER_DOWNLOADER_PLUGIN_H_
