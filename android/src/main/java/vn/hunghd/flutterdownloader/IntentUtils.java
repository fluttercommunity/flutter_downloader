package vn.hunghd.flutterdownloader;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.support.v4.content.FileProvider;

import java.io.File;
import java.util.List;

public class IntentUtils {

    public static synchronized Intent getOpenFileIntent(Context context, String path, String contentType) {
        File file = new File(path);
        Uri uri = FileProvider.getUriForFile(context, context.getPackageName() + ".flutter_downloader.provider", file);
        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(uri, contentType);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        return intent;
    }

    public static synchronized boolean validateIntent(Context context, Intent intent) {
        PackageManager manager = context.getPackageManager();
        List<ResolveInfo> infos = manager.queryIntentActivities(intent, 0);
        if (infos.size() > 0) {
            //Then there is an Application(s) can handle this intent
            return true;
        } else {
            //No Application can handle this intent
            return false;
        }
    }

}
