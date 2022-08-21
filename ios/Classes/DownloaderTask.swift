//
//  Task.swift
//  flutter-test
//
//  Created by Brandon Butler on 7/29/22.
//

import Foundation

enum DownloaderTaskStatus : Int {
    case undefined = 0
    case enqueued
    case running
    case completed
    case failed
    case canceled
    case paused
}

class DownloaderTask {
    
    internal init(id: String, taskId: String?, url: String, savedDir: String, fileName: String?, progress: Int, status: DownloaderTaskStatus, headers: String?, resumable: Bool, showNotification: Bool, openFileFromNotification: Bool/*, timeCreated: Date?*/) {
        self.id = id
        self.taskId = taskId
        self.url = url
        self.savedDir = savedDir
        filename = fileName
        self.progress = progress
        self.status = status
        self.headers = headers
        isResumable = resumable
        shouldShowNotification = showNotification
        shouldOpenFileFromNotification = openFileFromNotification
//        self.timeCreated = timeCreated
    }
    
    convenience init(withArgs args: [String : Any?]) {
        self.init(id: args["id"] as! String,
                  taskId: args["taskId"] as? String,
                  url: args["url"] as! String,
                  savedDir: args["savedDir"] as! String,
                  fileName: args["filename"] as? String,
                  progress: args["progress"] as! Int,
                  status: DownloaderTaskStatus(rawValue: args["status"] as! Int)!,
                  headers: args["headers"] as? String,
                                  resumable: false,
                  showNotification: false,
                  openFileFromNotification: false
//                  resumable: args["resumable"] as! Bool,
//                  showNotification: args["showNotification"] as! Bool,
//                  openFileFromNotification: args["openFileFromNotification"] as! Bool
        )
    }
    
    
    let id: String
    let url: String
    let savedDir: String
    let headers: String?
    let shouldShowNotification: Bool
    let shouldOpenFileFromNotification: Bool
    
    var taskId: String?
    var filename: String?
    var progress: Int
    var status: DownloaderTaskStatus
    var isResumable: Bool
//    let timeCreated: Date?
    
    var sessionTask: URLSessionDownloadTask? {
        get { return sessionTask }
        set(newTask) {
            if (filename == nil) {
                filename = newTask?.response?.suggestedFilename ?? newTask?.currentRequest?.url?.lastPathComponent;
            }
        }
    }
    
    var destinationUrl: URL? {
        get {
            if (filename == nil) {
                return nil
            }
            let savedDirUrl = URL(fileURLWithPath: savedDir)
            return savedDirUrl.appendingPathComponent(filename!)
        }
    }
    
    func deleteDestinationPath(debug: Bool = false)
    {
        guard let destinationUrl = destinationUrl else {
            if (debug) {
                print("download task is missing destination url")
            }
            return
        }
        if (FileManager.default.fileExists(atPath: destinationUrl.path)) {
            do {
                try FileManager.default.removeItem(at: destinationUrl)
            } catch {
                if (debug) {
                    print("Failed to delete \(destinationUrl.path): \(error).")
                }
            }
        }
    }
    
    
}

extension DownloaderTask {
    func toCreateArgs() -> [String: Any?] {
        [
            "taskId": taskId,
            "url": url,
            "savedDir": savedDir,
            "filename": filename,
            "progress": progress,
            "status": status.rawValue,
            "headers": headers,
            "isResumeable": isResumable,
            "shouldShowNotification": shouldShowNotification,
            "shouldOpenFileFromNotification": shouldOpenFileFromNotification
        ]
    }
        
    func toSetArgs() -> [String: Any?] {
        [
            "id": id,
            "taskId": taskId,
            "progress": progress,
            "status": status.rawValue,
            "filename": filename,
            "isResumeable": isResumable,
        ]
    }
}
