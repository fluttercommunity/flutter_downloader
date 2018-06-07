package vn.hunghd.flutterdownloader;

import android.provider.BaseColumns;

public final class TaskContract {

    private TaskContract() {}

    public static class TaskEntry implements BaseColumns {
        public static final String TABLE_NAME = "task";
        public static final String COLUMN_NAME_TASK_ID = "task_id";
        public static final String COLUMN_NAME_STATUS = "status";
        public static final String COLUMN_NAME_PROGRESS = "progress";
        public static final String COLUMN_NAME_URL = "url";
        public static final String COLUMN_NAME_SAVED_DIR = "saved_dir";
        public static final String COLUMN_NAME_FILE_NAME = "file_name";
    }

}
