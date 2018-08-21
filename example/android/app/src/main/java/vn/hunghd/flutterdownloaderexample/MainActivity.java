package vn.hunghd.flutterdownloaderexample;

import android.os.Bundle;
import io.flutter.app.FlutterActivity;
import io.flutter.plugins.GeneratedPluginRegistrant;
import vn.hunghd.flutterdownloader.FlutterDownloaderPlugin;

public class MainActivity extends FlutterActivity {
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    FlutterDownloaderPlugin.maximumConcurrentTask = 2;
    GeneratedPluginRegistrant.registerWith(this);
  }
}
