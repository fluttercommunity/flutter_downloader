#import "FlutterDownloaderPlugin.h"
#import "DBManager.h"

#define STATUS_UNDEFINED 0
#define STATUS_ENQUEUED 1
#define STATUS_RUNNING 2
#define STATUS_COMPLETE 3
#define STATUS_FAILED 4
#define STATUS_CANCELED 5
#define STATUS_PAUSED 6

#define KEY_URL @"url"
#define KEY_SAVED_DIR @"saved_dir"
#define KEY_FILE_NAME @"file_name"
#define KEY_PROGRESS @"progress"
#define KEY_ID @"id"
#define KEY_IDS @"ids"
#define KEY_TASK_ID @"task_id"
#define KEY_STATUS @"status"
#define KEY_HEADERS @"headers"
#define KEY_RESUMABLE @"resumable"

#define STEP_UPDATE 10

@interface FlutterDownloaderPlugin()<NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>
{
    FlutterMethodChannel *_flutterChannel;
    NSURLSession *_session;
    NSMutableDictionary<NSString *, NSMutableDictionary *> *_downloadInfo;
    DBManager *_dbManager;
}

@end

@implementation FlutterDownloaderPlugin

static int maximumConcurrentTask;

+ (int)maximumConcurrentTask {
    @synchronized(self) {
        return maximumConcurrentTask;
    }
}

+ (void)setMaximumConcurrentTask:(int)val {
    @synchronized(self) {
        maximumConcurrentTask = val;
    }
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {

    FlutterDownloaderPlugin* instance = [[FlutterDownloaderPlugin alloc] initWithBinaryMessenger:registrar.messenger];
    [registrar addMethodCallDelegate:instance channel:[instance channel]];
    [registrar addApplicationDelegate: instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"methodCallHandler: %@", call.method);
    if ([@"enqueue" isEqualToString:call.method]) {
        NSString *urlString = call.arguments[KEY_URL];
        NSString *savedDir = call.arguments[KEY_SAVED_DIR];
        NSString *fileName = call.arguments[KEY_FILE_NAME];
        NSString *headers = call.arguments[KEY_HEADERS];

        NSString *taskId = [self downloadTaskWithURL:[NSURL URLWithString:urlString] fileName:fileName andSavedDir:savedDir andHeaders:headers];

        __weak id weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
           [weakSelf addNewTask:taskId url:urlString status:STATUS_ENQUEUED progress:0 filename:fileName savedDir:savedDir resumable:NO];
           [weakSelf sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_ENQUEUED) andProgress:@0];
        });
        result(taskId);
    } else if ([@"loadTasks" isEqualToString:call.method]) {
        __weak id weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
           NSArray* tasks = [weakSelf loadAllTasks];
           result(tasks);
        });
    } else if ([@"cancel" isEqualToString:call.method]) {
       NSString *taskId = call.arguments[KEY_TASK_ID];
       [self cancelTaskWithId:taskId];
       result([NSNull null]);
    } else if ([@"cancelAll" isEqualToString:call.method]) {
       [self cancelAllTasks];
       result([NSNull null]);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void) addNewTask: (NSString*) taskId url: (NSString*) url status: (int) status progress: (int) progress filename: (NSString*) filename savedDir: (NSString*) savedDir resumable: (BOOL) resumable
{
    NSString *query = [NSString stringWithFormat:@"INSERT INTO task (task_id,url,status,progress,file_name,saved_dir,resumable) VALUES (\"%@\",\"%@\",%d,%d,\"%@\",\"%@\",%d)", taskId, url, status, progress, filename, savedDir, resumable ? 1 : 0];
    [_dbManager executeQuery:query];
    if (_dbManager.affectedRows != 0) {
        NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
    } else {
        NSLog(@"Could not execute the query.");
    }
}

- (void) updateTask: (NSString*) taskId status: (int) status progress: (int) progress
{
    NSString *query = [NSString stringWithFormat:@"UPDATE task SET status=%d, progress=%d WHERE task_id=\"%@\"", status, progress, taskId];
    [_dbManager executeQuery:query];
    if (_dbManager.affectedRows != 0) {
        NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
    } else {
        NSLog(@"Could not execute the query.");
    }
}

- (void) updateTask: (NSString*) taskId resumable: (BOOL) resumable
{
    NSString *query = [NSString stringWithFormat:@"UPDATE task SET resumable=%d WHERE task_id=\"%@\"", resumable ? 1 : 0, taskId];
    [_dbManager executeQuery:query];
    if (_dbManager.affectedRows != 0) {
        NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
    } else {
        NSLog(@"Could not execute the query.");
    }
}

- (NSArray*)loadAllTasks
{
    NSString *query = @"SELECT * FROM task";
    NSArray *records = [[NSArray alloc] initWithArray:[_dbManager loadDataFromDB:query]];
    NSLog(@"Load tasks successfully");
    NSMutableArray *results = [NSMutableArray new];
    for(NSArray *record in records) {
        NSString *taskId = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"task_id"]];
        int status = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"status"]] intValue];
        int progress = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"progress"]] intValue];
        NSString *url = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"url"]];
        NSString *filename = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"file_name"]];
        NSString *savedDir = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"saved_dir"]];
        int resumable = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"resumable"]] intValue];
        [results addObject:[NSDictionary dictionaryWithObjectsAndKeys:taskId, KEY_TASK_ID, @(status), KEY_STATUS, @(progress), KEY_PROGRESS, url, KEY_URL, filename, KEY_FILE_NAME, savedDir, KEY_SAVED_DIR, [NSNumber numberWithBool:(resumable == 1)], KEY_RESUMABLE, nil]];
    }
    return results;
}

- (instancetype)initWithBinaryMessenger: (NSObject<FlutterBinaryMessenger>*) messenger;
{
    if (self = [super init]) {
        _flutterChannel = [FlutterMethodChannel
                                methodChannelWithName:@"vn.hunghd/downloader"
                                binaryMessenger:messenger];

        NSLog(@"maximumConcurrentTask: %d", FlutterDownloaderPlugin.maximumConcurrentTask);

        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[NSString stringWithFormat:@"%@.download.background.%f", NSBundle.mainBundle.bundleIdentifier, [[NSDate date] timeIntervalSince1970]]];
        sessionConfiguration.HTTPMaximumConnectionsPerHost = MAX(FlutterDownloaderPlugin.maximumConcurrentTask, 1);
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
        NSLog(@"init NSURLSession with id: %@", [[_session configuration] identifier]);

        NSBundle *frameworkBundle = [NSBundle bundleForClass:FlutterDownloaderPlugin.class];
        NSURL *bundleUrl = [[frameworkBundle resourceURL] URLByAppendingPathComponent:@"FlutterDownloaderDatabase.bundle"];
        NSBundle *resourceBundle = [NSBundle bundleWithURL:bundleUrl];
        NSString *dbPath = [resourceBundle pathForResource:@"download_tasks" ofType:@"sql"];
        NSLog(@"database path: %@", dbPath);
        _dbManager = [[DBManager alloc] initWithDatabaseFilePath:dbPath];

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

- (NSString*)downloadTaskWithURL: (NSURL*) url fileName: (NSString*) fileName andSavedDir: (NSString*) savedDir andHeaders: (NSString*) headers
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    if (headers != nil && [headers length] > 0) {
        NSError *jsonError;
        NSData *data = [headers dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

        for (NSString *key in json) {
            NSString *value = json[key];
            NSLog(@"Header(%@: %@)", key, value);
            [request setValue:value forHTTPHeaderField:key];
        }
    }
    NSURLSessionDownloadTask *task = [[self currentSession] downloadTaskWithRequest:request];
    NSString *taskId = [self getIdentifierForTask:task];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 taskId, KEY_ID,
                                 url, KEY_URL,
                                 savedDir, KEY_SAVED_DIR,
                                 fileName, KEY_FILE_NAME,
                                 @(0), KEY_PROGRESS,
                                 nil];
    _downloadInfo[taskId] = info;
    [task resume];

    return taskId;
}

- (NSString*)getIdentifierForTask:(NSURLSessionDownloadTask*) task
{
    return [NSString stringWithFormat: @"%@.%lu", [[[self currentSession] configuration] identifier], [task taskIdentifier]];
}

- (NSString*)getIdentifierForTask:(NSURLSessionDownloadTask*) task ofSession:(NSURLSession *)session
{
    return [NSString stringWithFormat: @"%@.%lu", [[session configuration] identifier], [task taskIdentifier]];
}

- (void)cancelTaskWithId: (NSString*)taskId
{
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            NSUInteger *taskIdentifier = download.taskIdentifier;
            NSString *taskIdValue = [self getIdentifierForTask:download];
            if ([taskId isEqualToString:taskIdValue] && (state == NSURLSessionTaskStateRunning)) {
                [download cancel];
                [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_CANCELED) andProgress:@(-1)];
                [self updateTask:taskId status:STATUS_CANCELED progress:-1];
            }
        };
    }];
}

- (void)cancelAllTasks {
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            if (state == NSURLSessionTaskStateRunning) {
                [download cancel];
                NSString *taskId = [self getIdentifierForTask:download];
                [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_CANCELED) andProgress:@(-1)];
                [self updateTask:taskId status:STATUS_CANCELED progress:-1];
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

# pragma FlutterPlugin
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler {
    self.backgroundTransferCompletionHandler = completionHandler;
}

- (void)applicationWillTerminate:(nonnull UIApplication *)application
{
    NSLog(@"applicationWillTerminate:");
    [self cancelAllTasks];
    _session = nil;
    _flutterChannel = nil;
    _downloadInfo = nil;
    _dbManager = nil;
}

# pragma NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) {
        NSLog(@"Unknown transfer size");
    } else {
        NSString *taskId = [self getIdentifierForTask:downloadTask];
        int progress = round(totalBytesWritten * 100 / (double)totalBytesExpectedToWrite);
        NSMutableDictionary *info = _downloadInfo[taskId];
        NSNumber *lastProgress = info[KEY_PROGRESS];
        if (([lastProgress intValue] == 0 || (progress > [lastProgress intValue] + STEP_UPDATE) || progress == 100) && progress != [lastProgress intValue]) {
            info[KEY_PROGRESS] = @(progress);
            [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_RUNNING) andProgress:@(progress)];
            [self updateTask:taskId status:STATUS_RUNNING progress:progress];
        }
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *taskId = [self getIdentifierForTask:downloadTask ofSession:session];
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
        [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_COMPLETE) andProgress:@100];
        [self updateTask:taskId status:STATUS_COMPLETE progress:100];
    } else {
        NSLog(@"Unable to copy temp file. Error: %@", [error localizedDescription]);
        [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_FAILED) andProgress:@(-1)];
        [self updateTask:taskId status:STATUS_FAILED progress:-1];
    }
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error != nil) {
        NSLog(@"Download completed with error: %@", [error localizedDescription]);
        NSString *taskId = [self getIdentifierForTask:task ofSession:session];
        int status = [error code] == -999 ? STATUS_CANCELED : STATUS_FAILED;
        [self sendUpdateProgressForTaskId:taskId inStatus:@(status) andProgress:@(-1)];
        [self updateTask:taskId status:status progress:-1];
    }
}

-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    NSLog(@"URLSessionDidFinishEventsForBackgroundURLSession:");
    // Check if all download tasks have been finished.
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if ([downloadTasks count] == 0) {
            NSLog(@"all download tasks have been finished");

            if (self.backgroundTransferCompletionHandler != nil) {
                // Copy locally the completion handler.
                void(^completionHandler)() = self.backgroundTransferCompletionHandler;

                // Make nil the backgroundTransferCompletionHandler.
                self.backgroundTransferCompletionHandler = nil;

                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    // Call the completion handler to tell the system that there are no other background transfers.
                    completionHandler();

                    // Show a local notification when all downloads are over.
                    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
                    localNotification.alertBody = @"All files have been downloaded!";
                    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
                }];
            }
        }
    }];
}

@end
