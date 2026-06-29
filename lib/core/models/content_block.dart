import 'package:flutter/material.dart';

enum BlockType { text, voice, image, video, link }

enum TextSize { small, body, heading, title }

class ContentBlock {
  final String id;
  final BlockType type;
  // text block
  final String? text;
  final TextSize? textSize;
  // media blocks (voice/image/video)
  final String? mediaUrl;
  final int? durationSeconds; // voice only
  // link block
  final String? linkUrl;
  final String? linkTitle;

  const ContentBlock({
    required this.id,
    required this.type,
    this.text,
    this.textSize = TextSize.body,
    this.mediaUrl,
    this.durationSeconds,
    this.linkUrl,
    this.linkTitle,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    if (text != null) 'text': text,
    if (textSize != null) 'textSize': textSize!.name,
    if (mediaUrl != null) 'mediaUrl': mediaUrl,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (linkUrl != null) 'linkUrl': linkUrl,
    if (linkTitle != null) 'linkTitle': linkTitle,
  };

  factory ContentBlock.fromMap(Map<String, dynamic> m) => ContentBlock(
    id: m['id'] ?? UniqueKey().toString(),
    type: BlockType.values.byName(m['type'] ?? 'text'),
    text: m['text'] as String?,
    textSize: m['textSize'] != null
        ? TextSize.values.byName(m['textSize'] as String)
        : TextSize.body,
    mediaUrl: m['mediaUrl'] as String?,
    durationSeconds: m['durationSeconds'] as int?,
    linkUrl: m['linkUrl'] as String?,
    linkTitle: m['linkTitle'] as String?,
  );

  static ContentBlock newText() => ContentBlock(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    type: BlockType.text,
    text: '',
    textSize: TextSize.body,
  );

  ContentBlock copyWith({
    String? id,
    BlockType? type,
    String? text,
    TextSize? textSize,
    String? mediaUrl,
    int? durationSeconds,
    String? linkUrl,
    String? linkTitle,
  }) => ContentBlock(
    id: id ?? this.id,
    type: type ?? this.type,
    text: text ?? this.text,
    textSize: textSize ?? this.textSize,
    mediaUrl: mediaUrl ?? this.mediaUrl,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    linkUrl: linkUrl ?? this.linkUrl,
    linkTitle: linkTitle ?? this.linkTitle,
  );
}
