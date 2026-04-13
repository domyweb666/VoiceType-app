import 'package:hive/hive.dart';

class TranscriptRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String rawText;

  @HiveField(3)
  String organizedText;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  int durationSeconds;

  TranscriptRecord({
    required this.id,
    required this.title,
    required this.rawText,
    required this.organizedText,
    required this.createdAt,
    required this.durationSeconds,
  });
}

class TranscriptRecordAdapter extends TypeAdapter<TranscriptRecord> {
  @override
  final int typeId = 0;

  @override
  TranscriptRecord read(BinaryReader reader) {
    return TranscriptRecord(
      id: reader.readString(),
      title: reader.readString(),
      rawText: reader.readString(),
      organizedText: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      durationSeconds: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, TranscriptRecord obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.rawText);
    writer.writeString(obj.organizedText);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.durationSeconds);
  }
}
