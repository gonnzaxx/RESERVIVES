/// Gestión de Navegación en la Sección de Servicios.
///
/// Mantiene el estado del índice de la pestaña activa en la pantalla de servicios.
/// Permite que la selección del usuario (ej: "Aulas", "Materiales", "Otros")
/// persista o se coordine entre diferentes componentes de la interfaz.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider global para controlar la navegación por pestañas en Servicios.
final servicesTabIndexProvider = NotifierProvider<ServicesTabIndexNotifier, int>(() {
  return ServicesTabIndexNotifier();
});

/// Notifier que gestiona el índice de la pestaña seleccionada.
class ServicesTabIndexNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  /// Actualiza el índice activo si es diferente al actual.
  void setIndex(int index) {
    if (state != index) {
      state = index;
    }
  }
}
