#import <Flutter/Flutter.h>

@interface FlutterDownloaderPlugin : NSObject<FlutterPlugin>

@property (nonatomic, copy) void(^backgroundTransferCompletionHandler)();

+ (int) maximumConcurrentTask;

+ (void) setMaximumConcurrentTask:(int)val;

@end