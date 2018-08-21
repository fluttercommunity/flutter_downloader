#import <Flutter/Flutter.h>

@interface FlutterDownloaderPlugin : NSObject<FlutterPlugin>

+ (int) maximumConcurrentTask;

+ (void) setMaximumConcurrentTask:(int)val;

@end