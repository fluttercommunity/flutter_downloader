#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#if __has_include(<flutter_downloader/FlutterDownloaderPlugin.h>)
#import <flutter_downloader/FlutterDownloaderPlugin.h>
#else
#import "FlutterDownloaderPlugin.h"
#endif

@implementation AppDelegate

void registerPlugins(NSObject<FlutterPluginRegistry>* registry) {
    if (![registry hasPlugin:@"FlutterDownloaderPlugin"]) {
        [FlutterDownloaderPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterDownloaderPlugin"]];
    }
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  [FlutterDownloaderPlugin setPluginRegistrantCallback:registerPlugins];
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
