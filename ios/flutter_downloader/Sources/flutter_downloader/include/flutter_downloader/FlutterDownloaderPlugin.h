#import <Flutter/Flutter.h>

@interface FlutterDownloaderPlugin : NSObject<FlutterPlugin>

@property (nonatomic, copy) void(^backgroundTransferCompletionHandler)(void);

@end
