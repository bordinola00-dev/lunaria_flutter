class MoodEntry {
  MoodEntry({
    required this.id,
    required this.mood,
    required this.note,
    required this.createdAt,
    this.entryDate,
  });

  final String id;
  final String mood;
  final String note;
  final DateTime createdAt;
  final String? entryDate;

  Map<String, dynamic> toJson() => {
    'id': id,
    'mood': mood,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'entryDate': entryDate,
  };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
    id: json['id'] as String,
    mood: json['mood'] as String,
    note: json['note'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    entryDate: json['entryDate'] as String?,
  );
}

class DailyRoutine {
  const DailyRoutine({
    required this.id,
    required this.title,
    required this.description,
    required this.routineDate,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String description;
  final String routineDate;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'routineDate': routineDate,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory DailyRoutine.fromJson(Map<String, dynamic> json) => DailyRoutine(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    routineDate: json['routineDate'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
  );
}

class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class BeautyProduct {
  BeautyProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.shade,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final String shade;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'category': category,
    'shade': shade,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BeautyProduct.fromJson(Map<String, dynamic> json) => BeautyProduct(
    id: json['id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String? ?? '',
    category: json['category'] as String? ?? '',
    shade: json['shade'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class BeautyLook {
  BeautyLook({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BeautyLook.fromJson(Map<String, dynamic> json) => BeautyLook(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class Song {
  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String artist;
  final String url;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'url': url,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String? ?? '',
    url: json['url'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String url;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
