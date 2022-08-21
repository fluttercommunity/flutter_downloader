//
//  FlutterDownloaderPlugin.swift
//  flutter-test
//
//  Created by Brandon Butler on 7/29/22.
//

import Foundation
import Flutter

public class FlutterDownloaderPlugin: NSObject {

    static private var debug = true
    static private var initialized = false;
    static private var step = 10
    static private var headlessRunner: FlutterEngine?
    static private var callbackHandle: Int64 = 0

    private var session: URLSession {
        let maxConcurrentTasks = Bundle.main.object(forInfoDictionaryKey: "FDMaximumConcurrentTasks") as? NSNumber ?? NSNumber(3)
        if (FlutterDownloaderPlugin.debug) {
            print("MAXIMUM_CONCURRENT_TASKS = \(maxConcurrentTasks)")
        }
        // session identifier needs to be the same for background download and resume to work
        let identifier = "\(Bundle.main.bundleIdentifier!).download.background.session"
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: identifier)
        sessionConfig.httpMaximumConnectionsPerHost = maxConcurrentTasks.intValue
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        if (FlutterDownloaderPlugin.debug) {
            print("init NSURLSession with id: \(session.configuration.identifier!)")
        }
        return session
    }

    private let allFilesDownloadedMsg: String

    public var backgroundTransferCompletionHandler: (() -> Void)?

    private let mainChannel: FlutterMethodChannel
    private let callbackChannel: FlutterMethodChannel
    private let registrar: FlutterPluginRegistrar
    private var tasks: [String: DownloaderTask] = [:]
//    private var eventQueue: []

    init(with registrar: FlutterPluginRegistrar) {

        if (FlutterDownloaderPlugin.headlessRunner == nil) {
            FlutterDownloaderPlugin.headlessRunner = FlutterEngine.init(name: "FlutterDownloaderIsolate", project: nil, allowHeadlessExecution: true)
        }

        self.registrar = registrar

        mainChannel = FlutterMethodChannel(name: "vn.hunghd/downloader", binaryMessenger: registrar.messenger())

        callbackChannel = FlutterMethodChannel(name: "vn.hunghd/downloader_background", binaryMessenger: FlutterDownloaderPlugin.headlessRunner!.binaryMessenger)

        allFilesDownloadedMsg = Bundle.main.object(forInfoDictionaryKey: "FDAllFilesDownloadedMessage") as? String ?? "All files have been downloaded"
        if (FlutterDownloaderPlugin.debug) {
            print("AllFilesDownloadedMessage: \(allFilesDownloadedMsg)")
        }

        super.init()

        defer {
            self.registrar.addMethodCallDelegate(self, channel: mainChannel)
        }
    }

    private func startBackgroundIsolate(handle: Int64) {
        if (FlutterDownloaderPlugin.debug) {
            print("\(#function)")
        }
        let info = FlutterCallbackCache.lookupCallbackInformation(handle)
        assert(info != nil, "failed to find callback")
        let entrypoint = info!.callbackName
        let uri = info!.callbackLibraryPath
        FlutterDownloaderPlugin.headlessRunner?.run(withEntrypoint: entrypoint, libraryURI: uri)
        assert(FlutterDownloaderPlugin.registerPlugins != nil, "failed to set registerPlugins")


        // Once our headless runner has been started, we need to register the application's plugins
        // with the runner in order for them to work on the background isolate. `registerPlugins` is
        // a callback set from AppDelegate.m in the main application. This callback should register
        // all relevant plugins (excluding those which require UI).
        FlutterDownloaderPlugin.registerPlugins!(FlutterDownloaderPlugin.headlessRunner!)
        registrar.addMethodCallDelegate(self, channel: callbackChannel)
    }

    private func initializeMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        guard let args = call.arguments as? Array<Any> else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments as a Array<Any>", details: nil))
            return
        }

        guard let handle = args[0] as? Int64 else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[0] as Long", details: nil))
            return
        }

        guard let shouldDebug = args[1] as? Bool else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[1] as Bool", details: nil))
            return
        }

        FlutterDownloaderPlugin.debug = shouldDebug
        startBackgroundIsolate(handle: handle)
        result(nil)
    }

    private func didInitializeDispatcherMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        FlutterDownloaderPlugin.initialized = true
        // unqueue if callback handler has been set
        if FlutterDownloaderPlugin.callbackHandle != 0 {
            // Todo: Implement This
//            unqueueStatusEvents()
        }
        result(nil)
    }

    private func registerCallbackMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        guard let args = call.arguments as? Array<Any> else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments as a Array<Any>", details: nil))
            return
        }

        guard let handle = args[0] as? Int64 else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[0] as Long", details: nil))
            return
        }

        guard let step = args[0] as? Int else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[1] as Int", details: nil))
            return
        }

        FlutterDownloaderPlugin.callbackHandle = handle
        FlutterDownloaderPlugin.step = step
        if (FlutterDownloaderPlugin.initialized) {
            // Todo: Implement This
//            unqueueStatusEvents()
        }
        initDatabase()
        result(nil)
    }

//    - (void) unqueueStatusEvents {

//        @synchronized (self) {
//            // unqueue all pending download status events.
//            while ([_eventQueue count] > 0) {
//                NSArray* args = _eventQueue[0];
//                [_eventQueue removeObjectAtIndex:0];
//                [_callbackChannel invokeMethod:@"" arguments:@[@(_callbackHandle), args[1], args[2], args[3]]];
//            }
//        }
//    }

    private func enqueueMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        guard let args = call.arguments as? Dictionary<String, Any> else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments as a Dictionary<String, Any>", details: nil))
            return
        }

        guard let urlString = args["url"] as? String else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"url\"] as String", details: nil))
            return
        }

        guard let savedDir = args["saved_dir"] as? String else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"saved_dir\"] as String", details: nil))
            return
        }

//        NSString *shortSavedDir = [self shortenSavedDirPath:savedDir];

//        guard let fileName = args["file_name"] as? String? else {
//            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"file_name\"] as String?", details: nil))
//            return
//        }

        let fileName = args["file_name"] as? String ?? nil;
        let headers = args["headers"] as? String ?? nil;

//        let headers: String? = args.keys.contains("headers") ? args["headers"] as? String : nil

        guard let shouldShowNotification = args["show_notification"] as? Bool else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"show_notification\"] as Bool", details: nil))
            return
        }

        guard let shouldOpenFileFromNotification = args["open_file_from_notification"] as? Bool else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"open_file_from_notification\"] as Bool", details: nil))
            return
        }

        enqueueDownloaderTask(urlString, fileName, savedDir, headers, shouldShowNotification, shouldOpenFileFromNotification)

        result(nil)
    }

    private func enqueueDownloaderTask(_ urlString: String, _ fileName: String?, _ savedDir: String, _ headers: String?, _ shouldShowNotification: Bool, _ shouldOpenFileFromNotification: Bool) {

        let sessionTask = sessionTask(withUrl: URL(string: urlString)!, headers: headers)

        let downloaderTask = DownloaderTask(id: "-1", taskId: String(sessionTask.taskIdentifier), url: urlString, savedDir: savedDir, fileName: fileName, progress: 0, status: .enqueued, headers: headers, resumable: false, showNotification: shouldShowNotification, openFileFromNotification: shouldOpenFileFromNotification)

        // trigger updating the filename based on the sessionTask
        downloaderTask.sessionTask = sessionTask

        createDownloaderTask(downloaderTask)

        sessionTask.resume()
    }

    private func sessionTask(withUrl url: URL, headers: String?) -> URLSessionDownloadTask {
        var request = URLRequest(url: url)
        if (headers?.count ?? 0 > 0) {
            let data = headers!.data(using: .utf8)
            do {
                if let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String: String?] {
                    for key in json.keys {
                        let value: String? = json[key] ?? nil
                        if (FlutterDownloaderPlugin.debug) {
                            print("Header(\(key): \(value)")
                        }
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                }
            } catch {
                if (FlutterDownloaderPlugin.debug) {
                    print("Failed to add headers to request")
                }
            }
        }
        return session.downloadTask(with: request)
    }

    private func cancelMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        guard let args = call.arguments as? Dictionary<String, Any> else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments as a Dictionary<String, Any>", details: nil))
            return
        }

        guard let taskId = args["taskId"] as? String else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"taskId\"] as Int", details: nil))
            return
        }

        getDownloaderTask(withTaskId: taskId) { [self] task in
            guard let task = task else {
                result(FlutterError.init(code: "invalid_task_id", message: "failed to get task with id \(taskId)", details: nil))
                return
            }
            cancelDownloaderTask(task)
            result(nil)
        }
    }

    private func cancelAllMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        cancelAllDownloaderTasks()
        result(nil)
    }

    private func pauseMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any> else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments as a Dictionary<String, Any>", details: nil))
            return
        }

        guard let taskId = args["taskId"] as? String else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"taskId\"] as Int", details: nil))
            return
        }

        getDownloaderTask(withTaskId: taskId) { [self] task in
            guard let task = task else {
                result(FlutterError.init(code: "invalid_task_id", message: "failed to get task with id \(taskId)", details: nil))
                return
            }
            pauseDownloaderTask(task)
            result(nil)
        }
    }

    private func resumeMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

    }

    private func retryMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any> else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments as a Dictionary<String, Any>", details: nil))
            return
        }

        guard let taskId = args["taskId"] as? String else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"taskId\"] as Int", details: nil))
            return
        }

        getDownloaderTask(withTaskId: taskId) { [self] task in
            guard let task = task else {
                result(FlutterError.init(code: "invalid_task_id", message: "failed to get task with id \(taskId)", details: nil))
                return
            }
            retryDownloaderTask(task)
            result(nil)
        }
    }

    private func openMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        guard let args = call.arguments as? Dictionary<String, Any> else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments as a Dictionary<String, Any>", details: nil))
            return
        }

        guard let taskId = args["taskId"] as? String else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"taskId\"] as Int", details: nil))
            return
        }

        getDownloaderTask(withTaskId: taskId) { [self] task in
            guard let task = task else {
                result(FlutterError.init(code: "invalid_task_id", message: "failed to get task with id \(taskId)", details: nil))
                return
            }

            if task.status != .completed {
                result(FlutterError.init(code: "invalid_status", message: "only tasks marked as completed can be opened", details: nil))
                return
            }

            guard let url = task.destinationUrl else {
                result(FlutterError.init(code: "invalid_task_filename", message: "task was missing file url", details: nil))
                return
            }

            let success = openDocument(withUrl: url)
            result(NSNumber(booleanLiteral: success))
        }
    }

    private func removeMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        guard let args = call.arguments as? Dictionary<String, Any> else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments as a Dictionary<String, Any>", details: nil))
            return
        }

        guard let taskId = args["task_id"] as? String else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"taskId\"] as Int", details: nil))
            return
        }

        guard let shouldDeleteContent = args["should_delete_content"] as? Bool else {
            result(FlutterError.init(code: "invalid_arguments", message: "failed to cast arguments[\"should_delete_content\"] as Bool", details: nil))
            return
        }

        getDownloaderTask(withTaskId: taskId) { [self] downloaderTask in

            guard let downloaderTask = downloaderTask else {
                result(FlutterError.init(code: "invalid_task_id", message: "failed to get task with id \(taskId)", details: nil))
                return
            }

            if (downloaderTask.status == .enqueued || downloaderTask.status == .running) {
                cancelDownloaderTask(downloaderTask)
                //used to call delete as well, not sure that is necessary as it happens below
            }

            deleteDownloaderTask(downloaderTask)

            if (shouldDeleteContent) {
                downloaderTask.deleteDestinationPath(debug: FlutterDownloaderPlugin.debug)
            }

            result(nil)
        }
    }

    private func createDownloaderTask(_ task: DownloaderTask) {
        callbackChannel.invokeMethod("createDownloaderTask", arguments: task.toCreateArgs())
    }

    private func initDatabase() {
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        callbackChannel.invokeMethod("initDatabase", arguments: [documentsDirectory])
    }

    private func getDownloaderTask(withTaskId taskId: String, onCompletion: @escaping (DownloaderTask?) -> ()) {
        callbackChannel.invokeMethod("getDownloaderTask", arguments: [taskId]) { result in

            guard let result = result as? [String: Any?] else {
                onCompletion(nil)
                return
            }

            let downloaderTask = DownloaderTask(withArgs: result)
            onCompletion(downloaderTask)
        }
    }

    private func getDownloaderTask(forSessionTask sessionTask: URLSessionTask, onCompletion: @escaping (DownloaderTask?) -> ()) {
        getDownloaderTask(withTaskId: String(sessionTask.taskIdentifier), onCompletion: onCompletion)
    }

    private func setDownloaderTask(_ task: DownloaderTask) {
        callbackChannel.invokeMethod("setDownloaderTask", arguments: [FlutterDownloaderPlugin.callbackHandle, task.toSetArgs()])
    }

    private func deleteDownloaderTask(_ task: DownloaderTask) {
        callbackChannel.invokeMethod("deleteDownloaderTask", arguments: String(task.id))
    }

    private func cancelDownloaderTask(_ task: DownloaderTask) {
        session.getTasksWithCompletionHandler { [self] dataTasks, uploadTasks, downloadTasks in
            if let downloadTask = downloadTasks.first(where: { downloadTask in
                return downloadTask.taskIdentifier == Int(task.id) && downloadTask.state == .running
            }) {
                downloadTask.cancel()
                task.status = .canceled
                task.progress = -1
                setDownloaderTask(task)
            }
        }
    }

    private func cancelAllDownloaderTasks() {
        session.getTasksWithCompletionHandler { [self] dataTasks, uploadTasks, downloadTasks in
            for sessionTask in downloadTasks {
                getDownloaderTask(forSessionTask: sessionTask) { [self] downloaderTask in
                    guard let downloaderTask = downloaderTask else {
                        return
                    }
                    sessionTask.cancel()
                    downloaderTask.status = .canceled
                    downloaderTask.progress = -1
                    setDownloaderTask(downloaderTask)
                }
            }
        }
    }

    private func calculateProgress(forBytesReceived totalBytesWritten: Int64, withExpectedBytesToReceive totalBytesExpectedToWrite: Int64) -> Int {
        Int(round(Double(totalBytesWritten * 100 / totalBytesExpectedToWrite)))
    }

    private func calculateProgress(forSessionTask sessionTask: URLSessionTask) -> Int {
        Int(calculateProgress(forBytesReceived: sessionTask.countOfBytesReceived, withExpectedBytesToReceive: sessionTask.countOfBytesExpectedToReceive))
    }

    private func pauseDownloaderTask(_ task: DownloaderTask) {
        session.getTasksWithCompletionHandler { [self] dataTasks, uploadTasks, downloadTasks in
            if let downloadTask = downloadTasks.first(where: { downloadTask in
                return downloadTask.taskIdentifier == Int(task.id) && downloadTask.state == .running
            }) {

                getDownloaderTask(forSessionTask: downloadTask) { [self] downloaderTask in
                    guard let downloaderTask = downloaderTask else {
                        return
                    }
                    let progress = calculateProgress(forSessionTask: downloadTask)

                    downloadTask.cancel { data in

                        guard let data = data else {
                            return
                        }

                        downloaderTask.deleteDestinationPath(debug: FlutterDownloaderPlugin.debug)

                        do {
                            try data.write(to: downloaderTask.destinationUrl!)
                            if (FlutterDownloaderPlugin.debug) {
                                print("saved partial downloaded data to a file: \(downloaderTask.destinationUrl!.path)")
                            }
                        } catch {
                            if (FlutterDownloaderPlugin.debug) {
                                print("failed to save partial downloaded data to a file: \(downloaderTask.destinationUrl?.path ?? "nil")")
                            }
                        }
                    }

                    downloaderTask.progress = progress
                    downloaderTask.status = .paused
                    downloaderTask.isResumable = true
                    setDownloaderTask(downloaderTask)
                }
            }
        }
    }

    private func retryDownloaderTask(_ task: DownloaderTask) {
        session.getTasksWithCompletionHandler { [self] dataTasks, uploadTasks, downloadTasks in
            if let downloadTask = downloadTasks.first(where: { downloadTask in
                return downloadTask.taskIdentifier == Int(task.id) && downloadTask.state == .running
            }) {
                getDownloaderTask(forSessionTask: downloadTask) { [self] downloaderTask in
                    guard let downloaderTask = downloaderTask else {
                        return
                    }
                    deleteDownloaderTask(downloaderTask)
                    enqueueDownloaderTask(downloaderTask.url, downloaderTask.filename, downloaderTask.savedDir, downloaderTask.headers, downloaderTask.shouldShowNotification, downloaderTask.shouldOpenFileFromNotification)
                }
            }
        }
    }

    private func openDocument(withUrl url: URL) -> Bool {
        if (FlutterDownloaderPlugin.debug) {
            print("trying to open file in url \(url)")
        }

        let tmpDocController = UIDocumentInteractionController(url: url)
        tmpDocController.delegate = self
        return tmpDocController.presentPreview(animated: true)
    }
}

extension FlutterDownloaderPlugin: FlutterPlugin {
    static var registerPlugins: FlutterPluginRegistrantCallback?

    public static func register(with registrar: FlutterPluginRegistrar) {
        registrar.addApplicationDelegate(FlutterDownloaderPlugin.init(with: registrar))
    }

    public static func setPluginRegistrantCallback(_ callback: @escaping FlutterPluginRegistrantCallback) {
        registerPlugins = callback
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        switch call.method {
        case "initialize":
            initializeMethodCall(call, result: result)
        case "didInitializeDispatcher":
            didInitializeDispatcherMethodCall(call, result: result)
        case "registerCallback":
            registerCallbackMethodCall(call, result: result)
        case "enqueue":
            enqueueMethodCall(call, result: result)
        case "cancel":
            cancelMethodCall(call, result: result)
        case "cancelAll":
            cancelAllMethodCall(call, result: result)
        case "pause":
            pauseMethodCall(call, result: result)
        case "resume":
            resumeMethodCall(call, result: result)
        case "retry":
            retryMethodCall(call, result: result)
        case "open":
            openMethodCall(call, result: result)
        case "remove":
            removeMethodCall(call, result: result)
        default:
            result(FlutterMethodNotImplemented);
        }
    }

    public func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) -> Bool {
        backgroundTransferCompletionHandler = completionHandler
        //TODO: setup background isolate in case the application is re-launched from background to handle download event
        return true
    }
}

extension FlutterDownloaderPlugin: URLSessionDownloadDelegate {

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {

        if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) {
            if (FlutterDownloaderPlugin.debug) {
                print("Unknown transfer size")
            }
            return
        }

        getDownloaderTask(forSessionTask: downloadTask) { [self] task in
            guard let task = task else {
                return
            }
            let progress = calculateProgress(forBytesReceived: totalBytesWritten, withExpectedBytesToReceive: totalBytesExpectedToWrite)

            if (task.progress == progress) {
                return
            }

            if (!(task.progress == 0 || task.progress > (task.progress + FlutterDownloaderPlugin.step) || task.progress == 100)) {
                return
            }

            task.status = .running
            task.progress = progress
            setDownloaderTask(task)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        guard let statusCode = (downloadTask.response as? HTTPURLResponse)?.statusCode else {
            print("Failed to get HTTP status code")
            return
        }

        if FlutterDownloaderPlugin.debug {
            print("\(#function) HTTP status code: \(statusCode)")
        }

        let isSuccess = (statusCode >= 200 && statusCode < 300)
        if (!isSuccess) {
            return
        }

        getDownloaderTask(forSessionTask: downloadTask) { [self] task in
            guard let task = task else {
                return
            }
            //        [_runningTaskById removeObjectForKey:taskId];

            task.deleteDestinationPath(debug: FlutterDownloaderPlugin.debug)

            do {
                try FileManager.default.copyItem(at: location, to: task.destinationUrl!)
            } catch {
                if (FlutterDownloaderPlugin.debug) {
                    print("Unable to copy temp file. Error: \(error)")
                }
                task.status = .failed
                task.progress = -1
                setDownloaderTask(task)
                return
            }

            task.status = .completed
            task.progress = 100
            setDownloaderTask(task)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        guard let statusCode = (task.response as? HTTPURLResponse)?.statusCode else {
            print("Failed to get HTTP status code")
            return
        }

        if FlutterDownloaderPlugin.debug {
            print("\(#function) HTTP status code: \(statusCode)")
        }

        let isSuccess = (statusCode >= 200 && statusCode < 300) || error != nil
        if (isSuccess) {
            return
        }

        if FlutterDownloaderPlugin.debug {
            let errorMessage = error != nil ? error?.localizedDescription : "\(statusCode)"
            print("Download completed with error: \(errorMessage ?? "Unknown Error")")
        }

        getDownloaderTask(forSessionTask: task) { [self] downloaderTask in

            guard let downloaderTask = downloaderTask else {
                return
            }

            if (downloaderTask.isResumable) {
                return
            }

            downloaderTask.progress = -1
            downloaderTask.status = error != nil ? (error! as NSError).code == -999 ? .canceled : .failed : .failed
            setDownloaderTask(downloaderTask)
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {

        if FlutterDownloaderPlugin.debug {
            print("\(#function)")
        }

        // Check if all download tasks have been finished.
        self.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in

            if (downloadTasks.count > 0) {
                return
            }

            if FlutterDownloaderPlugin.debug {
                print("All download tasks have been finished")
            }

            if (self.backgroundTransferCompletionHandler == nil) {
                return
            }

            // Copy locally the completion handler.
            let completionHandler = self.backgroundTransferCompletionHandler!

            // Make nil the backgroundTransferCompletionHandler.
            self.backgroundTransferCompletionHandler = nil

            OperationQueue.main.addOperation {
                // Call the completion handler to tell the system that there are no other background transfers.
                completionHandler()

                // Show a local notification when all downloads are over.
                let localNotification = UILocalNotification()
                localNotification.alertBody = self.allFilesDownloadedMsg
                UIApplication.shared.presentLocalNotificationNow(localNotification)
            }
        }

    }
}

extension FlutterDownloaderPlugin: UIDocumentInteractionControllerDelegate {

    public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return (UIApplication.shared.delegate?.window??.rootViewController)!
    }

    public func documentInteractionController(_ controller: UIDocumentInteractionController, willBeginSendingToApplication application: String?) {
        if !FlutterDownloaderPlugin.debug {
            return
        }
        print("Send the document to the app \(application ?? "unknown") ...")
    }

    public func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
        if !FlutterDownloaderPlugin.debug {
            return
        }
        print("Finished sending the document to the app \(application ?? "unknown") ...")
    }

    public func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        if !FlutterDownloaderPlugin.debug {
            return
        }
        print("Finished previewing the document")
    }
}
