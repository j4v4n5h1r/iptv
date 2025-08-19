// lib/models/channel.dart
class Channel {
  final String name;
  final String url;
  final bool isMovie;
  final bool isFavorite;

  const Channel({
    required this.name,
    required this.url,
    this.isMovie = false,
    this.isFavorite = false,
  });

  Channel copyWith({
    String? name,
    String? url,
    bool? isMovie,
    bool? isFavorite,
  }) {
    return Channel(
      name: name ?? this.name,
      url: url ?? this.url,
      isMovie: isMovie ?? this.isMovie,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

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