#import "FlutterDownloaderPlugin.h"

#define STATUS_UNDEFINED 0
#define STATUS_ENQUEUED 1
#define STATUS_RUNNING 2
#define STATUS_COMPLETE 3
#define STATUS_FAILED 4
#define STATUS_CANCELED 5

#define KEY_URL @"url"
#define KEY_SAVED_DIR @"saved_dir"
#define KEY_FILE_NAME @"file_name"
#define KEY_PROGRESS @"progress"
#define KEY_ID @"id"
#define KEY_IDS @"ids"
#define KEY_TASK_ID @"task_id"
#define KEY_STATUS @"status"

#define STEP_UPDATE 10

@interface FlutterDownloaderPlugin()<NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>
{
    FlutterMethodChannel *_flutterChannel;
    NSURLSession *_session;
    NSMutableDictionary<NSNumber *, NSMutableDictionary *> *_downloadInfo;
}

@end

@implementation FlutterDownloaderPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {

    FlutterDownloaderPlugin* instance = [[FlutterDownloaderPlugin alloc] initWithBinaryMessenger:registrar.messenger];
    [registrar addMethodCallDelegate:instance channel:[instance channel]];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"methodCallHandler: %@", call.method);
    if ([@"enqueue" isEqualToString:call.method]) {
        NSString *urlString = call.arguments[KEY_URL];
        NSString *savedDir = call.arguments[KEY_SAVED_DIR];
        NSString *fileName = call.arguments[KEY_FILE_NAME];

        NSURLSessionDownloadTask *task = [self downloadTaskWithURL:[NSURL URLWithString:urlString] fileName:fileName andSavedDir:savedDir];
        NSString *taskId = [@(task.taskIdentifier) stringValue];
        [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_ENQUEUED) andProgress:@0];
        result(taskId);
    } else if ([@"loadTasks" isEqualToString:call.method]) {
        NSArray *ids = call.arguments[KEY_IDS];
        [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
            NSMutableArray *tasks = [NSMutableArray new];
            for (NSURLSessionDownloadTask *download in downloads) {
                NSNumber *taskIdentifier = @(download.taskIdentifier);
                if (![ids containsObject:[taskIdentifier stringValue]]) {
                    continue;
                }
                int64_t bytesReceived = download.countOfBytesReceived;
                int64_t bytesExpectedToReceive = download.countOfBytesExpectedToReceive;
                NSError *error = download.error;
                int progress = round(bytesReceived * 100 / bytesExpectedToReceive);
                int status;
                NSURLSessionTaskState state = download.state;
                if (state == NSURLSessionTaskStateRunning) {
                    status = STATUS_RUNNING;
                } else if (state == NSURLSessionTaskStateCompleted) {
                    if (error != nil) {
                        status = STATUS_FAILED;
                    } else {
                        status = STATUS_COMPLETE;
                    }
                } else {
                    status = STATUS_UNDEFINED;
                }
                [tasks addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                  [taskIdentifier stringValue], KEY_TASK_ID,
                                  @(status), KEY_STATUS,
                                  @(progress), KEY_PROGRESS, nil]];
            };
            result(tasks);
        }];
    } else if ([@"cancel" isEqualToString:call.method]) {
       NSString *taskId = call.arguments[KEY_TASK_ID];
       [self cancelTaskWithId:taskId];
    } else if ([@"cancelAll" isEqualToString:call.method]) {
       [self cancelAllTask];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (instancetype)initWithBinaryMessenger: (NSObject<FlutterBinaryMessenger>*) messenger;
{
    if (self = [super init]) {
        _flutterChannel = [FlutterMethodChannel
                                methodChannelWithName:@"vn.hunghd/downloader"
                                binaryMessenger:messenger];

        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[NSString stringWithFormat:@"%@.download.background", NSBundle.mainBundle.bundleIdentifier]];
        sessionConfiguration.HTTPMaximumConnectionsPerHost = 5;
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];

        _downloadInfo = [NSMutableDictionary new];
    }

    return self;
}

-(FlutterMethodChannel *)channel {
    return _flutterChannel;
}

- (NSURLSession*)currentSession {
    return _session;
}

- (NSURLSessionDownloadTask*)downloadTaskWithURL: (NSURL*) url fileName: (NSString*) fileName andSavedDir: (NSString*) savedDir
{
    NSURLSessionDownloadTask *task = [_session downloadTaskWithURL:url];
    NSNumber *taskId = @(task.taskIdentifier);
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 taskId, KEY_ID,
                                 url, KEY_URL,
                                 savedDir, KEY_SAVED_DIR,
                                 fileName, KEY_FILE_NAME,
                                 @(0), KEY_PROGRESS,
                                 nil];
    _downloadInfo[taskId] = info;
    [task resume];

    return task;
}

- (void)cancelTaskWithId: (NSString*)taskId
{
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            NSNumber *taskIdentifier = @(download.taskIdentifier);
            if ([taskId isEqualToString:[taskIdentifier stringValue]] && (state == NSURLSessionTaskStateRunning)) {
                [download cancel];
            }
        };
    }];
}

- (void)cancelAllTask {
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            if (state == NSURLSessionTaskStateRunning) {
                [download cancel];
            }
        };
    }];
}

- (void)sendUpdateProgressForTaskId: (NSString*)taskId inStatus: (NSNumber*) status andProgress: (NSNumber*) progress
{
    NSDictionary *info = @{KEY_TASK_ID: taskId,
                           KEY_STATUS: status,
                           KEY_PROGRESS: progress};
    [_flutterChannel invokeMethod:@"updateProgress" arguments:info];
}

# pragma NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) {
        NSLog(@"Unknown transfer size");
    } else {
        NSInteger taskId = downloadTask.taskIdentifier;
        int progress = round(totalBytesWritten * 100 / (double)totalBytesExpectedToWrite);
        NSMutableDictionary *info = _downloadInfo[@(taskId)];
        NSNumber *lastProgress = info[KEY_PROGRESS];
        if (([lastProgress intValue] == 0 || (progress > [lastProgress intValue] + STEP_UPDATE) || progress == 100) && progress != [lastProgress intValue]) {
            info[KEY_PROGRESS] = @(progress);
            [self sendUpdateProgressForTaskId:[@(taskId) stringValue] inStatus:@(STATUS_RUNNING) andProgress:@(progress)];
        }
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSNumber *taskId = @(downloadTask.taskIdentifier);
    NSDictionary *info = _downloadInfo[taskId];
    NSString *savedDir = info[KEY_SAVED_DIR];
    NSString *fileName = info[KEY_FILE_NAME];

    NSString *destinationFilename;
    if ([fileName isEqual:[NSNull null]]) {
        destinationFilename = downloadTask.originalRequest.URL.lastPathComponent;
    } else {
        destinationFilename = fileName;
    }
    NSURL *savedDirURL = [NSURL fileURLWithPath:savedDir];
    NSURL *destinationURL = [savedDirURL URLByAppendingPathComponent:destinationFilename];

    if ([fileManager fileExistsAtPath:[destinationURL path]]) {
        [fileManager removeItemAtURL:destinationURL error:nil];
    }

    BOOL success = [fileManager copyItemAtURL:location
                                        toURL:destinationURL
                                        error:&error];

    if (success) {
        [self sendUpdateProgressForTaskId:[taskId stringValue] inStatus:@(STATUS_COMPLETE) andProgress:@100];
    } else {
        NSLog(@"Unable to copy temp file. Error: %@", [error localizedDescription]);
        [self sendUpdateProgressForTaskId:[taskId stringValue] inStatus:@(STATUS_FAILED) andProgress:@0];
    }
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error != nil) {
        NSLog(@"Download completed with error: %@", [error localizedDescription]);
        int status = [error code] == -999 ? STATUS_CANCELED : STATUS_FAILED;
        [self sendUpdateProgressForTaskId:[@(task.taskIdentifier) stringValue] inStatus:@(status) andProgress:@0];
    }
}

@end
