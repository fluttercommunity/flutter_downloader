import Flutter
import UIKit
import BackgroundTasks

private enum DownloadStatus {
  case running
  case completed
  case failed
  case canceled
  case paused
}

private class IosDownload: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
  /// The cache file of the (partial) download
  private var contentLength: Int64?
  private var progress: Int64 = 0
  private var lastProgress: Int64 = -1
  private var backChannel: FlutterMethodChannel
  private var url: String?
  private var headers = [String:String]()
  private let id: String
  private var resumeData: Data?
  private var task: URLSessionDownloadTask?
  
  init(id : String, with binaryMessenger : FlutterBinaryMessenger) throws {
    backChannel = FlutterMethodChannel(name: "fluttercommunity/flutter_downloader/\(id)", binaryMessenger: binaryMessenger)
    self.id = id

    /// Parse meta file
    let metaFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(id).meta")
    let partFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(id).part")
    let metaData = try Data(contentsOf: metaFile, options: .mappedIfSafe)
    let metaJson = try JSONSerialization.jsonObject(with: metaData, options: .mutableLeaves)
    if let metaDict = metaJson as? Dictionary<String, AnyObject>, let metaUrl = metaDict["url"] as? String, let headers = metaDict["headers"] as? Dictionary<String, String> {
      url = metaUrl
      print("UA: \(headers["User-Agent"])")
    }
      resumeData = try Data(contentsOf: partFile, options: .mappedIfSafe)
  }
  
  func resume() {
    let config = URLSessionConfiguration.background(withIdentifier: id)
    //config.timeoutIntervalForResource = Downloader.resourceTimeout
    let urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    
    if resumeData == nil {
      print("Start download of \(url!)...")
      
      var request = URLRequest(url: URL(string: url!)!)
      
      for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
      }
      task = urlSession.downloadTask(with: request)
    } else {
      print("Resume download...")
      task = urlSession.downloadTask(withResumeData: resumeData!)
    }
    task?.taskDescription = id

    // now start the task
    task?.resume()
    
    self.updateStatus(status: .running)
  }
  
  func pause() {
    print("asked to pause")
    task?.cancel{ resumeDataOrNil in
      guard let resumeData = resumeDataOrNil else {
        print("failed to pause")
        self.updateStatus(status: .canceled)
        return
      }
      self.resumeData = resumeData
      let partFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(self.id).part")
      do {
        try resumeData.write(to: partFile)
        self.updateStatus(status: .paused)
      } catch {
        print("Could not safe progress")
        self.updateStatus(status: .canceled)
      }
    }
  }
  
  private func updateProgress(progress: Int64) {
    if lastProgress != progress {
      lastProgress = progress
      backChannel.invokeMethod("updateProgress", arguments: progress)
    }
  }
  
  private func updateStatus(status: DownloadStatus) {
    backChannel.invokeMethod("updateStatus", arguments: "\(status)")
  }
  
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    if totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown {return}
    
    if contentLength == nil {
      backChannel.invokeMethod("updateSize", arguments: totalBytesExpectedToWrite)
      contentLength = totalBytesExpectedToWrite
    }
    
    let permill = (totalBytesWritten * 1000) / totalBytesExpectedToWrite
    
    updateProgress(progress: permill)
    
    if permill == 1000 {
      updateStatus(status: .completed)
    }
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let error = error else {return}
    let userInfo = (error as NSError).userInfo
    if let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
      self.resumeData = resumeData
      self.updateStatus(status: .paused)
    } else {
      self.updateStatus(status: .failed)
    }
  }
  
  /// Process end of downloadTask sent by the urlSession.
  ///
  /// If successful, (over)write file to final destination per FlutterDownloadTask info
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let response = downloadTask.response as? HTTPURLResponse
    else {
      print("Did not get HttpResponse")
      return}
    if response.statusCode == 200 || response.statusCode == 206 {
      updateStatus(status: .completed)
        print("Written to \(location)")
    } else {
      updateStatus(status: .failed)
    }
  }
}

public class SwiftFlutterDownloaderPlugin: NSObject, FlutterPlugin {
  private var downloads = [String:IosDownload]()
  private static var binaryMessenger : FlutterBinaryMessenger?;
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fluttercommunity/flutter_downloader", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterDownloaderPlugin()
    binaryMessenger = registrar.messenger()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCacheDir":
      getCacheDir(call: call, result: result)
    case "resume":
      resume(call: call, result: result)
    case "pause":
      pause(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getCacheDir(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let documentDirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).map(\.path).first
    result(documentDirPath)
  }
  
  private func resume(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let id = call.arguments as! String
    
    print("Resume download with id \(id)...")
    if downloads[id] == nil {
      do {
        let download = try IosDownload(id: id, with: SwiftFlutterDownloaderPlugin.binaryMessenger!)
        downloads[id] = download
      } catch {
        //self.updateStatus(status: DownloadStatus.failed)
      }
    }
    downloads[id]?.resume()

    result(nil)
  }
  
  private func pause(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let id = call.arguments as! String
    print("Pause download with id \(id)...")
    downloads[id]?.pause()
    
    result(nil)
  }
}

struct DownloadMetadata: Codable {
  // The url to download
  var url: String

  // The filename which should be used for the filesystem
  //var filename: String?

  // The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag), if given, to resume the download
  //var etag: String?

  // The target of the download
  //var target: DownloadTarget

  // The final file size of the file to download
  //var contentLength: Int?

  // The request headers
  //var headers: Dictionary<String, String>

  //required init(from decoder:Decoder) throws {
  //  let values = try decoder.container(keyedBy: CodingKeys.self)
  //  indexPath = try values.decode([Int].self, forKey: .indexPath)
  //  locationInText = try values.decode(Int.self, forKey: .locationInText)
}