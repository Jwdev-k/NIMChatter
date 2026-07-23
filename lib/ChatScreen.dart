import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:nim_chatter/model/ChatMessage.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // NVIDIA Build 대표 추천 모델 목록
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
  }

  // 현재 사용할 실제 모델 ID 반환
  String get _currentModelId {
    if (_isCustomModel) {
      return _customModelController.text.trim();
    }
    return _selectedModel;
  }

  // 설정 다이얼로그 노출 메서드
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              // 1. 다이얼로그 배경 반투명 처리 및 스타일 설정
              backgroundColor: Colors.black.withValues(alpha: 0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[800]!),
              ),
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFF76B900)),
                  SizedBox(width: 8),
                  Text(
                    'API 및 모델 설정',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              // 2. 최소 너비를 500으로 고정하기 위해 SizedBox로 감싸기
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
                          hintText: 'build.nvidia.com에서 발급받은 API 키 입력',
                          prefixIcon: Icon(Icons.key),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 3. 드롭다운 텍스트 길어질 때 ... 수용
                      DropdownButtonFormField<String>(
                        initialValue: _selectedModel,
                        isExpanded: true, // 너비 전체 채우기
                        dropdownColor: Colors.grey[900], // 드롭다운 메뉴 배경색
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
                              overflow: TextOverflow.ellipsis, // 텍스트 넘어갈 시 ... 처리
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

  // NVIDIA Build API 호출 (OpenAI 호환 포맷)
  Future<void> _sendMessage() async {
    String apiKey = _apiKeyController.text.trim();
    final userText = _messageController.text.trim();
    final modelId = _currentModelId;

    if (apiKey.isEmpty) {
      _showSnackBar('NVIDIA API Key를 먼저 설정해 주세요 (우측 상단 ⚙️ 아이콘).');
      _showSettingsDialog();
      return;
    }

    // nvapi- 중복 부착 방지
    if (!apiKey.startsWith('nvapi-')) {
      apiKey = 'nvapi-$apiKey';
    }

    if (userText.isEmpty) return;

    if (modelId.isEmpty) {
      _showSnackBar('사용할 모델 ID를 입력해 주세요.');
      _showSettingsDialog();
      return;
    }

    // 1. 사용자 메시지 및 AI 메시지 공간 생성
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: userText));
      _messages.add(ChatMessage(role: 'assistant', reasoning: '', content: ''));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    final assistantIndex = _messages.length - 1;

    try {
      final client = http.Client();
      final request = http.Request(
        'POST',
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
      );

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Accept': 'text/event-stream',
      });

      // 2. 파이썬 OpenAI SDK의 extra_body 구조를 정확히 JSON 파라미터로 매핑
      request.body = jsonEncode({
        'model': modelId,
        'messages': _messages
            .sublist(0, assistantIndex)
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        'temperature': 1.0,
        'top_p': 0.95,
        'max_tokens': 16384,
        'stream': true,
        // extra_body 필드 반영
        'chat_template_kwargs': {'enable_thinking': true},
        'reasoning_budget': 16384,
      });

      final response = await client.send(request);

      if (response.statusCode == 200) {
        // 3. SSE 스트리밍 수신 (LineSplitter 사용)
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

                // (1) reasoning_content (생각 과정) 파싱 및 축적
                final reasoningChunk = delta['reasoning_content'];
                if (reasoningChunk != null && reasoningChunk.toString().isNotEmpty) {
                  setState(() {
                    _messages[assistantIndex].reasoning += reasoningChunk.toString();
                  });
                }

                // (2) content (최종 답변) 파싱 및 축적
                final contentChunk = delta['content'];
                if (contentChunk != null && contentChunk.toString().isNotEmpty) {
                  setState(() {
                    _messages[assistantIndex].content += contentChunk.toString();
                  });
                }

                _scrollToBottom();
              }
            } catch (_) {
              // 스트리밍 조각 JSON 파싱 예외 무시
            }
          }
        });
      } else {
        final errorBody = await response.stream.bytesToString();
        try {
          final errorJson = jsonDecode(errorBody);
          final errorMsg = errorJson['detail'] ?? errorJson['message'] ?? errorBody;
          _showSnackBar('API 오류 (${response.statusCode}): $errorMsg');
        } catch (_) {
          _showSnackBar('API 오류 (${response.statusCode}): $errorBody');
        }
        setState(() {
          _messages.removeAt(assistantIndex);
        });
      }
    } catch (e) {
      _showSnackBar('네트워크 오류가 발생했습니다: $e');
      if (_messages.isNotEmpty && _messages.last.content.isEmpty && _messages.last.reasoning.isEmpty) {
        setState(() {
          _messages.removeLast();
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
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
      SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
    );
  }

  // 메시지 카드 빌더 메서드 (마크다운 지원)
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
            // 1. Thinking (생각 과정) 블록
            if (!isUser && msg.reasoning.isNotEmpty) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    msg.isExpanded = !msg.isExpanded;
                  });
                },
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
                      code: TextStyle(backgroundColor: Colors.grey[800], fontSize: 12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],

            // 2. 최종 답변 (Content) 영역
            if (msg.content.isNotEmpty)
              MarkdownBody(
                data: msg.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white),
                  h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  code: TextStyle(
                    backgroundColor: Colors.grey[800],
                    color: Colors.lightGreenAccent,
                    fontSize: 13,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  tableBorder: TableBorder.all(color: Colors.grey[600]!, width: 1),
                  tableCellsPadding: const EdgeInsets.all(8.0),
                ),
              )
            else if (!isUser && msg.reasoning.isEmpty)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
        title: const Row(
          children: [
            Icon(Icons.developer_board, color: Color(0xFF76B900)),
            SizedBox(width: 8),
            Text('NVIDIA Build LLM Chat'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'API 및 모델 설정',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '대화 초기화',
            onPressed: () {
              setState(() => _messages.clear());
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 1. 대화 목록 영역
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Colors.grey,
                      ),
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
                  itemBuilder: (context, index) {
                    return _buildMessageItem(_messages[index]);
                  },
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('NVIDIA API 응답 스트리밍 중...'),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // 2. 메시지 입력 영역
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
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF76B900),
                    ),
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