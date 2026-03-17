class Channel {
  final String name;
  final String url;
  final bool isMovie;
  final bool isFavorite;
  final String? logo;
  final int? num;
  final String? categoryId;
  final String? categoryName;
  final String? epgChannelId;
  final String? streamId;
  final String? containerExtension;
  final String? streamType; // live, movie, series

  const Channel({
    required this.name,
    required this.url,
    this.isMovie = false,
    this.isFavorite = false,
    this.logo,
    this.num,
    this.categoryId,
    this.categoryName,
    this.epgChannelId,
    this.streamId,
    this.containerExtension,
    this.streamType,
  });

  Channel copyWith({
    String? name,
    String? url,
    bool? isMovie,
    bool? isFavorite,
    String? logo,
    int? num,
    String? categoryId,
    String? categoryName,
    String? epgChannelId,
    String? streamId,
    String? containerExtension,
    String? streamType,
  }) {
    return Channel(
      name: name ?? this.name,
      url: url ?? this.url,
      isMovie: isMovie ?? this.isMovie,
      isFavorite: isFavorite ?? this.isFavorite,
      logo: logo ?? this.logo,
      num: num ?? this.num,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      streamId: streamId ?? this.streamId,
      containerExtension: containerExtension ?? this.containerExtension,
      streamType: streamType ?? this.streamType,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'isMovie': isMovie,
        'isFavorite': isFavorite,
        'logo': logo,
        'num': num,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'epgChannelId': epgChannelId,
        'streamId': streamId,
        'containerExtension': containerExtension,
        'streamType': streamType,
      };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        name: json['name'] ?? '',
        url: json['url'] ?? '',
        isMovie: json['isMovie'] ?? false,
        isFavorite: json['isFavorite'] ?? false,
        logo: json['logo'],
        num: json['num'],
        categoryId: json['categoryId'],
        categoryName: json['categoryName'],
        epgChannelId: json['epgChannelId'],
        streamId: json['streamId'],
        containerExtension: json['containerExtension'],
        streamType: json['streamType'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          url == other.url &&
          isMovie == other.isMovie;

  @override
  int get hashCode => name.hashCode ^ url.hashCode ^ isMovie.hashCode;
}

class Category {
  final String id;
  final String name;
  final String type; // live, vod, series

  const Category({
    required this.id,
    required this.name,
    required this.type,
  });
}

class EpgProgram {
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  const EpgProgram({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  String get timeRange {
    String fmt(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${fmt(start)} - ${fmt(end)}';
  }
}

class XtreamPlaylist {
  final String name;
  final String serverUrl;
  final String username;
  final String password;

  const XtreamPlaylist({
    required this.name,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
      };

  factory XtreamPlaylist.fromJson(Map<String, dynamic> json) => XtreamPlaylist(
        name: json['name'],
        serverUrl: json['serverUrl'],
        username: json['username'],
        password: json['password'],
      );
}
