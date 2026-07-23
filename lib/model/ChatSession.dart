
import 'package:isar/isar.dart';

part 'ChatSession.g.dart';

@collection
class ChatSession {
  Id id = Isar.autoIncrement;

  late String title;
  late DateTime createdAt;
  late DateTime updatedAt;

  List<ChatMessageItem> messages = [];
}

@embedded
class ChatMessageItem {
  String? role;
  String? content;
  String? reasoning;
}