package vn.hunghd.flutterdownloader;

import android.content.ComponentName;
import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.pm.ProviderInfo;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import java.util.concurrent.Executors;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.work.Configuration;
import androidx.work.WorkManager;

public class FlutterDownloaderInitializer extends ContentProvider {
    private final String TAG = "DownloaderInitializer";
    private final int DEFAULT_MAX_CONCURRENT_TASKS = 3;

    @Override
    public boolean onCreate() {
        int maximumConcurrentTask = getMaxConcurrentTaskMetadata(getContext());
        WorkManager.initialize(getContext(), new Configuration.Builder()
                .setExecutor(Executors.newFixedThreadPool(maximumConcurrentTask))
                .build());
        return true;
    }

    @Nullable
    @Override
    public Cursor query(
            @NonNull Uri uri,
            @Nullable String[] strings,
            @Nullable String s,
            @Nullable String[] strings1,
            @Nullable String s1) {
        return null;
    }

    @Nullable
    @Override
    public String getType(@NonNull Uri uri) {
        return null;
    }

    @Nullable
    @Override
    public Uri insert(
            @NonNull Uri uri,
            @Nullable ContentValues contentValues) {
        return null;
    }

    @Override
    public int delete(
            @NonNull Uri uri,
            @Nullable String s,
            @Nullable String[] strings) {
        return 0;
    }

    @Override
    public int update(
            @NonNull Uri uri,
            @Nullable ContentValues contentValues,
            @Nullable String s,
            @Nullable String[] strings) {
        return 0;
    }

    private int getMaxConcurrentTaskMetadata(Context context) {
        try {
            ProviderInfo pi = context.getPackageManager().getProviderInfo(
                    new ComponentName(context, "vn.hunghd.flutterdownloader.FlutterDownloaderInitializer"),
                    PackageManager.GET_META_DATA);
            Bundle bundle = pi.metaData;
            int max = bundle.getInt("vn.hunghd.flutterdownloader.MAX_CONCURRENT_TASKS", DEFAULT_MAX_CONCURRENT_TASKS);
            Log.d(TAG, "MAX_CONCURRENT_TASKS = " + max);
            return max;
        } catch (PackageManager.NameNotFoundException e) {
            Log.e(TAG, "Failed to load meta-data, NameNotFound: " + e.getMessage());
        } catch (NullPointerException e) {
            Log.e(TAG, "Failed to load meta-data, NullPointer: " + e.getMessage());
        }
        return DEFAULT_MAX_CONCURRENT_TASKS;
    }
}
