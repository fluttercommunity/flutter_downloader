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
#define KEY_MAX_CONCURRENT_TASKS @"max_concurrent_tasks"
#define KEY_MESSAGES @"messages"
#define KEY_SHOW_NOTIFICATION @"show_notification"
#define KEY_CLICK_TO_OPEN_DOWNLOADED_FILE @"click_to_open_downloaded_file"

#define STEP_UPDATE 10

@interface FlutterDownloaderPlugin()<NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>
{
    FlutterMethodChannel *_flutterChannel;
    NSURLSession *_session;
    DBManager *_dbManager;
    BOOL _initialized;
    dispatch_queue_t _databaseQueue;
    NSMutableDictionary<NSString*, NSNumber*> *_progressOfTask;
}

@end

@implementation FlutterDownloaderPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {

    FlutterDownloaderPlugin* instance = [[FlutterDownloaderPlugin alloc] initWithBinaryMessenger:registrar.messenger];
    [registrar addMethodCallDelegate:instance channel:[instance channel]];
    [registrar addApplicationDelegate: instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"methodCallHandler: %@", call.method);
    if ([@"initialize" isEqualToString:call.method]) {
        NSNumber *maxConcurrentTasks = call.arguments[KEY_MAX_CONCURRENT_TASKS];

        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[NSString stringWithFormat:@"%@.download.background.%f", NSBundle.mainBundle.bundleIdentifier, [[NSDate date] timeIntervalSince1970]]];
        sessionConfiguration.HTTPMaximumConnectionsPerHost = [maxConcurrentTasks intValue];
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
        NSLog(@"init NSURLSession with id: %@", [[_session configuration] identifier]);
        _initialized = YES;
    } else if ([@"enqueue" isEqualToString:call.method]) {
        if (_initialized) {
            NSString *urlString = call.arguments[KEY_URL];
            NSString *savedDir = call.arguments[KEY_SAVED_DIR];
            NSString *fileName = call.arguments[KEY_FILE_NAME];
            NSString *headers = call.arguments[KEY_HEADERS];
            NSNumber *showNotification = call.arguments[KEY_SHOW_NOTIFICATION];
            NSNumber *clickToOpenDownloadedFile = call.arguments[KEY_CLICK_TO_OPEN_DOWNLOADED_FILE];

            NSString *taskId = [self downloadTaskWithURL:[NSURL URLWithString:urlString] fileName:fileName andSavedDir:savedDir andHeaders:headers];

            [_progressOfTask setObject:@(0) forKey:taskId];

            __weak id weakSelf = self;
            dispatch_sync(_databaseQueue, ^{
                [weakSelf addNewTask:taskId url:urlString status:STATUS_ENQUEUED progress:0 filename:fileName savedDir:savedDir headers:headers resumable:NO showNotification: [showNotification boolValue] clickToOpenDownloadedFile: [clickToOpenDownloadedFile boolValue]];
            });
            result(taskId);
            [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_ENQUEUED) andProgress:@0];
        } else {
            result([FlutterError errorWithCode:@"not_initialized"
                                       message:@"initialize() must be called first"
                                       details:nil]);
        }
    } else if ([@"loadTasks" isEqualToString:call.method]) {
        if (_initialized) {
            __weak id weakSelf = self;
            dispatch_sync(_databaseQueue, ^{
                NSArray* tasks = [weakSelf loadAllTasks];
                result(tasks);
            });
        } else {
            result([FlutterError errorWithCode:@"not_initialized"
                                       message:@"initialize() must be called first"
                                       details:nil]);
        }
    } else if ([@"cancel" isEqualToString:call.method]) {
        if (_initialized) {
            NSString *taskId = call.arguments[KEY_TASK_ID];
            [self cancelTaskWithId:taskId];
            result([NSNull null]);
        } else {
            result([FlutterError errorWithCode:@"not_initialized"
                                       message:@"initialize() must be called first"
                                       details:nil]);
        }
    } else if ([@"cancelAll" isEqualToString:call.method]) {
        if (_initialized) {
            [self cancelAllTasks];
            result([NSNull null]);
        } else {
            result([FlutterError errorWithCode:@"not_initialized"
                                       message:@"initialize() must be called first"
                                       details:nil]);
        }
    } else if ([@"pause" isEqualToString:call.method]) {
        if (_initialized) {
            NSString *taskId = call.arguments[KEY_TASK_ID];
            [self pauseTaskWithId:taskId];
            result([NSNull null]);
        } else {
            result([FlutterError errorWithCode:@"not_initialized"
                                       message:@"initialize() must be called first"
                                       details:nil]);
        }
    } else if ([@"resume" isEqualToString:call.method]) {
        if (_initialized) {
            NSString *taskId = call.arguments[KEY_TASK_ID];
            NSDictionary* taskDict = [self loadTaskWithId:taskId];
            if (taskDict != nil) {
                NSNumber* status = taskDict[KEY_STATUS];
                if ([status intValue] == STATUS_PAUSED) {
                    NSString* urlString = taskDict[KEY_URL];
                    NSString* fileName = taskDict[KEY_FILE_NAME];
                    NSString* savedDir = taskDict[KEY_SAVED_DIR];
                    NSNumber* progress = taskDict[KEY_PROGRESS];
                    NSString *partialFilename;
                    if ([fileName isEqual:[NSNull null]]) {
                        partialFilename = [NSURL URLWithString:urlString].lastPathComponent;
                    } else {
                        partialFilename = fileName;
                    }
                    NSURL *savedDirURL = [NSURL fileURLWithPath:savedDir];
                    NSURL *partialFileURL = [savedDirURL URLByAppendingPathComponent:partialFilename];

                    NSData *resumeData = [NSData dataWithContentsOfURL:partialFileURL];

                    if (resumeData != nil) {
                        NSURLSessionDownloadTask *task = [[self currentSession] downloadTaskWithResumeData:resumeData];
                        NSString *newTaskId = [self getIdentifierForTask:task];
                        [task resume];

                        [_progressOfTask setObject:progress forKey:newTaskId];

                        result(newTaskId);

                        __weak id weakSelf = self;
                        dispatch_sync(_databaseQueue, ^{
                            [weakSelf updateTask:taskId newTaskId:newTaskId status:STATUS_RUNNING resumable:NO];
                            NSDictionary *task = [weakSelf loadTaskWithId:newTaskId];
                            NSNumber *progress = task[KEY_PROGRESS];
                            [weakSelf sendUpdateProgressForTaskId:newTaskId inStatus:@(STATUS_RUNNING) andProgress:progress];
                        });
                    } else {
                        result([FlutterError errorWithCode:@"invalid_data"
                                                   message:@"not found resume data, this task cannot be resumed"
                                                   details:nil]);
                    }
                } else {
                    result([FlutterError errorWithCode:@"invalid_status"
                                               message:@"only paused task can be resumed"
                                               details:nil]);
                }
            } else {
                result([FlutterError errorWithCode:@"invalid_task_id"
                                           message:@"not found task corresponding to given task id"
                                           details:nil]);
            }
        } else {
            result([FlutterError errorWithCode:@"not_initialized"
                                       message:@"initialize() must be called first"
                                       details:nil]);
        }
    } else if ([@"retry" isEqualToString:call.method]) {
        NSString *taskId = call.arguments[KEY_TASK_ID];
        NSDictionary* taskDict = [self loadTaskWithId:taskId];
        if (taskDict != nil) {
            NSNumber* status = taskDict[KEY_STATUS];
            if ([status intValue] == STATUS_FAILED) {
                NSString *urlString = taskDict[KEY_URL];
                NSString *savedDir = taskDict[KEY_SAVED_DIR];
                NSString *fileName = taskDict[KEY_FILE_NAME];
                NSString *headers = taskDict[KEY_HEADERS];

                NSString *newTaskId = [self downloadTaskWithURL:[NSURL URLWithString:urlString] fileName:fileName andSavedDir:savedDir andHeaders:headers];

                [_progressOfTask setObject:@(0) forKey:newTaskId];

                __weak id weakSelf = self;
                dispatch_sync(_databaseQueue, ^{
                    [weakSelf updateTask:taskId newTaskId:newTaskId status:STATUS_ENQUEUED resumable:NO];
                });
                result(newTaskId);
                [self sendUpdateProgressForTaskId:newTaskId inStatus:@(STATUS_ENQUEUED) andProgress:@0];
            } else {
                result([FlutterError errorWithCode:@"invalid_status"
                                           message:@"only failed task can be retried"
                                           details:nil]);
            }
        } else {
            result([FlutterError errorWithCode:@"invalid_task_id"
                                       message:@"not found task corresponding to given task id"
                                       details:nil]);
        }
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void) addNewTask: (NSString*) taskId url: (NSString*) url status: (int) status progress: (int) progress filename: (NSString*) filename savedDir: (NSString*) savedDir headers: (NSString*) headers resumable: (BOOL) resumable showNotification: (BOOL) showNotification clickToOpenDownloadedFile: (BOOL) clickToOpenDownloadedFile
{
    NSString *query = [NSString stringWithFormat:@"INSERT INTO task (task_id,url,status,progress,file_name,saved_dir,headers,resumable,show_notification,click_to_open_downloaded_file) VALUES (\"%@\",\"%@\",%d,%d,\"%@\",\"%@\",\"%@\",%d,%d,%d)", taskId, url, status, progress, filename, savedDir, headers, resumable ? 1 : 0, showNotification ? 1 : 0, clickToOpenDownloadedFile ? 1 : 0];
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

- (void) updateTask: (NSString*) taskId status: (int) status progress: (int) progress resumable: (BOOL) resumable {
    NSString *query = [NSString stringWithFormat:@"UPDATE task SET status=%d, progress=%d, resumable=%d WHERE task_id=\"%@\"", status, progress, resumable ? 1 : 0, taskId];
    [_dbManager executeQuery:query];
    if (_dbManager.affectedRows != 0) {
        NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
    } else {
        NSLog(@"Could not execute the query.");
    }
}

- (void) updateTask: (NSString*) currentTaskId newTaskId: (NSString*) newTaskId status: (int) status resumable: (BOOL) resumable {
    NSString *query = [NSString stringWithFormat:@"UPDATE task SET task_id=\"%@\", status=%d, resumable=%d WHERE task_id=\"%@\"", newTaskId, status, resumable ? 1 : 0, currentTaskId];
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

- (NSDictionary*) parseDictFromArray:(NSArray*)record
{
    NSString *taskId = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"task_id"]];
    int status = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"status"]] intValue];
    int progress = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"progress"]] intValue];
    NSString *url = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"url"]];
    NSString *filename = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"file_name"]];
    NSString *savedDir = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"saved_dir"]];
    NSString *headers = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"headers"]];
    int resumable = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"resumable"]] intValue];
    int showNotification = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"show_notification"]] intValue];
    int clickToOpenDownloadedFile = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"click_to_open_downloaded_file"]] intValue];
    return [NSDictionary dictionaryWithObjectsAndKeys:taskId, KEY_TASK_ID, @(status), KEY_STATUS, @(progress), KEY_PROGRESS, url, KEY_URL, filename, KEY_FILE_NAME, headers, KEY_HEADERS, savedDir, KEY_SAVED_DIR, [NSNumber numberWithBool:(resumable == 1)], KEY_RESUMABLE, [NSNumber numberWithBool:(showNotification == 1)], KEY_SHOW_NOTIFICATION, [NSNumber numberWithBool:(clickToOpenDownloadedFile == 1)], KEY_CLICK_TO_OPEN_DOWNLOADED_FILE, nil];
}

- (NSArray*)loadAllTasks
{
    NSString *query = @"SELECT * FROM task";
    NSArray *records = [[NSArray alloc] initWithArray:[_dbManager loadDataFromDB:query]];
    NSLog(@"Load tasks successfully");
    NSMutableArray *results = [NSMutableArray new];
    for(NSArray *record in records) {
        [results addObject:[self parseDictFromArray:record]];
    }
    return results;
}

- (NSDictionary*)loadTaskWithId:(NSString*)taskId
{
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM task WHERE task_id = \"%@\" ORDER BY id DESC LIMIT 1", taskId];
    NSArray *records = [[NSArray alloc] initWithArray:[_dbManager loadDataFromDB:query]];
    NSLog(@"Load task successfully");
    if (records != nil && [records count] > 0) {
        NSArray *record = [records firstObject];
        return [self parseDictFromArray:record];
    }
    return nil;
}

- (instancetype)initWithBinaryMessenger: (NSObject<FlutterBinaryMessenger>*) messenger;
{
    if (self = [super init]) {
        _flutterChannel = [FlutterMethodChannel
                           methodChannelWithName:@"vn.hunghd/downloader"
                           binaryMessenger:messenger];
        NSBundle *frameworkBundle = [NSBundle bundleForClass:FlutterDownloaderPlugin.class];
        NSURL *bundleUrl = [[frameworkBundle resourceURL] URLByAppendingPathComponent:@"FlutterDownloaderDatabase.bundle"];
        NSBundle *resourceBundle = [NSBundle bundleWithURL:bundleUrl];
        NSString *dbPath = [resourceBundle pathForResource:@"download_tasks" ofType:@"sql"];
        NSLog(@"database path: %@", dbPath);
        _databaseQueue = dispatch_queue_create("vn.hunghd.flutter_downloader", 0);
        _dbManager = [[DBManager alloc] initWithDatabaseFilePath:dbPath];
        _progressOfTask = [[NSMutableDictionary alloc] init];
        _initialized = NO;
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

- (void)pauseTaskWithId: (NSString*)taskId
{
    NSLog(@"pause task with id: %@", taskId);
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            NSString *taskIdValue = [self getIdentifierForTask:download];
            if ([taskId isEqualToString:taskIdValue] && (state == NSURLSessionTaskStateRunning)) {
                int64_t bytesReceived = download.countOfBytesReceived;
                int64_t bytesExpectedToReceive = download.countOfBytesExpectedToReceive;
                int progress = round(bytesReceived * 100 / (double)bytesExpectedToReceive);
                NSDictionary *task = [self loadTaskWithId:taskIdValue];
                NSString *savedDir = task[KEY_SAVED_DIR];
                NSString *fileName = task[KEY_FILE_NAME];
                NSString *destinationFilename;
                if ([fileName isEqual:[NSNull null]]) {
                    destinationFilename = download.originalRequest.URL.lastPathComponent;
                } else {
                    destinationFilename = fileName;
                }
                [download cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                    // Save partial downloaded data to a file
                    NSFileManager *fileManager = [NSFileManager defaultManager];

                    NSURL *savedDirURL = [NSURL fileURLWithPath:savedDir];
                    NSURL *destinationURL = [savedDirURL URLByAppendingPathComponent:destinationFilename];

                    if ([fileManager fileExistsAtPath:[destinationURL path]]) {
                        [fileManager removeItemAtURL:destinationURL error:nil];
                    }

                    BOOL success = [resumeData writeToURL:destinationURL atomically:YES];
                    NSLog(@"save partial downloaded data to a file: %s", success ? "success" : "failure");
                }];
                [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_PAUSED) andProgress:@(progress)];
                __weak id weakSelf = self;
                dispatch_sync(_databaseQueue, ^{
                    [weakSelf updateTask:taskId status:STATUS_PAUSED progress:progress resumable:YES];
                });
                return;
            }
        };
    }];
}

- (void)cancelTaskWithId: (NSString*)taskId
{
    NSLog(@"cancel task with id: %@", taskId);
    __weak id weakSelf = self;
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            NSString *taskIdValue = [self getIdentifierForTask:download];
            if ([taskId isEqualToString:taskIdValue] && (state == NSURLSessionTaskStateRunning)) {
                [download cancel];
                [weakSelf sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_CANCELED) andProgress:@(-1)];
                dispatch_sync(_databaseQueue, ^{
                    [weakSelf updateTask:taskId status:STATUS_CANCELED progress:-1];
                });
                return;
            }
        };
    }];
}

- (void)cancelAllTasks {
    __weak id weakSelf = self;
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            if (state == NSURLSessionTaskStateRunning) {
                [download cancel];
                NSString *taskId = [self getIdentifierForTask:download];
                [weakSelf sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_CANCELED) andProgress:@(-1)];
                dispatch_sync(_databaseQueue, ^{
                    [weakSelf updateTask:taskId status:STATUS_CANCELED progress:-1];
                });
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
- (BOOL)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler {
    self.backgroundTransferCompletionHandler = completionHandler;
    return YES;
}

- (void)applicationWillTerminate:(nonnull UIApplication *)application
{
    NSLog(@"applicationWillTerminate:");
    for (NSString* key in _progressOfTask) {
        [self updateTask:key status:STATUS_CANCELED progress:-1];
    }
    _session = nil;
    _flutterChannel = nil;
    _dbManager = nil;
    _databaseQueue = nil;
    _progressOfTask = nil;
}

# pragma NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) {
        NSLog(@"Unknown transfer size");
    } else {
        NSString *taskId = [self getIdentifierForTask:downloadTask];
        int progress = round(totalBytesWritten * 100 / (double)totalBytesExpectedToWrite);
        NSNumber *lastProgress = _progressOfTask[taskId];
        if (([lastProgress intValue] == 0 || (progress > [lastProgress intValue] + STEP_UPDATE) || progress == 100) && progress != [lastProgress intValue]) {
            [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_RUNNING) andProgress:@(progress)];
            _progressOfTask[taskId] = @(progress);
            __weak id weakSelf = self;
            dispatch_sync(_databaseQueue, ^{
                [weakSelf updateTask:taskId status:STATUS_RUNNING progress:progress];
            });
        }
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSString *taskId = [self getIdentifierForTask:downloadTask ofSession:session];
    NSDictionary *task = [self loadTaskWithId:taskId];
    NSString *savedDir = task[KEY_SAVED_DIR];
    NSString *fileName = task[KEY_FILE_NAME];

    NSString *destinationFilename;
    if ([fileName isEqual:[NSNull null]]) {
        destinationFilename = downloadTask.originalRequest.URL.lastPathComponent;
    } else {
        destinationFilename = fileName;
    }
    NSURL *savedDirURL = [NSURL fileURLWithPath:savedDir];
    NSURL *destinationURL = [savedDirURL URLByAppendingPathComponent:destinationFilename];

    [_progressOfTask removeObjectForKey:taskId];

    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:[destinationURL path]]) {
        [fileManager removeItemAtURL:destinationURL error:nil];
    }

    BOOL success = [fileManager copyItemAtURL:location
                                        toURL:destinationURL
                                        error:&error];

    __weak id weakSelf = self;
    if (success) {
        [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_COMPLETE) andProgress:@100];
        dispatch_sync(_databaseQueue, ^{
            [weakSelf updateTask:taskId status:STATUS_COMPLETE progress:100];
        });
    } else {
        NSLog(@"Unable to copy temp file. Error: %@", [error localizedDescription]);
        [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_FAILED) andProgress:@(-1)];
        dispatch_sync(_databaseQueue, ^{
            [weakSelf updateTask:taskId status:STATUS_FAILED progress:-1];
        });
    }
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error != nil) {
        NSLog(@"Download completed with error: %@", [error localizedDescription]);
        NSString *taskId = [self getIdentifierForTask:task ofSession:session];
        NSDictionary *task = [self loadTaskWithId:taskId];
        NSNumber *resumable = task[KEY_RESUMABLE];
        [_progressOfTask removeObjectForKey:taskId];
        if (![resumable boolValue]) {
            int status = [error code] == -999 ? STATUS_CANCELED : STATUS_FAILED;
            [self sendUpdateProgressForTaskId:taskId inStatus:@(status) andProgress:@(-1)];
            __weak id weakSelf = self;
            dispatch_sync(_databaseQueue, ^{
                [weakSelf updateTask:taskId status:status progress:-1];
            });
        }
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
                void(^completionHandler)(void) = self.backgroundTransferCompletionHandler;

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
