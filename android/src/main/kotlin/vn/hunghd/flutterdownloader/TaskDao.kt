package vn.hunghd.flutterdownloader

import android.content.ContentValues
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.provider.BaseColumns

class TaskDao(private val dbHelper: TaskDbHelper) {
    private val projection = arrayOf(
        BaseColumns._ID,
        TaskEntry.COLUMN_NAME_TASK_ID,
        TaskEntry.COLUMN_NAME_PROGRESS,
        TaskEntry.COLUMN_NAME_STATUS,
        TaskEntry.COLUMN_NAME_URL,
        TaskEntry.COLUMN_NAME_FILE_NAME,
        TaskEntry.COLUMN_NAME_SAVED_DIR,
        TaskEntry.COLUMN_NAME_HEADERS,
        TaskEntry.COLUMN_NAME_MIME_TYPE,
        TaskEntry.COLUMN_NAME_RESUMABLE,
        TaskEntry.COLUMN_NAME_OPEN_FILE_FROM_NOTIFICATION,
        TaskEntry.COLUMN_NAME_SHOW_NOTIFICATION,
        TaskEntry.COLUMN_NAME_TIME_CREATED,
        TaskEntry.COLUMN_SAVE_IN_PUBLIC_STORAGE,
        TaskEntry.COLUMN_ALLOW_CELLULAR
    )

    fun insertOrUpdateNewTask(
        taskId: String?,
        url: String?,
        status: DownloadStatus,
        progress: Int,
        fileName: String?,
        savedDir: String?,
        headers: String?,
        showNotification: Boolean,
        openFileFromNotification: Boolean,
        saveInPublicStorage: Boolean,
        allowCellular: Boolean
    ) {
        val db = dbHelper.writableDatabase
        val values = ContentValues()
        values.put(TaskEntry.COLUMN_NAME_TASK_ID, taskId)
        values.put(TaskEntry.COLUMN_NAME_URL, url)
        values.put(TaskEntry.COLUMN_NAME_STATUS, status.ordinal)
        values.put(TaskEntry.COLUMN_NAME_PROGRESS, progress)
        values.put(TaskEntry.COLUMN_NAME_FILE_NAME, fileName)
        values.put(TaskEntry.COLUMN_NAME_SAVED_DIR, savedDir)
        values.put(TaskEntry.COLUMN_NAME_HEADERS, headers)
        values.put(TaskEntry.COLUMN_NAME_MIME_TYPE, "unknown")
        values.put(TaskEntry.COLUMN_NAME_SHOW_NOTIFICATION, if (showNotification) 1 else 0)
        values.put(
            TaskEntry.COLUMN_NAME_OPEN_FILE_FROM_NOTIFICATION,
            if (openFileFromNotification) 1 else 0
        )
        values.put(TaskEntry.COLUMN_NAME_RESUMABLE, 0)
        values.put(TaskEntry.COLUMN_NAME_TIME_CREATED, System.currentTimeMillis())
        values.put(TaskEntry.COLUMN_SAVE_IN_PUBLIC_STORAGE, if (saveInPublicStorage) 1 else 0)
        values.put(TaskEntry.COLUMN_ALLOW_CELLULAR, if (allowCellular) 1 else 0)
        db.beginTransaction()
        try {
            db.insertWithOnConflict(
                TaskEntry.TABLE_NAME,
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE
            )
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            db.endTransaction()
        }
    }

    fun loadAllTasks(): List<DownloadTask> {
        val db = dbHelper.readableDatabase
        val cursor = db.query(
            TaskEntry.TABLE_NAME,
            projection,
            null,
            null,
            null,
            null,
            null
        )
        val result: MutableList<DownloadTask> = ArrayList()
        while (cursor.moveToNext()) {
            result.add(parseCursor(cursor))
        }
        cursor.close()
        return result
    }

    fun loadTasksWithRawQuery(query: String?): List<DownloadTask> {
        val db = dbHelper.readableDatabase
        val cursor = db.rawQuery(query!!, null)
        val result: MutableList<DownloadTask> = ArrayList()
        while (cursor.moveToNext()) {
            result.add(parseCursor(cursor))
        }
        cursor.close()
        return result
    }

    fun loadTask(taskId: String): DownloadTask? {
        val db = dbHelper.readableDatabase
        val whereClause = TaskEntry.COLUMN_NAME_TASK_ID + " = ?"
        val whereArgs = arrayOf(taskId)
        val cursor = db.query(
            TaskEntry.TABLE_NAME,
            projection,
            whereClause,
            whereArgs,
            null,
            null,
            BaseColumns._ID + " DESC",
            "1"
        )
        var result: DownloadTask? = null
        while (cursor.moveToNext()) {
            result = parseCursor(cursor)
        }
        cursor.close()
        return result
    }

    fun updateTask(taskId: String, status: DownloadStatus, progress: Int) {
        val db = dbHelper.writableDatabase
        val values = ContentValues()
        values.put(TaskEntry.COLUMN_NAME_STATUS, status.ordinal)
        values.put(TaskEntry.COLUMN_NAME_PROGRESS, progress)
        db.beginTransaction()
        try {
            db.update(
                TaskEntry.TABLE_NAME,
                values,
                TaskEntry.COLUMN_NAME_TASK_ID + " = ?",
                arrayOf(taskId)
            )
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            db.endTransaction()
        }
    }

    fun updateTask(
        currentTaskId: String,
        newTaskId: String?,
        status: DownloadStatus,
        progress: Int,
        resumable: Boolean
    ) {
        val db = dbHelper.writableDatabase
        val values = ContentValues()
        values.put(TaskEntry.COLUMN_NAME_TASK_ID, newTaskId)
        values.put(TaskEntry.COLUMN_NAME_STATUS, status.ordinal)
        values.put(TaskEntry.COLUMN_NAME_PROGRESS, progress)
        values.put(TaskEntry.COLUMN_NAME_RESUMABLE, if (resumable) 1 else 0)
        values.put(TaskEntry.COLUMN_NAME_TIME_CREATED, System.currentTimeMillis())
        db.beginTransaction()
        try {
            db.update(
                TaskEntry.TABLE_NAME,
                values,
                TaskEntry.COLUMN_NAME_TASK_ID + " = ?",
                arrayOf(currentTaskId)
            )
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            db.endTransaction()
        }
    }

    fun updateTask(taskId: String, resumable: Boolean) {
        val db = dbHelper.writableDatabase
        val values = ContentValues()
        values.put(TaskEntry.COLUMN_NAME_RESUMABLE, if (resumable) 1 else 0)
        db.beginTransaction()
        try {
            db.update(
                TaskEntry.TABLE_NAME,
                values,
                TaskEntry.COLUMN_NAME_TASK_ID + " = ?",
                arrayOf(taskId)
            )
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            db.endTransaction()
        }
    }

    fun updateTask(taskId: String, filename: String?, mimeType: String?) {
        val db = dbHelper.writableDatabase
        val values = ContentValues()
        values.put(TaskEntry.COLUMN_NAME_FILE_NAME, filename)
        values.put(TaskEntry.COLUMN_NAME_MIME_TYPE, mimeType ?: "unknown")
        db.beginTransaction()
        try {
            db.update(
                TaskEntry.TABLE_NAME,
                values,
                TaskEntry.COLUMN_NAME_TASK_ID + " = ?",
                arrayOf(taskId)
            )
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            db.endTransaction()
        }
    }

    fun deleteTask(taskId: String) {
        val db = dbHelper.writableDatabase
        db.beginTransaction()
        try {
            val whereClause = TaskEntry.COLUMN_NAME_TASK_ID + " = ?"
            val whereArgs = arrayOf(taskId)
            db.delete(TaskEntry.TABLE_NAME, whereClause, whereArgs)
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            db.endTransaction()
        }
    }

    private fun parseCursor(cursor: Cursor): DownloadTask {
        val primaryId = cursor.getInt(cursor.getColumnIndexOrThrow(BaseColumns._ID))
        val taskId = cursor.getString(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_TASK_ID))
        val status = cursor.getInt(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_STATUS))
        val progress = cursor.getInt(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_PROGRESS))
        val url = cursor.getString(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_URL))
        val filename = cursor.getString(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_FILE_NAME))
        val savedDir = cursor.getString(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_SAVED_DIR))
        val headers = cursor.getString(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_HEADERS))
        val mimeType = cursor.getString(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_MIME_TYPE))
        val resumable = cursor.getShort(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_RESUMABLE)).toInt()
        val showNotification = cursor.getShort(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_SHOW_NOTIFICATION)).toInt()
        val clickToOpenDownloadedFile = cursor.getShort(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_OPEN_FILE_FROM_NOTIFICATION)).toInt()
        val timeCreated = cursor.getLong(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_NAME_TIME_CREATED))
        val saveInPublicStorage = cursor.getShort(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_SAVE_IN_PUBLIC_STORAGE)).toInt()
        val allowCelluar = cursor.getShort(cursor.getColumnIndexOrThrow(TaskEntry.COLUMN_ALLOW_CELLULAR)).toInt()
        return DownloadTask(
            primaryId,
            taskId,
            DownloadStatus.values()[status],
            progress,
            url,
            filename,
            savedDir,
            headers,
            mimeType,
            resumable == 1,
            showNotification == 1,
            clickToOpenDownloadedFile == 1,
            timeCreated,
            saveInPublicStorage == 1,
            allowCellular = allowCelluar == 1
        )
    }
}
