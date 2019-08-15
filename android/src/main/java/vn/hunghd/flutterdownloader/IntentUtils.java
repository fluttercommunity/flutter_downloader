package vn.hunghd.flutterdownloader;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Build;

import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.URLConnection;
import java.util.List;

public class IntentUtils {

    private static Intent buildIntent(Context context, File file, String mime) {
        Intent intent = new Intent(Intent.ACTION_VIEW);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Uri uri = FileProvider.getUriForFile(context, context.getPackageName() + ".flutter_downloader.provider", file);
            intent.setDataAndType(uri, mime);
        } else {
            intent.setDataAndType(Uri.fromFile(file), mime);
        }
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        return intent;
    }

    public static synchronized Intent validatedFileIntent(Context context, String path, String contentType) {
        File file = new File(path);
        Intent intent = buildIntent(context, file, contentType);
        if (validateIntent(context, intent)) {
            return intent;
        }
        String mime = null;
        FileInputStream inputFile = null;
        try {
            inputFile = new FileInputStream(path);
            mime = URLConnection.guessContentTypeFromStream(inputFile);// fails sometime
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            if (inputFile != null) {
                try {
                    inputFile.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        if (mime == null) {
            mime = URLConnection.guessContentTypeFromName(path); // fallback to check file extension
        }
        if (mime != null) {
            intent = buildIntent(context, file, mime);
            if (validateIntent(context, intent))
                return intent;
        }
        return null;
    }

    private static boolean validateIntent(Context context, Intent intent) {
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
