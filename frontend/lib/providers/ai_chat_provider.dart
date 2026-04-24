import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/services/api_client.dart';

enum AiChatRole { user, assistant }

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
  });

  final AiChatRole role;
  final String text;
}

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
  });

  final List<AiChatMessage> messages;
  final bool isLoading;

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() => const AiChatState();

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final currentMessages = List<AiChatMessage>.from(state.messages)
      ..add(AiChatMessage(role: AiChatRole.user, text: trimmed));

    state = state.copyWith(messages: currentMessages, isLoading: true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/ai/chat',
        body: {'message': trimmed},
      ) as Map<String, dynamic>;
      final reply = (response['response'] ?? '').toString().trim();

      state = state.copyWith(
        messages: [
          ...currentMessages,
          AiChatMessage(
            role: AiChatRole.assistant,
            text: reply.isEmpty ? 'No se recibió respuesta de Vivi.' : reply,
          ),
        ],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...currentMessages,
          AiChatMessage(
            role: AiChatRole.assistant,
            text: 'Error al contactar con Vivi: $e',
          ),
        ],
        isLoading: false,
      );
    }
  }

  void resetChat() {
    state = const AiChatState();
  }
}

final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);
