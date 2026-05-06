/// Interfaz de Asistencia Inteligente (Vivi).
///
/// Este servicio gestiona la interacción con la IA del centro. Mantiene el
/// historial de la conversación, controla los estados de carga...

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/services/api_client.dart';

/// Roles definidos para la conversación del chat.
enum AiChatRole { user, assistant }

/// Representa un mensaje individual dentro de la conversación.
class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
  });

  final AiChatRole role;
  final String text;
}

/// Estado inmutable que encapsula la lista de mensajes y el indicador de progreso.
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

/// Controlador de la lógica del chat con Vivi.
class AiChatNotifier extends Notifier<AiChatState> {
  DateTime? _lastSentAt;

  @override
  AiChatState build() => const AiChatState();

  /// Procesa el envío de un mensaje, gestiona la llamada a la API y maneja errores.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();

    // Validaciones previas: texto no vacío y no hay otra carga en curso.
    if (trimmed.isEmpty || state.isLoading) return;

    // Throttling: Evita el spam de mensajes (mínimo 700ms entre envíos).
    final now = DateTime.now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(milliseconds: 700)) {
      return;
    }
    _lastSentAt = now;

    // Actualización local inmediata del mensaje del usuario.
    final currentMessages = List<AiChatMessage>.from(state.messages)
      ..add(AiChatMessage(role: AiChatRole.user, text: trimmed));

    state = state.copyWith(messages: currentMessages, isLoading: true);

    try {
      // Pequeño retardo para suavizar la transición en la UI.
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

      // Manejo específico de errores de la API.
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

  /// Limpia el historial de la conversación actual.
  void resetChat() {
    state = const AiChatState();
  }
}

/// Provider global para el chat de IA.
final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);
