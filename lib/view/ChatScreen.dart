import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:nim_chatter/model/ChatMessage.dart';
import 'package:nim_chatter/model/ChatSession.dart';
import 'package:nim_chatter/services/IsarService.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();
  final TextEditingController _maxTokensController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // Isar 관련 상태
  final IsarService _isarService = IsarService();
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession; // 현재 활성화된 세션 (null이면 새 대화)

  // NVIDIA 모델 설정
  final List<String> _presetModels = [
    'nvidia/nemotron-3-super-120b-a12b',
    'nvidia/nemotron-3-ultra-550b-a55b',
    'openai/gpt-oss-120b',
    'meta/llama-3.3-70b-instruct',
    'qwen/qwen3-next-80b-a3b-instruct',
    'deepseek-ai/deepseek-v4-flash',
    '직접 입력 (Custom)',
  ];

  late String _selectedModel;
  bool _isCustomModel = false;

  @override
  void initState() {
    super.initState();
    _selectedModel = _presetModels.first;
    _initIsarAndLoadHistory();
    _maxTokensController.text = '16384';
  }

  // Isar 초기화 및 대화 목록 로드
  Future<void> _initIsarAndLoadHistory() async {
    await _isarService.init();
    await _refreshSessions();
  }

  Future<void> _refreshSessions() async {
    final list = await _isarService.getAllSessions();
    setState(() {
      _sessions = list;
    });
  }

  // 새 대화방 시작
  void _startNewChat() {
    setState(() {
      _httpClient?.close();
      _currentSession = null;
      _messages.clear();
    });
    Navigator.pop(context); // Drawer 닫기
  }

  // 특정 히스토리 선택 시 대화 이어가기
  void _loadSession(ChatSession session) {
    setState(() {
      _httpClient?.close();
      _currentSession = session;
      _messages.clear();
      for (var m in session.messages) {
        _messages.add(ChatMessage(
          role: m.role ?? 'user',
          content: m.content ?? '',
          reasoning: m.reasoning ?? '',
        ));
      }
    });
    Navigator.pop(context); // Drawer 닫기
    _scrollToBottom();
  }

  // 세션 삭제
  Future<void> _deleteSession(Id id) async {
    await _isarService.deleteSession(id);
    if (_currentSession?.id == id) {
      _startNewChat();
    }
    await _refreshSessions();
  }

  // DB에 현재 대화 저장/업데이트
  Future<void> _saveCurrentStateToIsar() async {
    if (_messages.isEmpty) return;

    final now = DateTime.now();
    final firstUserMsg = _messages.firstWhere(
          (m) => m.role == 'user',
      orElse: () => ChatMessage(role: 'user', content: 'New Chat'),
    );

    // 제목은 첫 메시지의 최대 20자
    final title = firstUserMsg.content.length > 20
        ? '${firstUserMsg.content.substring(0, 20)}...'
        : firstUserMsg.content;

    ChatSession sessionToSave = _currentSession ?? ChatSession()
      ..createdAt = now;

    sessionToSave.title = title.isEmpty ? 'New Chat' : title;
    sessionToSave.updatedAt = now;
    sessionToSave.messages = _messages.map((m) {
      return ChatMessageItem()
        ..role = m.role
        ..content = m.content
        ..reasoning = m.reasoning;
    }).toList();

    final savedId = await _isarService.saveSession(sessionToSave);
    sessionToSave.id = savedId;
    _currentSession = sessionToSave;

    await _refreshSessions();
  }

  String get _currentModelId {
    return _isCustomModel ? _customModelController.text.trim() : _selectedModel;
  }

  // API 및 모델 설정 다이얼로그 (배경 반투명, 최소 너비 500, ... 처리)
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black.withValues(alpha: 0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFF76B900)),
                  SizedBox(width: 8),
                  Text('API 및 모델 설정', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'NVIDIA API Key (nvapi-...)',
                          hintText: 'build.nvidia.com 발급 키',
                          prefixIcon: Icon(Icons.key),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedModel,
                        isExpanded: true,
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: '모델 선택',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _presetModels.map((model) {
                          return DropdownMenuItem(
                            value: model,
                            child: Text(
                              model,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              _selectedModel = val;
                              _isCustomModel = (val == '직접 입력 (Custom)');
                            });
                            setState(() {
                              _selectedModel = val;
                              _isCustomModel = (val == '직접 입력 (Custom)');
                            });
                          }
                        },
                      ),
                      if (_isCustomModel) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customModelController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: '커스텀 모델 ID',
                            hintText: 'org/model-name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _maxTokensController,
                        keyboardType: TextInputType.number, // 숫자 키패드 띄우기
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly, // 숫자만 입력 허용 (0-9)
                        ],
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Default MaxTokens 16384 ',
                          hintText: '16384',
                          prefixIcon: Icon(Icons.key),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF76B900),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 메시지 전송 및 Isar 저장

  http.Client? _httpClient;

  Future<void> _sendMessage() async {
    String apiKey = _apiKeyController.text.trim();
    final userText = _messageController.text.trim();
    final modelId = _currentModelId;
    final maxTokens = _maxTokensController.text.trim();

    if (apiKey.isEmpty) {
      _showSnackBar('NVIDIA API Key를 먼저 설정해 주세요.');
      _showSettingsDialog();
      return;
    }

    if (!apiKey.startsWith('nvapi-')) apiKey = 'nvapi-$apiKey';
    if (userText.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: userText));
      _messages.add(ChatMessage(role: 'assistant', reasoning: '', content: ''));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    final assistantIndex = _messages.length - 1;

    try {
      _httpClient = http.Client();
      final request = http.Request(
        'POST',
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
      );

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Accept': 'text/event-stream',
      });

      request.body = jsonEncode({
        'model': modelId,
        'messages': _messages
            .sublist(0, assistantIndex)
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        'temperature': 1.0,
        'top_p': 0.95,
        'max_tokens': int.parse(maxTokens),
        'stream': true,
        'chat_template_kwargs': {'enable_thinking': true},
        'reasoning_budget': int.parse(maxTokens),
      });

      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        await response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach((line) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') return;

            try {
              final json = jsonDecode(dataStr);
              final choices = json['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'];

                final reasoningChunk = delta['reasoning_content'];
                if (reasoningChunk != null && reasoningChunk
                    .toString()
                    .isNotEmpty) {
                  setState(() {
                    _messages[assistantIndex].reasoning +=
                        reasoningChunk.toString();
                  });
                }

                final contentChunk = delta['content'];
                if (contentChunk != null && contentChunk
                    .toString()
                    .isNotEmpty) {
                  setState(() {
                    _messages[assistantIndex].content +=
                        contentChunk.toString();
                  });
                }

                _scrollToBottom();
              }
            } catch (_) {}
          }
        });
      } else {
        final errorBody = await response.stream.bytesToString();
        _showSnackBar('API 오류 (${response.statusCode}): $errorBody');
        setState(() => _messages.removeAt(assistantIndex));
      }
    } catch (e) {
      debugPrint('네트워크 오류: $e');
      if (_messages.isNotEmpty && _messages.last.content.isEmpty) {
        setState(() => _messages.removeLast());
      }
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
      // 메시지 응답 완료 후 Isar DB에 대화 저장
      await _saveCurrentStateToIsar();
    }
  }

  void _cancelStreaming() {
    if (_isLoading) {
      _httpClient?.close(); // HTTP 커넥션을 강제로 닫아 스트림 수신 중단
      _httpClient = null;
      setState(() {
        _isLoading = false;
      });

      _showSnackBar('응답 생성이 취소되었습니다.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 1)
      )
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final isUser = msg.role == 'user';
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF76B900).withValues(alpha: 0.15) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUser ? const Color(0xFF76B900) : Colors.grey[800]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && msg.reasoning.isNotEmpty) ...[
              InkWell(
                onTap: () => setState(() => msg.isExpanded = !msg.isExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology, size: 18, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        msg.content.isEmpty ? 'Thinking Process...' : 'Thought Process',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        msg.isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              if (msg.isExpanded) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: MarkdownBody(
                    data: msg.reasoning,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: TextStyle(fontSize: 13, color: Colors.grey[400], fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
            if (msg.content.isNotEmpty)
              MarkdownBody(
                data: msg.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white),
                  blockquoteDecoration: BoxDecoration(
                    color: Colors.black, // 또는 Colors.grey[900] (어두운 회색)
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                      left: BorderSide(color: Color(0xFF76B900), width: 4), // 왼쪽 테두리에 포인트 컬러(NVIDIA Green) 부여
                    ),
                  ),
                  blockquotePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                ),
              )
            else if (!isUser && msg.reasoning.isEmpty)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Thinking...', style: TextStyle(color: Colors.grey)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentSession?.title ?? 'New Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'API 및 모델 설정',
            onPressed: _showSettingsDialog,
          ),
        ],
      ),

      // 좌측 대화 히스토리 사이드 메뉴 (Drawer)
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.black),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.developer_board, color: Color(0xFF76B900)),
                      SizedBox(width: 8),
                      Text(
                        'NVIDIA Chat',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF76B900),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    onPressed: _startNewChat,
                    icon: const Icon(Icons.add),
                    label: const Text('새 대화 시작'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _sessions.isEmpty
                  ? const Center(
                child: Text('저장된 히스토리가 없습니다.', style: TextStyle(color: Colors.grey)),
              )
                  : ListView.builder(
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final isSelected = _currentSession?.id == session.id;

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: const Color(0xFF76B900).withValues(alpha: 0.2),
                    leading: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                    title: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF76B900) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                      onPressed: () => _deleteSession(session.id),
                    ),
                    onTap: () => _loadSession(session),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        '우측 상단 설정(⚙️) 아이콘을 눌러\nNVIDIA API 키를 설정 후 대화를 시작하세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _showSettingsDialog,
                        icon: const Icon(Icons.settings, color: Color(0xFF76B900)),
                        label: const Text('설정 열기'),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      const Text('NVIDIA API 응답 스트리밍 중...'),
                      const SizedBox(width: 12),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _cancelStreaming,
                          icon: const Icon(Icons.stop_circle_outlined, size: 16),
                          label: const Text('취소', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    mouseCursor: SystemMouseCursors.click,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF76B900)),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}