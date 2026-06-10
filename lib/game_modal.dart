class GameModal {
  final int id;
  final String title;
  final String coverUrl;
  final List<String> genres;
  final String summary;
  final double rating;
  final int hoursPlayed;
  final int? timeToBeatHours;
  final String? status;
  final int? userRating;
  final int year;
  final bool inLibrary;
  final String lastUpdated;

  const GameModal({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.genres,
    required this.summary,
    required this.rating,
    required this.hoursPlayed,
    this.timeToBeatHours,
    this.status,
    this.userRating,
    required this.year,
    this.inLibrary = false,
    required this.lastUpdated,
  });

  GameModal copyWith({
    int? id,
    String? title,
    String? coverUrl,
    List<String>? genres,
    String? summary,
    double? rating,
    int? hoursPlayed,
    int? timeToBeatHours,
    String? status,
    bool statusIsNull = false,
    int? year,
    int? userRating,
    bool? inLibrary,
    String? lastUpdated,
  }) {
    return GameModal(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      genres: genres ?? this.genres,
      summary: summary ?? this.summary,
      rating: rating ?? this.rating,
      hoursPlayed: hoursPlayed ?? this.hoursPlayed,
      timeToBeatHours: timeToBeatHours ?? this.timeToBeatHours,
      status: statusIsNull ? null : (status ?? this.status),
      userRating: userRating ?? this.userRating,
      year: year ?? this.year,
      inLibrary: inLibrary ?? this.inLibrary,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
