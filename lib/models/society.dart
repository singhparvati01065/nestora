// Data models for a society and its tower/flat hierarchy.
//
// A Society has N towers (A, B, C…). Each Tower can have its own number of
// floors, and EACH FLOOR can have its own number of flats. Flat numbers follow
// the scheme `{towerLetter}{floor}{flatIndex:2}` — e.g. Tower A, floor 1, flat
// 3 → `A103`.

class Flat {
  const Flat({
    required this.id,
    required this.number,
    required this.floor,
    required this.towerLetter,
  });

  final String id;
  final String number;
  final int floor;
  final String towerLetter;

  factory Flat.fromJson(Map<String, dynamic> json, {String? towerLetter}) {
    final number = json['number'] as String;
    return Flat(
      id: (json['id'] ?? '').toString(),
      number: number,
      floor: (json['floor'] as num).toInt(),
      // Leading letters of the flat number (e.g. "A" in "A101").
      towerLetter:
          towerLetter ??
          RegExp(r'^[A-Za-z]+').firstMatch(number)?.group(0) ??
          '',
    );
  }
}

class Tower {
  const Tower({
    required this.name,
    required this.letter,
    required this.flatsPerFloorCounts,
    required this.flats,
  });

  final String name;
  final String letter;

  /// Number of flats on each floor. `flatsPerFloorCounts[i]` is the flat count
  /// on floor `i + 1`. Its length is the number of floors.
  final List<int> flatsPerFloorCounts;

  final List<Flat> flats;

  int get floors => flatsPerFloorCounts.length;

  int get minFlatsPerFloor => flatsPerFloorCounts.isEmpty
      ? 0
      : flatsPerFloorCounts.reduce((a, b) => a < b ? a : b);

  int get maxFlatsPerFloor => flatsPerFloorCounts.isEmpty
      ? 0
      : flatsPerFloorCounts.reduce((a, b) => a > b ? a : b);

  /// "4" when every floor has 4 flats, "2–4" when they differ.
  String get flatsPerFloorLabel => minFlatsPerFloor == maxFlatsPerFloor
      ? '$minFlatsPerFloor'
      : '$minFlatsPerFloor–$maxFlatsPerFloor';

  /// Flats grouped by floor number, ascending.
  Map<int, List<Flat>> get flatsByFloor {
    final map = <int, List<Flat>>{};
    for (final flat in flats) {
      map.putIfAbsent(flat.floor, () => []).add(flat);
    }
    return map;
  }

  factory Tower.fromJson(Map<String, dynamic> json) {
    final letter = json['letter'] as String;
    final flats = ((json['flats'] as List?) ?? [])
        .map(
          (f) => Flat.fromJson(f as Map<String, dynamic>, towerLetter: letter),
        )
        .toList();
    // Derive per-floor flat counts from the flats.
    final byFloor = <int, int>{};
    for (final f in flats) {
      byFloor[f.floor] = (byFloor[f.floor] ?? 0) + 1;
    }
    final floors = byFloor.keys.toList()..sort();
    return Tower(
      name: json['name'] as String,
      letter: letter,
      flatsPerFloorCounts: [for (final fl in floors) byFloor[fl]!],
      flats: flats,
    );
  }
}

/// Per-tower configuration entered during setup. `flatsPerFloor[i]` is the flat
/// count on floor `i + 1`; its length is the tower's floor count.
class TowerSpec {
  TowerSpec({required this.flatsPerFloor});

  List<int> flatsPerFloor;

  int get floors => flatsPerFloor.length;
}

class Society {
  Society({
    this.id = '',
    required this.name,
    required this.address,
    required this.towers,
    this.city,
    this.state,
    this.logoUrl,
    this.hasTowers = true,
  });

  String id;
  String name;
  String address;

  /// City and state, shown to the super admin alongside the free-form address.
  /// Null until the admin fills them in.
  String? city;
  String? state;

  List<Tower> towers;

  /// Stored path of the society logo; null falls back to the name's initial.
  String? logoUrl;

  /// False when the society is one building with no towers: its flats are
  /// numbered 101, 102 rather than A101, and the UI drops all tower language.
  /// Fixed at creation — changing it would renumber every flat.
  bool hasTowers;

  factory Society.fromJson(Map<String, dynamic> json) {
    return Society(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String,
      address: json['address'] as String,
      city: json['city'] as String?,
      state: json['state'] as String?,
      logoUrl: json['logoUrl'] as String?,
      hasTowers: (json['hasTowers'] as bool?) ?? true,
      towers: ((json['towers'] as List?) ?? [])
          .map((t) => Tower.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  int get numberOfTowers => towers.length;

  /// Every flat across all towers, in tower/floor order.
  List<Flat> get allFlats =>
      towers.expand((tower) => tower.flats).toList(growable: false);

  int get totalFlats =>
      towers.fold(0, (sum, tower) => sum + tower.flats.length);

  int get minFloors => towers.isEmpty
      ? 0
      : towers.map((t) => t.floors).reduce((a, b) => a < b ? a : b);

  int get maxFloors => towers.isEmpty
      ? 0
      : towers.map((t) => t.floors).reduce((a, b) => a > b ? a : b);

  /// "5" when every tower has 5 floors, "5–8" when they differ.
  String get floorsLabel =>
      minFloors == maxFloors ? '$minFloors' : '$minFloors–$maxFloors';

  /// Builds a society, generating each floor's flats from its own count.
  factory Society.generate({
    required String name,
    required String address,
    required List<TowerSpec> towerSpecs,
  }) {
    final towers = <Tower>[];
    for (var t = 0; t < towerSpecs.length; t++) {
      final spec = towerSpecs[t];
      final letter = String.fromCharCode(65 + t); // A, B, C…
      final flats = <Flat>[];
      for (var floor = 1; floor <= spec.floors; floor++) {
        final flatsOnFloor = spec.flatsPerFloor[floor - 1];
        for (var f = 1; f <= flatsOnFloor; f++) {
          final flatIndex = f.toString().padLeft(2, '0');
          flats.add(
            Flat(
              id: '',
              number: '$letter$floor$flatIndex',
              floor: floor,
              towerLetter: letter,
            ),
          );
        }
      }
      towers.add(
        Tower(
          name: 'Tower $letter',
          letter: letter,
          flatsPerFloorCounts: List<int>.from(spec.flatsPerFloor),
          flats: flats,
        ),
      );
    }

    return Society(name: name, address: address, towers: towers);
  }
}
