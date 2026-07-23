import 'package:isar/isar.dart';
import 'package:nim_chatter/model/ChatSession.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  late Isar _isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [ChatSessionSchema],
      directory: dir.path,
    );
  }

  // 전체 대화 세션 최근순으로 가져오기
  Future<List<ChatSession>> getAllSessions() async {
    return await _isar.chatSessions.where().sortByUpdatedAtDesc().findAll();
  }

  // 특정 세션 가져오기
  Future<ChatSession?> getSession(Id id) async {
    return await _isar.chatSessions.get(id);
  }

  // 세션 저장 또는 업데이트
  Future<Id> saveSession(ChatSession session) async {
    await _isar.writeTxn(() async {
      await _isar.chatSessions.put(session);
    });
    return session.id;
  }

  // 세션 삭제
  Future<void> deleteSession(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.chatSessions.delete(id);
    });
  }
}