// ── Avatar Model ──────────────────────────────────────────────────────────

class AvatarConfig {
  final int skinTone;    // 0–5
  final int faceShape;   // 0–3
  final int hairStyle;   // 0–7
  final int hairColor;   // 0–6
  final int eyeStyle;    // 0–4
  final int eyeColor;    // 0–4
  final int outfitStyle; // 0–5
  final int outfitColor; // 0–4
  final int accessory;   // 0–4 (0 = none)

  const AvatarConfig({
    required this.skinTone,
    required this.faceShape,
    required this.hairStyle,
    required this.hairColor,
    required this.eyeStyle,
    required this.eyeColor,
    required this.outfitStyle,
    required this.outfitColor,
    required this.accessory,
  });

  static AvatarConfig defaultConfig() => const AvatarConfig(
        skinTone: 1,
        faceShape: 0,
        hairStyle: 0,
        hairColor: 0,
        eyeStyle: 0,
        eyeColor: 0,
        outfitStyle: 0,
        outfitColor: 0,
        accessory: 0,
      );

  factory AvatarConfig.fromMap(Map<String, dynamic> map) => AvatarConfig(
        skinTone: (map['skinTone'] as num?)?.toInt() ?? 1,
        faceShape: (map['faceShape'] as num?)?.toInt() ?? 0,
        hairStyle: (map['hairStyle'] as num?)?.toInt() ?? 0,
        hairColor: (map['hairColor'] as num?)?.toInt() ?? 0,
        eyeStyle: (map['eyeStyle'] as num?)?.toInt() ?? 0,
        eyeColor: (map['eyeColor'] as num?)?.toInt() ?? 0,
        outfitStyle: (map['outfitStyle'] as num?)?.toInt() ?? 0,
        outfitColor: (map['outfitColor'] as num?)?.toInt() ?? 0,
        accessory: (map['accessory'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'skinTone': skinTone,
        'faceShape': faceShape,
        'hairStyle': hairStyle,
        'hairColor': hairColor,
        'eyeStyle': eyeStyle,
        'eyeColor': eyeColor,
        'outfitStyle': outfitStyle,
        'outfitColor': outfitColor,
        'accessory': accessory,
      };

  AvatarConfig copyWith({
    int? skinTone,
    int? faceShape,
    int? hairStyle,
    int? hairColor,
    int? eyeStyle,
    int? eyeColor,
    int? outfitStyle,
    int? outfitColor,
    int? accessory,
  }) =>
      AvatarConfig(
        skinTone: skinTone ?? this.skinTone,
        faceShape: faceShape ?? this.faceShape,
        hairStyle: hairStyle ?? this.hairStyle,
        hairColor: hairColor ?? this.hairColor,
        eyeStyle: eyeStyle ?? this.eyeStyle,
        eyeColor: eyeColor ?? this.eyeColor,
        outfitStyle: outfitStyle ?? this.outfitStyle,
        outfitColor: outfitColor ?? this.outfitColor,
        accessory: accessory ?? this.accessory,
      );
}
