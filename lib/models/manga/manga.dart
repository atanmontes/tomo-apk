class MangaItem {
  final String id;
  final String title;
  final String cover;
  final String url;

  MangaItem({
    required this.id,
    required this.title,
    required this.cover,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover': cover,
      'url': url,
    };
  }

  factory MangaItem.fromJson(Map<String, dynamic> json) {
    return MangaItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      cover: json['cover'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
