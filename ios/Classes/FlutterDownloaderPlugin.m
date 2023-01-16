#import "FlutterDownloaderPlugin.h"
#if __has_include(<flutter_downloader/flutter_downloader-Swift.h>)
#import <flutter_downloader/flutter_downloader-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_downloader-Swift.h"
#endif

@implementation FlutterDownloaderPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterDownloaderPlugin registerWithRegistrar:registrar];
}
@end
