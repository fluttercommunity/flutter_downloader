package vn.hunghd.flutterdownloader

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.provider.BaseColumns

class TaskDbHelper private constructor(context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(SQL_CREATE_ENTRIES)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        update1to2(db, oldVersion)
        update2to3(db, oldVersion)
        update3to4(db, oldVersion)
    }

    private fun update1to2(db: SQLiteDatabase, oldVersion: Int) {
        if (oldVersion > 1) {
            return
        }
        db.execSQL(SQL_DELETE_ENTRIES)
        onCreate(db)
    }

    private fun update2to3(db: SQLiteDatabase, oldVersion: Int) {
        if (oldVersion > 2) {
            return
        }
        db.execSQL("ALTER TABLE " + TaskEntry.TABLE_NAME + " ADD COLUMN " + TaskEntry.COLUMN_SAVE_IN_PUBLIC_STORAGE + " TINYINT DEFAULT 0")
    }

    private fun update3to4(db: SQLiteDatabase, oldVersion: Int) {
        if (oldVersion > 3) {
            return
        }
        db.execSQL("ALTER TABLE ${TaskEntry.TABLE_NAME} ADD COLUMN ${TaskEntry.COLUMN_ALLOW_CELLULAR} TINYINT DEFAULT 1")
    }

    override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        onUpgrade(db, oldVersion, newVersion)
    }

    companion object {
        const val DATABASE_VERSION = 4
        const val DATABASE_NAME = "download_tasks.db"
        private var instance: TaskDbHelper? = null
        private const val SQL_CREATE_ENTRIES = (
            "CREATE TABLE " + TaskEntry.TABLE_NAME + " (" +
                BaseColumns._ID + " INTEGER PRIMARY KEY," +
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
                TaskEntry.COLUMN_SAVE_IN_PUBLIC_STORAGE + " TINYINT DEFAULT 0, " +
                TaskEntry.COLUMN_ALLOW_CELLULAR + " TINYINT DEFAULT 1" +
                ")"
            )
        private const val SQL_DELETE_ENTRIES = "DROP TABLE IF EXISTS ${TaskEntry.TABLE_NAME}"

        fun getInstance(ctx: Context?): TaskDbHelper {
            // Use the application context, which will ensure that you
            // don't accidentally leak an Activity's context.
            // See this article for more information: http://bit.ly/6LRzfx
            if (instance == null) {
                instance = TaskDbHelper(ctx!!.applicationContext)
            }
            return instance!!
        }
    }
}
