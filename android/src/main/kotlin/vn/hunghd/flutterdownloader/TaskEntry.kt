package vn.hunghd.flutterdownloader

import android.provider.BaseColumns

object TaskEntry : BaseColumns {
    const val TABLE_NAME = "task"
    const val COLUMN_NAME_TASK_ID = "task_id"
    const val COLUMN_NAME_STATUS = "status"
    const val COLUMN_NAME_PROGRESS = "progress"
    const val COLUMN_NAME_URL = "url"
    const val COLUMN_NAME_SAVED_DIR = "saved_dir"
    const val COLUMN_NAME_FILE_NAME = "file_name"
    const val COLUMN_NAME_MIME_TYPE = "mime_type"
    const val COLUMN_NAME_RESUMABLE = "resumable"
    const val COLUMN_NAME_HEADERS = "headers"
    const val COLUMN_NAME_SHOW_NOTIFICATION = "show_notification"
    const val COLUMN_NAME_OPEN_FILE_FROM_NOTIFICATION = "open_file_from_notification"
    const val COLUMN_NAME_TIME_CREATED = "time_created"
    const val COLUMN_SAVE_IN_PUBLIC_STORAGE = "save_in_public_storage"
    const val COLUMN_ALLOW_CELLULAR = "allow_cellular"
}
