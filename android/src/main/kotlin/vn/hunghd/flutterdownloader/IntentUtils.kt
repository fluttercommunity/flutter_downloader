package vn.hunghd.flutterdownloader

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.webkit.MimeTypeMap
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

    /** Use extension-based MIME when server sent a generic type so the right app (e.g. PDF viewer) is chosen. */
    private fun effectiveMimeType(path: String, contentType: String?): String? {
        val generic = contentType == null ||
            contentType.startsWith("application/octet-stream") ||
            contentType.startsWith("application/unknown")
        if (generic) {
            val ext = path.substringAfterLast('.', "").lowercase()
            if (ext.isNotEmpty()) {
                val fromExt = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
                if (fromExt != null) return fromExt
            }
        }
        return contentType
    }

    @Synchronized
    fun validatedFileIntent(context: Context, path: String, contentType: String?): Intent? {
        val file = File(path)
        val mime = effectiveMimeType(path, contentType) ?: contentType
        var intent = buildIntent(context, file, mime)
        if (canBeHandled(context, intent)) {
            return intent
        }
        var fallbackMime: String? = null
        var inputFile: FileInputStream? = null
        try {
            inputFile = FileInputStream(path)
            fallbackMime = URLConnection.guessContentTypeFromStream(inputFile) // fails sometimes
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
        if (fallbackMime == null) {
            fallbackMime = URLConnection.guessContentTypeFromName(path) // fallback to check file extension
        }
        if (fallbackMime != null) {
            intent = buildIntent(context, file, fallbackMime)
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
