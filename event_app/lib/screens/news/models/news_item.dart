// models/news_item.dart
class NewsItem {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime createdAt;
  final int viewCount;
  final String? authorName;
  final bool isViewed;

  NewsItem({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.createdAt,
    required this.viewCount,
    this.authorName,
    this.isViewed = false,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      viewCount: json['view_count'] as int? ?? 0,
      authorName: json['author_name'] as String?,
      isViewed: json['is_viewed'] as bool? ?? false,
    );
  }

  NewsItem copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
    int? viewCount,
    String? authorName,
    bool? isViewed,
  }) {
    return NewsItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      viewCount: viewCount ?? this.viewCount,
      authorName: authorName ?? this.authorName,
      isViewed: isViewed ?? this.isViewed,
    );
  }
}
