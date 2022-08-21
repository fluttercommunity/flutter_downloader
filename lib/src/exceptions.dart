/// Thrown when something bad happens on the Dart side of the flutter_downloader
/// plugin.
class FlutterDownloaderException implements Exception {
  /// Creates a new [FlutterDownloaderException].
  const FlutterDownloaderException({required this.message});

  /// Description of the problem.
  final String message;
}
