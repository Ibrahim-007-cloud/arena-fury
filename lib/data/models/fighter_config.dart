import 'dart:math';
import 'dart:ui';

import 'fighter_stats.dart';
import 'moveset.dart';

enum BodyType {
  slim('Slim'),
  standard('Standard'),
  heavy('Heavy');

  const BodyType(this.label);
  final String label;

  double get widthScale => switch (this) {
        BodyType.slim => 0.85,
        BodyType.standard => 1.0,
        BodyType.heavy => 1.3,
      };

  double get heightScale => switch (this) {
        BodyType.slim => 1.03,
        BodyType.standard => 1.0,
        BodyType.heavy => 0.97,
      };

  static BodyType fromName(String? name) => BodyType.values
      .firstWhere((b) => b.name == name, orElse: () => BodyType.standard);
}

enum Costume {
  gi('Martial Gi'),
  street('Street Wear'),
  armor('Battle Armor'),
  ninja('Shadow Garb');

  const Costume(this.label);
  final String label;

  static Costume fromName(String? name) =>
      Costume.values.firstWhere((c) => c.name == name, orElse: () => Costume.gi);
}

/// Everything needed to build and render a fighter. Built-in fighters are
/// defined in code (see roster.dart); custom fighters are stored in
/// Firestore at users/{uid}/fighters/{id}.
class FighterConfig {
  const FighterConfig({
    required this.id,
    required this.name,
    this.isBuiltIn = false,
    this.costume = Costume.gi,
    this.bodyType = BodyType.standard,
    this.primaryColor = const Color(0xFFD32F2F),
    this.secondaryColor = const Color(0xFF212121),
    this.skinColor = const Color(0xFFE0AC69),
    this.hairColor = const Color(0xFF1B1B1B),
    this.movesetId = 'striker',
    this.stats = const FighterStats(),
    this.faceImagePath,
    this.faceImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final bool isBuiltIn;
  final Costume costume;
  final BodyType bodyType;
  final Color primaryColor;
  final Color secondaryColor;
  final Color skinColor;
  final Color hairColor;
  final String movesetId;
  final FighterStats stats;

  /// Firebase Storage path of the cropped selfie, e.g. users/uid/faces/id.png
  final String? faceImagePath;
  final String? faceImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Moveset get moveset => Movesets.byId(movesetId);
  bool get hasFace => faceImagePath != null;

  static String newId() {
    final r = Random();
    return 'f_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${r.nextInt(1 << 30).toRadixString(36)}';
  }

  factory FighterConfig.blank() => FighterConfig(
        id: newId(),
        name: '',
        primaryColor: const Color(0xFF1E88E5),
        secondaryColor: const Color(0xFFFFFFFF),
      );

  FighterConfig copyWith({
    String? name,
    Costume? costume,
    BodyType? bodyType,
    Color? primaryColor,
    Color? secondaryColor,
    Color? skinColor,
    Color? hairColor,
    String? movesetId,
    FighterStats? stats,
    String? faceImagePath,
    String? faceImageUrl,
    bool clearFace = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FighterConfig(
      id: id,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn,
      costume: costume ?? this.costume,
      bodyType: bodyType ?? this.bodyType,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      skinColor: skinColor ?? this.skinColor,
      hairColor: hairColor ?? this.hairColor,
      movesetId: movesetId ?? this.movesetId,
      stats: stats ?? this.stats,
      faceImagePath: clearFace ? null : (faceImagePath ?? this.faceImagePath),
      faceImageUrl: clearFace ? null : (faceImageUrl ?? this.faceImageUrl),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore document shape (see docs/FIRESTORE_DATA_MODEL.md).
  Map<String, dynamic> toMap() => {
        'name': name,
        'costumeId': costume.name,
        'bodyType': bodyType.name,
        'primaryColor': primaryColor.toARGB32(),
        'secondaryColor': secondaryColor.toARGB32(),
        'skinColor': skinColor.toARGB32(),
        'hairColor': hairColor.toARGB32(),
        'movesetId': movesetId,
        'stats': stats.toMap(),
        'faceImagePath': faceImagePath,
        'faceImageUrl': faceImageUrl,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FighterConfig.fromMap(String id, Map<String, dynamic> map) {
    Color color(String key, int fallback) =>
        Color((map[key] as num?)?.toInt() ?? fallback);
    final statsRaw = map['stats'];
    return FighterConfig(
      id: id,
      name: (map['name'] as String?) ?? 'Fighter',
      costume: Costume.fromName(map['costumeId'] as String?),
      bodyType: BodyType.fromName(map['bodyType'] as String?),
      primaryColor: color('primaryColor', 0xFF1E88E5),
      secondaryColor: color('secondaryColor', 0xFFFFFFFF),
      skinColor: color('skinColor', 0xFFE0AC69),
      hairColor: color('hairColor', 0xFF1B1B1B),
      movesetId: Movesets.byId(map['movesetId'] as String?).id,
      stats: FighterStats.fromMap(
        statsRaw is Map ? Map<String, dynamic>.from(statsRaw) : null,
      ),
      faceImagePath: map['faceImagePath'] as String?,
      faceImageUrl: map['faceImageUrl'] as String?,
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  static DateTime? _readDate(Object? v) {
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
