class ChatMessage {
  final String role; // 'user' or 'assistant'
  String reasoning;  // AI의 생각 과정 (Thinking)
  String content;    // AI의 최종 답변
  bool isExpanded;   // 생각 과정 펼침/접기 상태

  ChatMessage({
    required this.role,
    this.reasoning = '',
    required this.content,
    this.isExpanded = true,
  });
}