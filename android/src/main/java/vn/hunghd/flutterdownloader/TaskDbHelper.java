package vn.hunghd.flutterdownloader;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import vn.hunghd.flutterdownloader.TaskContract.TaskEntry;

public class TaskDbHelper extends SQLiteOpenHelper {
    public static final int DATABASE_VERSION = 3;
    public static final String DATABASE_NAME = "download_tasks.db";

    private static TaskDbHelper instance = null;

    private static final String SQL_CREATE_ENTRIES =
            "CREATE TABLE " + TaskEntry.TABLE_NAME + " (" +
                    TaskEntry._ID + " INTEGER PRIMARY KEY," +
                    TaskEntry.COLUMN_NAME_TASK_ID + " VARCHAR(256), " +
                    TaskEntry.COLUMN_NAME_URL + " TEXT, " +
                    TaskEntry.COLUMN_NAME_STATUS + " INTEGER DEFAULT 0, " +
                    TaskEntry.COLUMN_NAME_PROGRESS + " INTEGER DEFAULT 0, " +
                    TaskEntry.COLUMN_NAME_FILE_NAME + " TEXT, " +
                    TaskEntry.COLUMN_NAME_SAVED_DIR + " TEXT, " +
                    TaskEntry.COLUMN_NAME_HEADERS + " TEXT, " +
                    TaskEntry.COLUMN_NAME_MIME_TYPE + " VARCHAR(128), " +
                    TaskEntry.COLUMN_NAME_RESUMABLE + " TINYINT DEFAULT 0, " +
                    TaskEntry.COLUMN_NAME_SHOW_NOTIFICATION + " TINYINT DEFAULT 0, " +
                    TaskEntry.COLUMN_NAME_OPEN_FILE_FROM_NOTIFICATION + " TINYINT DEFAULT 0, " +
                    TaskEntry.COLUMN_NAME_TIME_CREATED + " INTEGER DEFAULT 0, " +
                    TaskEntry.COLUMN_SAVE_IN_PUBLIC_STORAGE + " TINYINT DEFAULT 0"
                    + ")";

    private static final String SQL_DELETE_ENTRIES =
            "DROP TABLE IF EXISTS " + TaskEntry.TABLE_NAME;


    public static TaskDbHelper getInstance(Context ctx) {
        // Use the application context, which will ensure that you
        // don't accidentally leak an Activity's context.
        // See this article for more information: http://bit.ly/6LRzfx
        if (instance == null) {
            instance = new TaskDbHelper(ctx.getApplicationContext());
        }
        return instance;
    }


    private TaskDbHelper(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL(SQL_CREATE_ENTRIES);
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        if (oldVersion == 2 && newVersion == 3) {
            db.execSQL("ALTER TABLE " + TaskEntry.TABLE_NAME + " ADD COLUMN " + TaskEntry.COLUMN_SAVE_IN_PUBLIC_STORAGE + " TINYINT DEFAULT 0");
        } else {
            db.execSQL(SQL_DELETE_ENTRIES);
            onCreate(db);
        }
    }

    @Override
    public void onDowngrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        onUpgrade(db, oldVersion, newVersion);
    }
}
