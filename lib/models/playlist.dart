class Playlist {
  final int id;
  final String title;
  final String cover;
  final String? content;
  final int? duration;
  final bool? isReady;
  final int? count;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Playlist({
    required this.id,
    required this.title,
    required this.cover,
    this.content,
    this.duration,
    this.isReady,
    this.count,
    this.createdAt,
    this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      cover: json['cover'] ?? '',
      content: json['content'],
      duration: json['duration'],
      isReady: json['is_ready'] == 1,
      count: json['count'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover': cover,
      'content': content,
      'duration': duration,
      'is_ready': isReady,
      'count': count,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
