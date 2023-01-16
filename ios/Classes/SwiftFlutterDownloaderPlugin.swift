import Flutter
import UIKit
import BackgroundTasks
import os.log

public class SwiftFlutterDownloaderPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fluttercommunity/flutter_downloader", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterDownloaderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private func getCacheDir(call: FlutterMethodCall, result: @escaping FlutterResult) {
    //let group = call.arguments as! String
    let documentDirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path).first
    result(documentDirPath)
  }

  private func resume(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let urlHash = call.arguments as! String
    os_log("urlHash with %@", log: log, type: .debug, urlHash)

    result(nil)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    //os_log("Method call %@", log: log, type: .debug, call.method)
    switch call.method {
      case "getCacheDir":
        getCacheDir(call: call, result: result)
      case "resume":
        resume(call: call, result: result)
      case "pause":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
    }
  }
}
