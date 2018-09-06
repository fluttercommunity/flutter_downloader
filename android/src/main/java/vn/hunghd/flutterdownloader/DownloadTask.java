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
    boolean resumable;
    boolean showNotification;
    boolean clickToOpenDownloadedFile;

    DownloadTask(int primaryId, String taskId, int status, int progress, String url, String filename, String savedDir,
                 String headers, boolean resumable, boolean showNotification, boolean clickToOpenDownloadedFile) {
        this.primaryId = primaryId;
        this.taskId = taskId;
        this.status = status;
        this.progress = progress;
        this.url = url;
        this.filename = filename;
        this.savedDir = savedDir;
        this.headers = headers;
        this.resumable = resumable;
        this.showNotification = showNotification;
        this.clickToOpenDownloadedFile = clickToOpenDownloadedFile;
    }

    @Override
    public String toString() {
        return "DownloadTask{taskId=" + taskId + ",status=" + status + ",progress=" + progress + ",url=" + url + ",filename=" + filename + ",savedDir=" + savedDir + ",headers=" + headers + "}";
    }
}
