import Flutter
import UIKit
import BackgroundTasks
import os.log

public class SwiftFlutterDownloaderPlugin: NSObject, FlutterPlugin, URLSessionDelegate, URLSessionDownloadDelegate {
  private var downloadSize = [String:Int64]()
  private var progress = [String:Int64]()
  private var backChannel = [String:FlutterMethodChannel]()
  private static var binaryMessenger : FlutterBinaryMessenger?;

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fluttercommunity/flutter_downloader", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterDownloaderPlugin()
    binaryMessenger = registrar.messenger()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private func getCacheDir(call: FlutterMethodCall, result: @escaping FlutterResult) {
    //let group = call.arguments as! String

    NSLog("Before\nAfter")
    let documentDirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path).first
    result(documentDirPath)
  }

  private func resume(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let urlHash = call.arguments as! String
    print("Resume download with hash \(urlHash)...")
    backChannel[urlHash] = FlutterMethodChannel(name: "fluttercommunity/flutter_downloader/\(urlHash)", binaryMessenger: SwiftFlutterDownloaderPlugin.binaryMessenger!)
    let config = URLSessionConfiguration.background(withIdentifier: urlHash)
    //config.timeoutIntervalForResource = Downloader.resourceTimeout
    let urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

    var request = URLRequest(url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!)

    let headers = [String:String]() //TODO read header files
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }
    let urlSessionDownloadTask = urlSession.downloadTask(with: request)
    urlSessionDownloadTask.taskDescription = urlHash

    // now start the task
    urlSessionDownloadTask.resume()
    print("Download started")

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

  private func updateProgress(urlHash: String, progress: Int64) {
    if self.progress[urlHash] != progress {
      self.progress[urlHash] = progress
      backChannel[urlHash]?.invokeMethod("updateProgress", arguments: progress)
      print("Update progress \(Double(progress) / 10.0)%")
    }
  }

  private func updateStatus(urlHash: String, status: String) {
    backChannel[urlHash]?.invokeMethod("updateStatus", arguments: status)
    print("Update status: \(status)")
  }

  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    if totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown {return}

    let urlHash = downloadTask.taskDescription!

    if downloadSize[urlHash] == nil {
      backChannel[urlHash]?.invokeMethod("updateSize", arguments: totalBytesExpectedToWrite)
      downloadSize[urlHash] = totalBytesExpectedToWrite
      progress[urlHash] = 0
    }

    let permill = (totalBytesWritten * 1000) / totalBytesExpectedToWrite

    updateProgress(urlHash: urlHash, progress: permill)

    if permill == 1000 {
      updateStatus(urlHash: urlHash, status: "complete")
    }
  }

  /// Process end of downloadTask sent by the urlSession.
  ///
  /// If successful, (over)write file to final destination per FlutterDownloadTask info
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    let urlHash = downloadTask.taskDescription!

    guard let response = downloadTask.response as? HTTPURLResponse
    else {
      //os_log("Could not find task associated with native id %d, or did not get HttpResponse", log: log,  type: .info, downloadTask.taskIdentifier)
      return}
    if response.statusCode == 200 || response.statusCode == 206 {
      updateStatus(urlHash: urlHash, status: "complete")
    } else {
      updateStatus(urlHash: urlHash, status: "failed")
    }
  }
}
