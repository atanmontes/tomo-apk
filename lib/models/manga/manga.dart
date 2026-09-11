class MangaItem {
  final String id;
  final String title;
  final String cover;
  final String url;

  final String description;
  final List<String> authors;
  final List<String> tags;
  final String type;
  final String status;
  final String released;
  final bool officialTranslation;
  final bool animeAdaptation;
  final bool adultContent;
  final List<String> associatedNames;

  MangaItem({
    required this.id,
    required this.title,
    required this.cover,
    required this.url,
    this.description = '',
    this.authors = const [],
    this.tags = const [],
    this.type = '',
    this.status = '',
    this.released = '',
    this.officialTranslation = false,
    this.animeAdaptation = false,
    this.adultContent = false,
    this.associatedNames = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover': cover,
      'url': url,
      'description': description,
      'authors': authors,
      'tags': tags,
      'type': type,
      'status': status,
      'released': released,
      'officialTranslation': officialTranslation,
      'animeAdaptation': animeAdaptation,
      'adultContent': adultContent,
      'associatedNames': associatedNames,
    };
  }

  factory MangaItem.fromJson(Map<String, dynamic> json) {
    return MangaItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      cover: json['cover'] ?? '',
      url: json['url'] ?? '',
      description: json['description'] ?? '',
      authors: List<String>.from(json['authors'] ?? const []),
      tags: List<String>.from(json['tags'] ?? const []),
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      released: json['released'] ?? '',
      officialTranslation:
          json['officialTranslation'] ?? false,
      animeAdaptation:
          json['animeAdaptation'] ?? false,
      adultContent:
          json['adultContent'] ?? false,
      associatedNames:
          List<String>.from(json['associatedNames'] ?? const []),
    );
  }
}