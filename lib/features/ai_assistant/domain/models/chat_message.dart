enum MessageSender {
  user,
  assistant,
  system,
}

enum MessageStatus {
  sending,
  sent,
  failed,
}

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageStatus status;
  final String? errorMessage;
  final String? navigationRoute;
  final String? navigationTitle;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.errorMessage,
    this.navigationRoute,
    this.navigationTitle,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    MessageStatus? status,
    String? errorMessage,
    String? navigationRoute,
    String? navigationTitle,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      navigationRoute: navigationRoute ?? this.navigationRoute,
      navigationTitle: navigationTitle ?? this.navigationTitle,
    );
  }
}
