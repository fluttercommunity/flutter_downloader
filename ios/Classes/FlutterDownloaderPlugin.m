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
#define KEY_SHOW_NOTIFICATION @"show_notification"
#define KEY_OPEN_FILE_FROM_NOTIFICATION @"open_file_from_notification"
#define KEY_QUERY @"query"
#define KEY_TIME_CREATED @"time_created"

#define NULL_VALUE @"<null>"

#define ERROR_NOT_INITIALIZED [FlutterError errorWithCode:@"not_initialized" message:@"initialize() must called first" details:nil]
#define ERROR_INVALID_TASK_ID [FlutterError errorWithCode:@"invalid_task_id" message:@"not found task corresponding to given task id" details:nil]

#define STEP_UPDATE 5

@interface FlutterDownloaderPlugin()<NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate, UIDocumentInteractionControllerDelegate>
{
    FlutterEngine *_headlessRunner;
    FlutterMethodChannel *_mainChannel;
    FlutterMethodChannel *_callbackChannel;
    NSObject<FlutterPluginRegistrar> *_registrar;
    NSURLSession *_session;
    DBManager *_dbManager;
    NSMutableDictionary<NSString*, NSMutableDictionary*> *_runningTaskById;
    NSString *_allFilesDownloadedMsg;
    NSMutableArray *_eventQueue;
    int64_t _callbackHandle;
}

@property(nonatomic, strong) dispatch_queue_t databaseQueue;

@end

@implementation FlutterDownloaderPlugin

static FlutterPluginRegistrantCallback registerPlugins = nil;
static BOOL initialized = NO;
static BOOL debug = YES;

@synthesize databaseQueue;

- (instancetype)init:(NSObject<FlutterPluginRegistrar> *)registrar;
{
    if (self = [super init]) {
        _headlessRunner = [[FlutterEngine alloc] initWithName:@"FlutterDownloaderIsolate" project:nil allowHeadlessExecution:YES];
        _registrar = registrar;

        _mainChannel = [FlutterMethodChannel
                           methodChannelWithName:@"vn.hunghd/downloader"
                           binaryMessenger:[registrar messenger]];
        [registrar addMethodCallDelegate:self channel:_mainChannel];

        _callbackChannel =
        [FlutterMethodChannel methodChannelWithName:@"vn.hunghd/downloader_background"
                                    binaryMessenger:[_headlessRunner binaryMessenger]];

        _eventQueue = [[NSMutableArray alloc] init];

        NSBundle *frameworkBundle = [NSBundle bundleForClass:FlutterDownloaderPlugin.class];

        // initialize Database
        NSURL *bundleUrl = [[frameworkBundle resourceURL] URLByAppendingPathComponent:@"FlutterDownloaderDatabase.bundle"];
        NSBundle *resourceBundle = [NSBundle bundleWithURL:bundleUrl];
        NSString *dbPath = [resourceBundle pathForResource:@"download_tasks" ofType:@"sql"];
        if (debug) {
            NSLog(@"database path: %@", dbPath);
        }
        databaseQueue = dispatch_queue_create("vn.hunghd.flutter_downloader", 0);
        _dbManager = [[DBManager alloc] initWithDatabaseFilePath:dbPath];
        _runningTaskById = [[NSMutableDictionary alloc] init];

        // init NSURLSession
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSNumber *maxConcurrentTasks = [mainBundle objectForInfoDictionaryKey:@"FDMaximumConcurrentTasks"];
        if (maxConcurrentTasks == nil) {
            maxConcurrentTasks = @3;
        }
        if (debug) {
            NSLog(@"MAXIMUM_CONCURRENT_TASKS = %@", maxConcurrentTasks);
        }
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[NSString stringWithFormat:@"%@.download.background.%f", NSBundle.mainBundle.bundleIdentifier, [[NSDate date] timeIntervalSince1970]]];
        sessionConfiguration.HTTPMaximumConnectionsPerHost = [maxConcurrentTasks intValue];
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
        if (debug) {
            NSLog(@"init NSURLSession with id: %@", [[_session configuration] identifier]);
        }

        _allFilesDownloadedMsg = [mainBundle objectForInfoDictionaryKey:@"FDAllFilesDownloadedMessage"];
        if (_allFilesDownloadedMsg == nil) {
            _allFilesDownloadedMsg = @"All files have been downloaded";
        }
        if (debug) {
            NSLog(@"AllFilesDownloadedMessage: %@", _allFilesDownloadedMsg);
        }
    }

    return self;
}

- (void)startBackgroundIsolate:(int64_t)handle {
    if (debug) {
        NSLog(@"startBackgroundIsolate");
    }
    FlutterCallbackInformation *info = [FlutterCallbackCache lookupCallbackInformation:handle];
    NSAssert(info != nil, @"failed to find callback");
    NSString *entrypoint = info.callbackName;
    NSString *uri = info.callbackLibraryPath;
    [_headlessRunner runWithEntrypoint:entrypoint libraryURI:uri];
    NSAssert(registerPlugins != nil, @"failed to set registerPlugins");

    // Once our headless runner has been started, we need to register the application's plugins
    // with the runner in order for them to work on the background isolate. `registerPlugins` is
    // a callback set from AppDelegate.m in the main application. This callback should register
    // all relevant plugins (excluding those which require UI).
    registerPlugins(_headlessRunner);
    [_registrar addMethodCallDelegate:self channel:_callbackChannel];
}

- (FlutterMethodChannel *)channel {
    return _mainChannel;
}

- (NSURLSession*)currentSession {
    return _session;
}

- (NSURLSessionDownloadTask*)downloadTaskWithURL: (NSURL*) url fileName: (NSString*) fileName andSavedDir: (NSString*) savedDir andHeaders: (NSString*) headers
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    if (headers != nil && [headers length] > 0) {
        NSError *jsonError;
        NSData *data = [headers dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

        for (NSString *key in json) {
            NSString *value = json[key];
            if (debug) {
                NSLog(@"Header(%@: %@)", key, value);
            }
            [request setValue:value forHTTPHeaderField:key];
        }
    }
    NSURLSessionDownloadTask *task = [[self currentSession] downloadTaskWithRequest:request];
    [task resume];

    return task;
}

- (NSString*)identifierForTask:(NSURLSessionTask*) task
{
    return [NSString stringWithFormat: @"%@.%lu", [[[self currentSession] configuration] identifier], [task taskIdentifier]];
}

- (NSString*)identifierForTask:(NSURLSessionTask*) task ofSession:(NSURLSession *)session
{
    return [NSString stringWithFormat: @"%@.%lu", [[session configuration] identifier], [task taskIdentifier]];
}

- (void)updateRunningTaskById:(NSString*)taskId progress:(int)progress status:(int)status resumable:(BOOL)resumable {
    _runningTaskById[taskId][KEY_PROGRESS] = @(progress);
    _runningTaskById[taskId][KEY_STATUS] = @(status);
    _runningTaskById[taskId][KEY_RESUMABLE] = @(resumable);
}

- (void)pauseTaskWithId: (NSString*)taskId
{
    if (debug) {
        NSLog(@"pause task with id: %@", taskId);
    }
    __typeof__(self) __weak weakSelf = self;
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            NSString *taskIdValue = [weakSelf identifierForTask:download];
            if ([taskId isEqualToString:taskIdValue] && (state == NSURLSessionTaskStateRunning)) {
                int64_t bytesReceived = download.countOfBytesReceived;
                int64_t bytesExpectedToReceive = download.countOfBytesExpectedToReceive;
                int progress = round(bytesReceived * 100 / (double)bytesExpectedToReceive);
                NSDictionary *task = [weakSelf loadTaskWithId:taskIdValue];
                [download cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                    // Save partial downloaded data to a file
                    NSFileManager *fileManager = [NSFileManager defaultManager];
                    NSURL *destinationURL = [weakSelf fileUrlOf:taskId taskInfo:task downloadTask:download];

                    if ([fileManager fileExistsAtPath:[destinationURL path]]) {
                        [fileManager removeItemAtURL:destinationURL error:nil];
                    }

                    BOOL success = [resumeData writeToURL:destinationURL atomically:YES];
                    if (debug) {
                        NSLog(@"save partial downloaded data to a file: %s", success ? "success" : "failure");
                    }
                }];

                [weakSelf updateRunningTaskById:taskId progress:progress status:STATUS_PAUSED resumable:YES];

                [weakSelf sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_PAUSED) andProgress:@(progress)];

                dispatch_sync([weakSelf databaseQueue], ^{
                    [weakSelf updateTask:taskId status:STATUS_PAUSED progress:progress resumable:YES];
                });
                return;
            }
        };
    }];
}

- (void)cancelTaskWithId: (NSString*)taskId
{
    if (debug) {
        NSLog(@"cancel task with id: %@", taskId);
    }
    __typeof__(self) __weak weakSelf = self;
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            NSString *taskIdValue = [self identifierForTask:download];
            if ([taskId isEqualToString:taskIdValue] && (state == NSURLSessionTaskStateRunning)) {
                [download cancel];
                [weakSelf sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_CANCELED) andProgress:@(-1)];
                dispatch_sync([weakSelf databaseQueue], ^{
                    [weakSelf updateTask:taskId status:STATUS_CANCELED progress:-1];
                });
                return;
            }
        };
    }];
}

- (void)cancelAllTasks {
    __typeof__(self) __weak weakSelf = self;
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
        for (NSURLSessionDownloadTask *download in downloads) {
            NSURLSessionTaskState state = download.state;
            if (state == NSURLSessionTaskStateRunning) {
                [download cancel];
                NSString *taskId = [self identifierForTask:download];
                [weakSelf sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_CANCELED) andProgress:@(-1)];
                dispatch_sync([weakSelf databaseQueue], ^{
                    [weakSelf updateTask:taskId status:STATUS_CANCELED progress:-1];
                });
            }
        };
    }];
}

- (void)sendUpdateProgressForTaskId: (NSString*)taskId inStatus: (NSNumber*) status andProgress: (NSNumber*) progress
{
    NSArray *args = @[@(_callbackHandle), taskId, status, progress];
    if (initialized) {
        [_callbackChannel invokeMethod:@"" arguments:args];
    } else {
        [_eventQueue addObject:args];
    }
}

- (BOOL)openDocumentWithURL:(NSURL*)url {
    if (debug) {
        NSLog(@"try to open file in url: %@", url);
    }
    BOOL result = NO;
    UIDocumentInteractionController* tmpDocController = [UIDocumentInteractionController
                                                         interactionControllerWithURL:url];
    if (tmpDocController)
    {
        if (debug) {
            NSLog(@"initialize UIDocumentInteractionController successfully");
        }
        tmpDocController.delegate = self;
        result = [tmpDocController presentPreviewAnimated:YES];
    }
    return result;
}

- (NSURL*)fileUrlFromDict:(NSDictionary*)dict
{
    NSString *savedDir = dict[KEY_SAVED_DIR];
    NSString *filename = dict[KEY_FILE_NAME];
    if (debug) {
        NSLog(@"savedDir: %@", savedDir);
        NSLog(@"filename: %@", filename);
    }
    NSURL *savedDirURL = [NSURL fileURLWithPath:savedDir];
    return [savedDirURL URLByAppendingPathComponent:filename];
}

- (NSURL*)fileUrlOf:(NSString*)taskId taskInfo:(NSDictionary*)taskInfo downloadTask:(NSURLSessionDownloadTask*)downloadTask {
    NSString *filename = taskInfo[KEY_FILE_NAME];
    NSString *suggestedFilename = downloadTask.response.suggestedFilename;
    if (debug) {
        NSLog(@"SuggestedFileName: %@", suggestedFilename);
    }

    // check filename, if it is empty then we try to extract it from http response or url path
    if (filename == (NSString*) [NSNull null] || [NULL_VALUE isEqualToString: filename]) {
        if (suggestedFilename) {
            filename = suggestedFilename;
        } else {
            filename = downloadTask.currentRequest.URL.lastPathComponent;
        }

        NSMutableDictionary *mutableTask = [taskInfo mutableCopy];
        [mutableTask setObject:filename forKey:KEY_FILE_NAME];

        // update taskInfo
        if ([_runningTaskById objectForKey:taskId]) {
            _runningTaskById[taskId][KEY_FILE_NAME] = filename;
        }

        // update DB
        __typeof__(self) __weak weakSelf = self;
        dispatch_sync(databaseQueue, ^{
            [weakSelf updateTask:taskId filename:filename];
        });

        return [self fileUrlFromDict:mutableTask];
    }

    return [self fileUrlFromDict:taskInfo];
}

- (NSString*)absoluteSavedDirPath:(NSString*)savedDir {
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:savedDir];
}

- (NSString*)shortenSavedDirPath:(NSString*)absolutePath {
    if (debug) {
        NSLog(@"Absolute savedDir path: %@", absolutePath);
    }
    
    if (absolutePath) {
        NSString* documentDirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSRange foundRank = [absolutePath rangeOfString:documentDirPath];
        if (foundRank.length > 0) {
            // we increase the location of range by one because we want to remove the file separator as well.
            NSString *shortenSavedDirPath = [absolutePath substringWithRange:NSMakeRange(foundRank.length + 1, absolutePath.length - documentDirPath.length - 1)];
            return shortenSavedDirPath != nil ? shortenSavedDirPath : @"";
        }
    }
   
    return absolutePath;
}

- (long long)currentTimeInMilliseconds
{
    return (long long)([[NSDate date] timeIntervalSince1970]*1000);
}

# pragma mark - Database Accessing

- (NSString*) escape:(NSString*) origin revert:(BOOL)revert
{
    if ( origin == (NSString *)[NSNull null] )
    {
        return @"";
    }
    return revert
    ? [origin stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    : [origin stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
}

- (void) addNewTask: (NSString*) taskId url: (NSString*) url status: (int) status progress: (int) progress filename: (NSString*) filename savedDir: (NSString*) savedDir headers: (NSString*) headers resumable: (BOOL) resumable showNotification: (BOOL) showNotification openFileFromNotification: (BOOL) openFileFromNotification
{
    headers = [self escape:headers revert:false];
    NSString *query = [NSString stringWithFormat:@"INSERT INTO task (task_id,url,status,progress,file_name,saved_dir,headers,resumable,show_notification,open_file_from_notification,time_created) VALUES (\"%@\",\"%@\",%d,%d,\"%@\",\"%@\",\"%@\",%d,%d,%d,%lld)", taskId, url, status, progress, filename, savedDir, headers, resumable ? 1 : 0, showNotification ? 1 : 0, openFileFromNotification ? 1 : 0, [self currentTimeInMilliseconds]];
    [_dbManager executeQuery:query];
    if (debug) {
        if (_dbManager.affectedRows != 0) {
            NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
        } else {
            NSLog(@"Could not execute the query.");
        }
    }
}

- (void) updateTask: (NSString*) taskId status: (int) status progress: (int) progress
{
    NSString *query = [NSString stringWithFormat:@"UPDATE task SET status=%d, progress=%d WHERE task_id=\"%@\"", status, progress, taskId];
    [_dbManager executeQuery:query];
    if (debug) {
        if (_dbManager.affectedRows != 0) {
            NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
        } else {
            NSLog(@"Could not execute the query.");
        }
    }
}

- (void) updateTask: (NSString*) taskId filename: (NSString*) filename {
    NSString *query = [NSString stringWithFormat:@"UPDATE task SET file_name=\"%@\" WHERE task_id=\"%@\"", filename, taskId];
    [_dbManager executeQuery:query];
    if (debug) {
        if (_dbManager.affectedRows != 0) {
            NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
        } else {
            NSLog(@"Could not execute the query.");
        }
    }
}

- (void) updateTask: (NSString*) taskId status: (int) status progress: (int) progress resumable: (BOOL) resumable {
    NSString *query = [NSString stringWithFormat:@"UPDATE task SET status=%d, progress=%d, resumable=%d WHERE task_id=\"%@\"", status, progress, resumable ? 1 : 0, taskId];
    [_dbManager executeQuery:query];
    if (debug) {
        if (_dbManager.affectedRows != 0) {
            NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
        } else {
            NSLog(@"Could not execute the query.");
        }
    }
}

- (void) updateTask: (NSString*) currentTaskId newTaskId: (NSString*) newTaskId status: (int) status resumable: (BOOL) resumable {
    NSString *query = [NSString stringWithFormat:@"UPDATE task SET task_id=\"%@\", status=%d, resumable=%d, time_created=%lld WHERE task_id=\"%@\"", newTaskId, status, resumable ? 1 : 0, [self currentTimeInMilliseconds], currentTaskId];
    [_dbManager executeQuery:query];
    if (debug) {
        if (_dbManager.affectedRows != 0) {
            NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
        } else {
            NSLog(@"Could not execute the query.");
        }
    }
}

- (void) updateTask: (NSString*) taskId resumable: (BOOL) resumable
{
    NSString *query = [NSString stringWithFormat:@"UPDATE task SET resumable=%d WHERE task_id=\"%@\"", resumable ? 1 : 0, taskId];
    [_dbManager executeQuery:query];
    if (debug) {
        if (_dbManager.affectedRows != 0) {
            NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
        } else {
            NSLog(@"Could not execute the query.");
        }
    }
}

- (void) deleteTask: (NSString*) taskId {
    NSString *query = [NSString stringWithFormat:@"DELETE FROM task WHERE task_id=\"%@\"", taskId];
    [_dbManager executeQuery:query];
    if (debug) {
        if (_dbManager.affectedRows != 0) {
            NSLog(@"Query was executed successfully. Affected rows = %d", _dbManager.affectedRows);
        } else {
            NSLog(@"Could not execute the query.");
        }
    }
}

- (NSArray*)loadAllTasks
{
    NSString *query = @"SELECT * FROM task";
    NSArray *records = [[NSArray alloc] initWithArray:[_dbManager loadDataFromDB:query]];
    if (debug) {
        NSLog(@"Load tasks successfully");
    }
    NSMutableArray *results = [NSMutableArray new];
    for(NSArray *record in records) {
        NSDictionary *task = [self taskDictFromRecordArray:record];
        if (debug) {
            NSLog(@"%@", task);
        }
        [results addObject:task];
    }
    return results;
}

- (NSArray*)loadTasksWithRawQuery: (NSString*)query
{
    NSArray *records = [[NSArray alloc] initWithArray:[_dbManager loadDataFromDB:query]];
    if (debug) {
        NSLog(@"Load tasks successfully");
    }
    NSMutableArray *results = [NSMutableArray new];
    for(NSArray *record in records) {
        [results addObject:[self taskDictFromRecordArray:record]];
    }
    return results;
}

- (NSDictionary*)loadTaskWithId:(NSString*)taskId
{
    // check task in memory-cache first
    if ([_runningTaskById objectForKey:taskId]) {
        return [_runningTaskById objectForKey:taskId];
    } else {
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM task WHERE task_id = \"%@\" ORDER BY id DESC LIMIT 1", taskId];
        NSArray *records = [[NSArray alloc] initWithArray:[_dbManager loadDataFromDB:query]];
        if (debug) {
            NSLog(@"Load task successfully");
        }
        if (records != nil && [records count] > 0) {
            NSArray *record = [records firstObject];
            NSDictionary *task = [self taskDictFromRecordArray:record];
            if ([task[KEY_STATUS] intValue] < STATUS_COMPLETE) {
                [_runningTaskById setObject:[NSMutableDictionary dictionaryWithDictionary:task] forKey:taskId];
            }
            return task;
        }
        return nil;
    }
}

- (NSDictionary*) taskDictFromRecordArray:(NSArray*)record
{
    NSString *taskId = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"task_id"]];
    int status = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"status"]] intValue];
    int progress = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"progress"]] intValue];
    NSString *url = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"url"]];
    NSString *filename = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"file_name"]];
    NSString *savedDir = [self absoluteSavedDirPath:[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"saved_dir"]]];
    NSString *headers = [record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"headers"]];
    headers = [self escape:headers revert:true];
    int resumable = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"resumable"]] intValue];
    int showNotification = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"show_notification"]] intValue];
    int openFileFromNotification = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"open_file_from_notification"]] intValue];
    long long timeCreated = [[record objectAtIndex:[_dbManager.arrColumnNames indexOfObject:@"time_created"]] longLongValue];
    return [NSDictionary dictionaryWithObjectsAndKeys:taskId, KEY_TASK_ID, @(status), KEY_STATUS, @(progress), KEY_PROGRESS, url, KEY_URL, filename, KEY_FILE_NAME, headers, KEY_HEADERS, savedDir, KEY_SAVED_DIR, [NSNumber numberWithBool:(resumable == 1)], KEY_RESUMABLE, [NSNumber numberWithBool:(showNotification == 1)], KEY_SHOW_NOTIFICATION, [NSNumber numberWithBool:(openFileFromNotification == 1)], KEY_OPEN_FILE_FROM_NOTIFICATION, @(timeCreated), KEY_TIME_CREATED, nil];
}

# pragma mark - FlutterDownloader

- (void)initializeMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSArray *arguments = call.arguments;
    debug = [arguments[1] boolValue];
    _dbManager.debug = debug;
    [self startBackgroundIsolate:[arguments[0] longLongValue]];
    result([NSNull null]);
}

- (void)didInitializeDispatcherMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    @synchronized (self) {
        initialized = YES;
        //unqueue all pending download status events.
        while ([_eventQueue count] > 0) {
            NSArray* args = _eventQueue[0];
            [_eventQueue removeObjectAtIndex:0];
            [_callbackChannel invokeMethod:@"" arguments:args];
        }
    }
    result([NSNull null]);
}

- (void)registerCallbackMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSArray *arguments = call.arguments;
    _callbackHandle = [arguments[0] longLongValue];
    result([NSNull null]);
}

- (void)enqueueMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *urlString = call.arguments[KEY_URL];
    NSString *savedDir = call.arguments[KEY_SAVED_DIR];
    NSString *shortSavedDir = [self shortenSavedDirPath:savedDir];
    NSString *fileName = call.arguments[KEY_FILE_NAME];
    NSString *headers = call.arguments[KEY_HEADERS];
    NSNumber *showNotification = call.arguments[KEY_SHOW_NOTIFICATION];
    NSNumber *openFileFromNotification = call.arguments[KEY_OPEN_FILE_FROM_NOTIFICATION];

    NSURLSessionDownloadTask *task = [self downloadTaskWithURL:[NSURL URLWithString:urlString] fileName:fileName andSavedDir:savedDir andHeaders:headers];

    NSString *taskId = [self identifierForTask:task];

    [_runningTaskById setObject: [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  urlString, KEY_URL,
                                  fileName, KEY_FILE_NAME,
                                  savedDir, KEY_SAVED_DIR,
                                  headers, KEY_HEADERS,
                                  showNotification, KEY_SHOW_NOTIFICATION,
                                  openFileFromNotification, KEY_OPEN_FILE_FROM_NOTIFICATION,
                                  @(NO), KEY_RESUMABLE,
                                  @(STATUS_ENQUEUED), KEY_STATUS,
                                  @(0), KEY_PROGRESS, nil]
                         forKey:taskId];

    __typeof__(self) __weak weakSelf = self;
    dispatch_sync(databaseQueue, ^{
        [weakSelf addNewTask:taskId url:urlString status:STATUS_ENQUEUED progress:0 filename:fileName savedDir:shortSavedDir headers:headers resumable:NO showNotification: [showNotification boolValue] openFileFromNotification: [openFileFromNotification boolValue]];
    });
    result(taskId);
    [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_ENQUEUED) andProgress:@0];
}

- (void)loadTasksMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    __typeof__(self) __weak weakSelf = self;
    dispatch_sync(databaseQueue, ^{
        NSArray* tasks = [weakSelf loadAllTasks];
        result(tasks);
    });
}

- (void)loadTasksWithRawQueryMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *query = call.arguments[KEY_QUERY];
    __typeof__(self) __weak weakSelf = self;
    dispatch_sync(databaseQueue, ^{
        NSArray* tasks = [weakSelf loadTasksWithRawQuery:query];
        result(tasks);
    });
}

- (void)cancelMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *taskId = call.arguments[KEY_TASK_ID];
    [self cancelTaskWithId:taskId];
    result([NSNull null]);
}

- (void)cancelAllMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    [self cancelAllTasks];
    result([NSNull null]);
}

- (void)pauseMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *taskId = call.arguments[KEY_TASK_ID];
    [self pauseTaskWithId:taskId];
    result([NSNull null]);
}

- (void)resumeMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *taskId = call.arguments[KEY_TASK_ID];
    NSDictionary* taskDict = [self loadTaskWithId:taskId];
    if (taskDict != nil) {
        NSNumber* status = taskDict[KEY_STATUS];
        if ([status intValue] == STATUS_PAUSED) {
            NSURL *partialFileURL = [self fileUrlFromDict:taskDict];

            if (debug) {
                NSLog(@"Try to load resume data at url: %@", partialFileURL);
            }

            NSData *resumeData = [NSData dataWithContentsOfURL:partialFileURL];

            if (resumeData != nil) {
                NSURLSessionDownloadTask *task = [[self currentSession] downloadTaskWithResumeData:resumeData];
                NSString *newTaskId = [self identifierForTask:task];
                [task resume];

                // update memory-cache, assign a new taskId for paused task
                NSMutableDictionary *newTask = [NSMutableDictionary dictionaryWithDictionary:taskDict];
                newTask[KEY_STATUS] = @(STATUS_RUNNING);
                newTask[KEY_RESUMABLE] = @(NO);
                [_runningTaskById setObject:newTask forKey:newTaskId];
                [_runningTaskById removeObjectForKey:taskId];

                result(newTaskId);

                __typeof__(self) __weak weakSelf = self;
                dispatch_sync([self databaseQueue], ^{
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
        result(ERROR_INVALID_TASK_ID);
    }
}

- (void)retryMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *taskId = call.arguments[KEY_TASK_ID];
    NSDictionary* taskDict = [self loadTaskWithId:taskId];
    if (taskDict != nil) {
        NSNumber* status = taskDict[KEY_STATUS];
        if ([status intValue] == STATUS_FAILED || [status intValue] == STATUS_CANCELED) {
            NSString *urlString = taskDict[KEY_URL];
            NSString *savedDir = taskDict[KEY_SAVED_DIR];
            NSString *fileName = taskDict[KEY_FILE_NAME];
            NSString *headers = taskDict[KEY_HEADERS];

            NSURLSessionDownloadTask *newTask = [self downloadTaskWithURL:[NSURL URLWithString:urlString] fileName:fileName andSavedDir:savedDir andHeaders:headers];
            NSString *newTaskId = [self identifierForTask:newTask];

            // update memory-cache
            NSMutableDictionary *newTaskDict = [NSMutableDictionary dictionaryWithDictionary:taskDict];
            newTaskDict[KEY_STATUS] = @(STATUS_ENQUEUED);
            newTaskDict[KEY_PROGRESS] = @(0);
            newTaskDict[KEY_RESUMABLE] = @(NO);
            [_runningTaskById setObject:newTaskDict forKey:newTaskId];
            [_runningTaskById removeObjectForKey:taskId];

            __typeof__(self) __weak weakSelf = self;
            dispatch_sync([self databaseQueue], ^{
                [weakSelf updateTask:taskId newTaskId:newTaskId status:STATUS_ENQUEUED resumable:NO];
            });
            result(newTaskId);
            [self sendUpdateProgressForTaskId:newTaskId inStatus:@(STATUS_ENQUEUED) andProgress:@(0)];
        } else {
            result([FlutterError errorWithCode:@"invalid_status"
                                       message:@"only failed and canceled task can be retried"
                                       details:nil]);
        }
    } else {
        result(ERROR_INVALID_TASK_ID);
    }
}

- (void)openMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *taskId = call.arguments[KEY_TASK_ID];
    NSDictionary* taskDict = [self loadTaskWithId:taskId];
    if (taskDict != nil) {
        NSNumber* status = taskDict[KEY_STATUS];
        if ([status intValue] == STATUS_COMPLETE) {
            NSURL *downloadedFileURL = [self fileUrlFromDict:taskDict];

            BOOL success = [self openDocumentWithURL:downloadedFileURL];
            result([NSNumber numberWithBool:success]);
        } else {
            result([FlutterError errorWithCode:@"invalid_status"
                                       message:@"only success task can be opened"
                                       details:nil]);
        }
    } else {
        result(ERROR_INVALID_TASK_ID);
    }
}

- (void)removeMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *taskId = call.arguments[KEY_TASK_ID];
    Boolean shouldDeleteContent = [call.arguments[@"should_delete_content"] boolValue];
    NSDictionary* taskDict = [self loadTaskWithId:taskId];
    if (taskDict != nil) {
        NSNumber* status = taskDict[KEY_STATUS];
        if ([status intValue] == STATUS_ENQUEUED || [status intValue] == STATUS_RUNNING) {
            __typeof__(self) __weak weakSelf = self;
            [[self currentSession] getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *data, NSArray<NSURLSessionUploadTask *> *uploads, NSArray<NSURLSessionDownloadTask *> *downloads) {
                for (NSURLSessionDownloadTask *download in downloads) {
                    NSURLSessionTaskState state = download.state;
                    NSString *taskIdValue = [weakSelf identifierForTask:download];
                    if ([taskId isEqualToString:taskIdValue] && (state == NSURLSessionTaskStateRunning)) {
                        [download cancel];
                        [weakSelf sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_CANCELED) andProgress:@(-1)];
                        dispatch_sync([weakSelf databaseQueue], ^{
                            [weakSelf deleteTask:taskId];
                        });
                        return;
                    }
                };
            }];
        }
        [self deleteTask:taskId];
        if (shouldDeleteContent) {
            NSURL *destinationURL = [self fileUrlFromDict:taskDict];

            NSError *error;
            NSFileManager *fileManager = [NSFileManager defaultManager];

            if ([fileManager fileExistsAtPath:[destinationURL path]]) {
                [fileManager removeItemAtURL:destinationURL error:&error];
                if (debug) {
                    if (error == nil) {
                        NSLog(@"delete content file successfully");
                    } else {
                        NSLog(@"cannot delete content file: %@", [error localizedDescription]);
                    }
                }
            }
        }
        result([NSNull null]);
    } else {
        result(ERROR_INVALID_TASK_ID);
    }
}

# pragma mark - FlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [registrar addApplicationDelegate: [[FlutterDownloaderPlugin alloc] init:registrar]];
}

+ (void)setPluginRegistrantCallback:(FlutterPluginRegistrantCallback)callback {
  registerPlugins = callback;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"initialize" isEqualToString:call.method]) {
        [self initializeMethodCall:call result:result];
    } else if ([@"didInitializeDispatcher" isEqualToString:call.method]) {
        [self didInitializeDispatcherMethodCall:call result:result];
    } else if ([@"registerCallback" isEqualToString:call.method]) {
        [self registerCallbackMethodCall:call result:result];
    } else if ([@"enqueue" isEqualToString:call.method]) {
        [self enqueueMethodCall:call result:result];
    } else if ([@"loadTasks" isEqualToString:call.method]) {
        [self loadTasksMethodCall:call result:result];
    } else if ([@"loadTasksWithRawQuery" isEqualToString:call.method]) {
        [self loadTasksWithRawQueryMethodCall:call result:result];
    } else if ([@"cancel" isEqualToString:call.method]) {
        [self cancelMethodCall:call result:result];
    } else if ([@"cancelAll" isEqualToString:call.method]) {
        [self cancelAllMethodCall:call result:result];
    } else if ([@"pause" isEqualToString:call.method]) {
        [self pauseMethodCall:call result:result];
    } else if ([@"resume" isEqualToString:call.method]) {
        [self resumeMethodCall:call result:result];
    } else if ([@"retry" isEqualToString:call.method]) {
        [self retryMethodCall:call result:result];
    } else if ([@"open" isEqualToString:call.method]) {
        [self openMethodCall:call result:result];
    } else if ([@"remove" isEqualToString:call.method]) {
        [self removeMethodCall:call result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (BOOL)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler {
    self.backgroundTransferCompletionHandler = completionHandler;
    //TODO: setup background isolate in case the application is re-launched from background to handle download event
    return YES;
}

- (void)applicationWillTerminate:(nonnull UIApplication *)application
{
    if (debug) {
        NSLog(@"applicationWillTerminate:");
    }
    for (NSString* key in _runningTaskById) {
        if ([_runningTaskById[key][KEY_STATUS] intValue] < STATUS_COMPLETE) {
            [self updateTask:key status:STATUS_CANCELED progress:-1];
        }
    }
    _session = nil;
    _mainChannel = nil;
    _dbManager = nil;
    databaseQueue = nil;
    _runningTaskById = nil;
}

# pragma mark - NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) {
        if (debug) {
            NSLog(@"Unknown transfer size");
        }
    } else {
        NSString *taskId = [self identifierForTask:downloadTask];
        int progress = round(totalBytesWritten * 100 / (double)totalBytesExpectedToWrite);
        NSNumber *lastProgress = _runningTaskById[taskId][KEY_PROGRESS];
        if (([lastProgress intValue] == 0 || (progress > [lastProgress intValue] + STEP_UPDATE) || progress == 100) && progress != [lastProgress intValue]) {
            [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_RUNNING) andProgress:@(progress)];
            __typeof__(self) __weak weakSelf = self;
            dispatch_sync(databaseQueue, ^{
                [weakSelf updateTask:taskId status:STATUS_RUNNING progress:progress];
            });
            _runningTaskById[taskId][KEY_PROGRESS] = @(progress);
        }
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    if (debug) {
        NSLog(@"URLSession:downloadTask:didFinishDownloadingToURL:");
    }

    NSString *taskId = [self identifierForTask:downloadTask ofSession:session];
    NSDictionary *task = [self loadTaskWithId:taskId];
    NSURL *destinationURL = [self fileUrlOf:taskId taskInfo:task downloadTask:downloadTask];

    [_runningTaskById removeObjectForKey:taskId];

    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:[destinationURL path]]) {
        [fileManager removeItemAtURL:destinationURL error:nil];
    }

    BOOL success = [fileManager copyItemAtURL:location
                                        toURL:destinationURL
                                        error:&error];

    __typeof__(self) __weak weakSelf = self;
    if (success) {
        [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_COMPLETE) andProgress:@100];
        dispatch_sync(databaseQueue, ^{
            [weakSelf updateTask:taskId status:STATUS_COMPLETE progress:100];
        });
    } else {
        if (debug) {
            NSLog(@"Unable to copy temp file. Error: %@", [error localizedDescription]);
        }
        [self sendUpdateProgressForTaskId:taskId inStatus:@(STATUS_FAILED) andProgress:@(-1)];
        dispatch_sync(databaseQueue, ^{
            [weakSelf updateTask:taskId status:STATUS_FAILED progress:-1];
        });
    }
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (debug) {
        NSLog(@"URLSession:task:didCompleteWithError:");
    }
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) task.response;
    long httpStatusCode = (long)[httpResponse statusCode];
    if (debug) {
        NSLog(@"HTTP status code: %ld", httpStatusCode);
    }
    bool isSuccess = (httpStatusCode >= 200 && httpStatusCode < 300);
    if (error != nil || !isSuccess) {
        if (debug) {
            NSLog(@"Download completed with error: %@", error != nil ? [error localizedDescription] : @(httpStatusCode));
        }
        NSString *taskId = [self identifierForTask:task ofSession:session];
        NSDictionary *taskInfo = [self loadTaskWithId:taskId];
        NSNumber *resumable = taskInfo[KEY_RESUMABLE];
        if (![resumable boolValue]) {
            int status;
            if (error != nil) {
                status = [error code] == -999 ? STATUS_CANCELED : STATUS_FAILED;
            } else {
                status = STATUS_FAILED;
            }
            [_runningTaskById removeObjectForKey:taskId];
            [self sendUpdateProgressForTaskId:taskId inStatus:@(status) andProgress:@(-1)];
            __typeof__(self) __weak weakSelf = self;
            dispatch_sync(databaseQueue, ^{
                [weakSelf updateTask:taskId status:status progress:-1];
            });
        }
    }
}

-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    if (debug) {
        NSLog(@"URLSessionDidFinishEventsForBackgroundURLSession:");
    }
    // Check if all download tasks have been finished.
    [[self currentSession] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if ([downloadTasks count] == 0) {
            if (debug) {
                NSLog(@"all download tasks have been finished");
            }

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
                    localNotification.alertBody = self->_allFilesDownloadedMsg;
                    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
                }];
            }
        }
    }];
}


# pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return [UIApplication sharedApplication].delegate.window.rootViewController;
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application
{
    if (debug) {
        NSLog(@"Send the document to app %@  ...", application);
    }
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application
{
    if (debug) {
        NSLog(@"Finished sending the document to app %@  ...", application);
    }

}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
    if (debug) {
        NSLog(@"Finished previewing the document");
    }
}

@end
