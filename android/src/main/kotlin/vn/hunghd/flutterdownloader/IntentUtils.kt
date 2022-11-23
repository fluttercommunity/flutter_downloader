package vn.hunghd.flutterdownloader

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.lang.Exception
import java.net.URLConnection
import kotlin.jvm.Synchronized

object IntentUtils {
    private fun buildIntent(context: Context, file: File, mime: String?): Intent {
        val intent = Intent(Intent.ACTION_VIEW)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val uri = FileProvider.getUriForFile(
                context,
                context.packageName + ".flutter_downloader.provider",
                file
            )
            intent.setDataAndType(uri, mime)
        } else {
            intent.setDataAndType(Uri.fromFile(file), mime)
        }
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return intent
    }

    @Synchronized
    fun validatedFileIntent(context: Context, path: String, contentType: String?): Intent? {
        val file = File(path)
        var intent = buildIntent(context, file, contentType)
        if (canBeHandled(context, intent)) {
            return intent
        }
        var mime: String? = null
        var inputFile: FileInputStream? = null
        try {
            inputFile = FileInputStream(path)
            mime = URLConnection.guessContentTypeFromStream(inputFile) // fails sometimes
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            if (inputFile != null) {
                try {
                    inputFile.close()
                } catch (e: IOException) {
                    e.printStackTrace()
                }
            }
        }
        if (mime == null) {
            mime = URLConnection.guessContentTypeFromName(path) // fallback to check file extension
        }
        if (mime != null) {
            intent = buildIntent(context, file, mime)
            if (canBeHandled(context, intent)) return intent
        }
        return null
    }

    private fun canBeHandled(context: Context, intent: Intent): Boolean {
        val manager = context.packageManager
        val results = manager.queryIntentActivities(intent, 0)
        // return if there is at least one app that can handle this intent
        return results.size > 0
    }
}
