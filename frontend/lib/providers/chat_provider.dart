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
  DateTime? _lastSentAt;

  @override
  AiChatState build() => const AiChatState();

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;
    final now = DateTime.now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(milliseconds: 700)) {
      return;
    }
    _lastSentAt = now;

    final currentMessages = List<AiChatMessage>.from(state.messages)
      ..add(AiChatMessage(role: AiChatRole.user, text: trimmed));

    state = state.copyWith(messages: currentMessages, isLoading: true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
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
      var friendlyMessage = 'Error al contactar con Vivi. Inténtalo de nuevo.';
      if (e is ApiException) {
        if (e.statusCode == 429) {
          friendlyMessage =
              'Vivi está recibiendo demasiadas solicitudes. Espera unos segundos y vuelve a intentarlo.';
        } else if (e.message.trim().isNotEmpty) {
          friendlyMessage = e.message;
        }
      }

      state = state.copyWith(
        messages: [
          ...currentMessages,
          AiChatMessage(
            role: AiChatRole.assistant,
            text: friendlyMessage,
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
