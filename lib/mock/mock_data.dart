class MockGame {
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

  const MockGame({
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

  MockGame copyWith({
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
    return MockGame(
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

const List<MockGame> mockGames = [
  MockGame(
    id: 1,
    title: 'Elden Ring',
    coverUrl: 'https://picsum.photos/seed/elden-ring/800/1200',
    genres: ['RPG', 'Action', 'Open World'],
    summary:
        'Forge your own path through a vast shattered kingdom filled with secrets, massive bosses, and wonder.',
    rating: 97,
    hoursPlayed: 126,
    year: 2022,
    lastUpdated: '',
  ),
  MockGame(
    id: 2,
    title: 'The Witcher 3: Wild Hunt',
    coverUrl: 'https://picsum.photos/seed/witcher-3/800/1200',
    genres: ['RPG', 'Adventure', 'Fantasy'],
    summary:
        'As Geralt of Rivia, hunt monsters and shape a war-torn world with every choice you make.',
    rating: 96,
    hoursPlayed: 94,
    year: 2015,
    lastUpdated: '',
  ),
  MockGame(
    id: 3,
    title: 'God of War Ragnarök',
    coverUrl: 'https://picsum.photos/seed/god-of-war-ragnarok/800/1200',
    genres: ['Action', 'Adventure', 'Narrative'],
    summary:
        'Kratos and Atreus journey across the Nine Realms as prophecy, family, and fate collide.',
    rating: 94,
    hoursPlayed: 42,
    year: 2022,
    lastUpdated: '',
  ),
  MockGame(
    id: 4,
    title: 'Red Dead Redemption 2',
    coverUrl: 'https://picsum.photos/seed/red-dead-redemption-2/800/1200',
    genres: ['Action', 'Open World', 'Western'],
    summary:
        'Live the outlaw life in a cinematic frontier world packed with quiet moments and explosive drama.',
    rating: 95,
    hoursPlayed: 88,
    year: 2018,
    lastUpdated: '',
  ),
  MockGame(
    id: 5,
    title: 'Cyberpunk 2077',
    coverUrl: 'https://picsum.photos/seed/cyberpunk-2077/800/1200',
    genres: ['RPG', 'Action', 'Sci-Fi'],
    summary:
        'Explore Night City as a mercenary chasing power, cyberware, and the promise of a better future.',
    rating: 89,
    hoursPlayed: 63,
    year: 2020,
    lastUpdated: '',
  ),
  MockGame(
    id: 6,
    title: 'Baldur\'s Gate 3',
    coverUrl: 'https://picsum.photos/seed/baldurs-gate-3/800/1200',
    genres: ['RPG', 'Strategy', 'Fantasy'],
    summary:
        'Lead a party of companions through a reactive fantasy world full of choices, dice rolls, and chaos.',
    rating: 99,
    hoursPlayed: 51,
    year: 2023,
    lastUpdated: '',
  ),
  MockGame(
    id: 7,
    title: 'Hollow Knight',
    coverUrl: 'https://picsum.photos/seed/hollow-knight/800/1200',
    genres: ['Metroidvania', 'Adventure', 'Indie'],
    summary:
        'Descend into Hallownest and uncover a haunting insect kingdom with precision combat and secrets.',
    rating: 92,
    hoursPlayed: 28,
    year: 2017,
    lastUpdated: '',
  ),
  MockGame(
    id: 8,
    title: 'Black Myth: Wukong',
    coverUrl: 'https://picsum.photos/seed/black-myth-wukong/800/1200',
    genres: ['Action', 'RPG', 'Mythology'],
    summary:
        'A mythic action journey inspired by Journey to the West, built around cinematic boss encounters.',
    rating: 91,
    hoursPlayed: 17,
    year: 2024,
    lastUpdated: '',
  ),
  MockGame(
    id: 9,
    title: 'Hades',
    coverUrl: 'https://picsum.photos/seed/hades/800/1200',
    genres: ['Roguelike', 'Action', 'Indie'],
    summary:
        'Break out of the Underworld again and again in a fast, stylish roguelike steeped in Greek myth.',
    rating: 93,
    hoursPlayed: 36,
    year: 2020,
    lastUpdated: '',
  ),
  MockGame(
    id: 10,
    title: 'Disco Elysium',
    coverUrl: 'https://picsum.photos/seed/disco-elysium/800/1200',
    genres: ['RPG', 'Narrative', 'Detective'],
    summary:
        'Investigate a bizarre murder case through dialogue, skill checks, and an unforgettable interior monologue.',
    rating: 91,
    hoursPlayed: 9,
    year: 2019,
    lastUpdated: '',
  ),
  MockGame(
    id: 11,
    title: 'Horizon Zero Dawn',
    coverUrl: 'https://picsum.photos/seed/horizon-zero-dawn/800/1200',
    genres: ['Action', 'RPG', 'Open World'],
    summary:
        'A sprawling open-world adventure where machine hunting and ancient mysteries shape every horizon.',
    rating: 88,
    hoursPlayed: 53,
    year: 2017,
    lastUpdated: '',
  ),
  MockGame(
    id: 12,
    title: 'Alan Wake 2',
    coverUrl: 'https://picsum.photos/seed/alan-wake-2/800/1200',
    genres: ['Horror', 'Adventure', 'Narrative'],
    summary:
        'A tense psychological thriller that blends survival horror, live-action staging, and surreal storytelling.',
    rating: 90,
    hoursPlayed: 24,
    year: 2023,
    lastUpdated: '',
  ),
];

const List<Map<String, dynamic>> mockTopGenres = [
  {'genre': 'RPG', 'count': 8, 'fraction': 0.82},
  {'genre': 'Action', 'count': 6, 'fraction': 0.68},
  {'genre': 'Open World', 'count': 5, 'fraction': 0.56},
  {'genre': 'Horror', 'count': 3, 'fraction': 0.38},
  {'genre': 'Strategy', 'count': 2, 'fraction': 0.25},
];

List<MockGame> gamesByStatus(String status) =>
    mockGames.where((game) => game.status == status).toList();

List<MockGame> gamesByGenre(String genre) => mockGames
    .where((game) => game.genres.any((item) => item.toLowerCase() == genre.toLowerCase()))
    .toList();

MockGame gameByTitle(String title) =>
    mockGames.firstWhere((game) => game.title == title);

