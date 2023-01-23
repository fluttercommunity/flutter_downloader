import Flutter
import UIKit
import BackgroundTasks

private class Download: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
  private var finalSize: Int64?
  private var progress: Int64 = 0
  private var backChannel: FlutterMethodChannel
  private var url: String?
  private var headers = [String:String]()
  private let urlHash: String
  private var resumeData: Data?
  private var task: URLSessionDownloadTask?
  
  init(urlHash : String, with binaryMessenger : FlutterBinaryMessenger) throws {
    backChannel = FlutterMethodChannel(name: "fluttercommunity/flutter_downloader/\(urlHash)", binaryMessenger: binaryMessenger)
    self.urlHash = urlHash
    
    let metaFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(urlHash).meta")
    let rawData = try String(contentsOf: metaFile, encoding: .utf8)
    //print("Meta-File:")
    //print(rawData)
    let lines = rawData.components(separatedBy:"\n")
    var parseHeaders = false
    for line in lines {
      if line == "headers:" {
        parseHeaders = true
      } else {
        let parts = line.components(separatedBy:"=")
        let key = parts.first!
        let value = parts.last!
        //print("'\(key)'='\(value)\'")/*
        if parseHeaders {
          headers[key] = value
        } else if key == "url" && !value.isEmpty {
          url = value
          // I think those fields are not relevant for iOS:
          //} else if key == "filename" && !value.isEmpty {
          //  filename = value
          //} else if key == "etag" && !value.isEmpty {
          // etag = value
          //} else if key == "resumable" && !value.isEmpty {
          //  resumable = value == "true";
          //} else if key == "size" && !value.isEmpty {
          //  finalSize = int.parse(value);
        }
      }
    }
  }
  
  func resume() {
    let config = URLSessionConfiguration.background(withIdentifier: urlHash)
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
    task?.taskDescription = urlHash

    // now start the task
    task?.resume()
    
    self.updateStatus(status: "running")
  }
  
  func pause() {
    print("asked to pause")
    task?.cancel{ resumeDataOrNil in
      guard let resumeData = resumeDataOrNil else {
        print("failed to pause?")
        self.updateStatus(status: "canceled")
        return
      }
      self.resumeData = resumeData
      print("can continue!?")
      self.updateStatus(status: "paused")
    }
  }
  
  private func updateProgress(progress: Int64) {
    backChannel.invokeMethod("updateProgress", arguments: progress)
    //print("Update progress \(Double(progress) / 10.0)%")
  }
  
  private func updateStatus(status: String) {
    backChannel.invokeMethod("updateStatus", arguments: status)
    print("Update status: \(status)")
  }
  
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    if totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown {return}
    
    if finalSize == nil {
      backChannel.invokeMethod("updateSize", arguments: totalBytesExpectedToWrite)
      finalSize = totalBytesExpectedToWrite
    }
    
    let permill = (totalBytesWritten * 1000) / totalBytesExpectedToWrite
    
    // TODO prevent again double updates
    updateProgress(progress: permill)
    
    if permill == 1000 {
      updateStatus(status: "complete")
    }
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let error = error else {
      //print("err1")
      //self.updateStatus(status: "failed")
      return
    }
    let userInfo = (error as NSError).userInfo
    if let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
      print("can continue!?")
      self.resumeData = resumeData
      self.updateStatus(status: "paused")
    } else {
      print("err2")
      self.updateStatus(status: "failed")
    }
  }
  
  /// Process end of downloadTask sent by the urlSession.
  ///
  /// If successful, (over)write file to final destination per FlutterDownloadTask info
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    let urlHash = downloadTask.taskDescription!
    
    guard let response = downloadTask.response as? HTTPURLResponse
    else {
      print("Did not get HttpResponse")
      return}
    if response.statusCode == 200 || response.statusCode == 206 {
      updateStatus(status: "complete")
    } else {
      updateStatus(status: "failed")
    }
  }
}

public class SwiftFlutterDownloaderPlugin: NSObject, FlutterPlugin {
  private var downloads = [String:Download]()
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
    let urlHash = call.arguments as! String
    
    print("Resume download with hash \(urlHash)...")
    if downloads[urlHash] == nil {
      do {
        let download = try Download(urlHash: urlHash, with: SwiftFlutterDownloaderPlugin.binaryMessenger!)
        downloads[urlHash] = download
      } catch {
        // TODO handle errors...
        //updateStatus(urlHash: urlHash, status: "failed")
      }
    }
    downloads[urlHash]?.resume()

    result(nil)
  }
  
  private func pause(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let urlHash = call.arguments as! String
    print("Pause download with hash \(urlHash)...")
    downloads[urlHash]?.pause()
    
    result(nil)
  }
}
