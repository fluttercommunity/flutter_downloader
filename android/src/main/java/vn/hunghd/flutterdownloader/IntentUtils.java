package vn.hunghd.flutterdownloader;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Build;

import androidx.core.content.FileProvider;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.net.URLConnection;
import java.util.List;

public class IntentUtils {
    
    private static Intent buildIntent(Context context, File file, String mime){
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
        Intent intent = buildIntent(context,file,contentType);
        if(validateIntent(context, intent))
            return intent;
        String mime = null;
        try {
            FileInputStream inputFile = new FileInputStream(path);
            mime = URLConnection.guessContentTypeFromStream(inputFile);//does not work in some target sdk version
            if(mime==null){
                mime = URLConnection.guessContentTypeFromName(path);//works fine

            }
        } catch (Exception ignored){

        }
        if(mime!=null) {
            intent = buildIntent(context,file,mime);
            if(validateIntent(context, intent))
                return intent;
        }
        return null;
    }
    
//     public static synchronized Intent getOpenFileIntent(Context context, String path, String contentType) {
//         File file = new File(path);
//         Intent intent = new Intent(Intent.ACTION_VIEW);
//         if (Build.VERSION.SDK_INT >= 24) {
//             Uri uri = FileProvider.getUriForFile(
//                     context,
//                     context.getPackageName() + ".flutter_downloader.provider", file);
//             intent.setDataAndType(uri, contentType);
//         } else {
//             intent.setDataAndType(Uri.fromFile(file), contentType);
//         }

//         intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
//         intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
//         return intent;
//     }

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
