package vn.hunghd.flutterdownloader

data class DownloadTask(
    var primaryId: Int,
    var taskId: String,
    var status: DownloadStatus,
    var progress: Int,
    var url: String,
    var filename: String?,
    var savedDir: String,
    var headers: String,
    var mimeType: String?,
    var resumable: Boolean,
    var showNotification: Boolean,
    var openFileFromNotification: Boolean,
    var timeCreated: Long,
    var saveInPublicStorage: Boolean,
    var allowCellular: Boolean
)
