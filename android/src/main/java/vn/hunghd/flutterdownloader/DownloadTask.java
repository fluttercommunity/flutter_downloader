package vn.hunghd.flutterdownloader;

public class DownloadTask {
    int primaryId;
    String taskId;
    int status;
    int progress;
    String url;
    String filename;
    String savedDir;
    String headers;
    String mimeType;
    boolean resumable;
    boolean showNotification;
    boolean openFileFromNotification;
    String notificationTitle;
    long timeCreated;
    boolean saveInPublicStorage;
    boolean allowCellular;

    DownloadTask(int primaryId, String taskId, int status, int progress, String url, String filename, String savedDir,
                 String headers, String mimeType, boolean resumable, boolean showNotification, boolean openFileFromNotification, String notificationTitle, long timeCreated, boolean saveInPublicStorage, boolean allowCellular) {
        this.primaryId = primaryId;
        this.taskId = taskId;
        this.status = status;
        this.progress = progress;
        this.url = url;
        this.filename = filename;
        this.savedDir = savedDir;
        this.headers = headers;
        this.mimeType = mimeType;
        this.resumable = resumable;
        this.showNotification = showNotification;
        this.openFileFromNotification = openFileFromNotification;
        this.notificationTitle = notificationTitle;
        this.timeCreated = timeCreated;
        this.saveInPublicStorage = saveInPublicStorage;
        this.allowCellular = allowCellular;
    }

    @Override
    public String toString() {
        return "DownloadTask{taskId=" + taskId + ", status=" + status + ", progress=" + progress + ", url=" + url + ", filename=" + filename + ", savedDir=" + savedDir + ", headers=" + headers + ", notificationTitle=" + notificationTitle + ", saveInPublicStorage= " + saveInPublicStorage + ", allowCellular=" + allowCellular + "}";
    }
}
