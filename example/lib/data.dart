class DownloadItems {
  static const documents = [
    DownloadItem(
      name: 'Learning Android Studio',
      url: 'http://barbra-coco.dyndns.org/student/learning_android_studio.pdf',
    ),
    DownloadItem(
      name: 'Android Programming Cookbook',
      url:
          'http://enos.itcollege.ee/~jpoial/allalaadimised/reading/Android-Programming-Cookbook.pdf',
    ),
    DownloadItem(
      name: 'iOS Programming Guide',
      url: 'http://darwinlogic.com/uploads/education/iOS_Programming_Guide.pdf',
    ),
    DownloadItem(
      name: 'Objective-C Programming (Pre-Course Workbook',
      url:
          'https://www.bignerdranch.com/documents/objective-c-prereading-assignment.pdf',
    ),
  ];

  static const images = [
    DownloadItem(
      name: 'Arches National Park',
      url:
          'https://upload.wikimedia.org/wikipedia/commons/6/60/The_Organ_at_Arches_National_Park_Utah_Corrected.jpg',
    ),
    DownloadItem(
      name: 'Canyonlands National Park',
      url:
          'https://upload.wikimedia.org/wikipedia/commons/7/78/Canyonlands_National_Park%E2%80%A6Needles_area_%286294480744%29.jpg',
    ),
    DownloadItem(
      name: 'Death Valley National Park',
      url:
          'https://upload.wikimedia.org/wikipedia/commons/b/b2/Sand_Dunes_in_Death_Valley_National_Park.jpg',
    ),
    DownloadItem(
      name: 'Gates of the Arctic National Park and Preserve',
      url:
          'https://upload.wikimedia.org/wikipedia/commons/e/e4/GatesofArctic.jpg',
    ),
  ];

  static const videos = [
    DownloadItem(
      name: 'Big Buck Bunny',
      url:
          'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ),
    DownloadItem(
      name: 'Elephant Dream',
      url:
          'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    ),
  ];
}

class DownloadItem {
  const DownloadItem({required this.name, required this.url});

  final String name;
  final String url;
}
