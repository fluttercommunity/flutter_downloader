package vn.hunghd.flutterdownloader

import android.content.ComponentName
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.PackageManager.NameNotFoundException
import android.database.Cursor
import android.net.Uri
import android.util.Log
import androidx.work.Configuration
import androidx.work.WorkManager
import java.util.concurrent.Executors

class FlutterDownloaderInitializer : ContentProvider() {
    companion object {
        private const val TAG = "DownloaderInitializer"
        private const val DEFAULT_MAX_CONCURRENT_TASKS = 3
    }

    override fun onCreate(): Boolean {
        val maximumConcurrentTask = getMaxConcurrentTaskMetadata(requireContext())
        WorkManager.initialize(
            requireContext(), Configuration.Builder()
                .setExecutor(Executors.newFixedThreadPool(maximumConcurrentTask))
                .build()
        )
        return true
    }

    override fun query(uri: Uri, strings: Array<String>?, s: String?, strings1: Array<String>?, s1: String?): Cursor? {
        return null
    }

    override fun getType(uri: Uri): String? {
        return null
    }

    override fun insert(uri: Uri, contentValues: ContentValues?): Uri? {
        return null
    }

    override fun delete(uri: Uri, s: String?, strings: Array<String>?): Int {
        return 0
    }

    override fun update(uri: Uri, contentValues: ContentValues?, s: String?, strings: Array<String>?): Int {
        return 0
    }

    private fun getMaxConcurrentTaskMetadata(context: Context): Int {
        try {
            val providerInfo = context.packageManager.getProviderInfo(
                ComponentName(context, "vn.hunghd.flutterdownloader.FlutterDownloaderInitializer"),
                PackageManager.GET_META_DATA
            )
            val bundle = providerInfo.metaData
            val max = bundle.getInt(
                "vn.hunghd.flutterdownloader.MAX_CONCURRENT_TASKS",
                DEFAULT_MAX_CONCURRENT_TASKS
            )
            Log.d(TAG, "MAX_CONCURRENT_TASKS = $max")
            return max
        } catch (e: NameNotFoundException) {
            Log.e(TAG, "Failed to load meta-data, NameNotFound: " + e.message)
        } catch (e: NullPointerException) {
            Log.e(TAG, "Failed to load meta-data, NullPointer: " + e.message)
        }
        return DEFAULT_MAX_CONCURRENT_TASKS
    }
}