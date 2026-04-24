import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';

class ReservaDetalleScreen extends ConsumerWidget {
  const ReservaDetalleScreen({
    super.key,
    required this.reservaId,
    this.reservaInicial,
    this.tipoEspacio,
  });

  final String reservaId;
  final Reserva? reservaInicial;
  final String? tipoEspacio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', locale);

    if (reservaInicial != null) {
      return _ReservaDetalleBody(
        reserva: reservaInicial!,
        dateFormat: dateFormat,
      );
    }

    return FutureBuilder<Reserva>(
      future: _loadReserva(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle de reserva')),
            body: Center(
              child: RvApiErrorState(
                title: 'No se pudo cargar la reserva',
                subtitle: 'Inténtalo de nuevo en unos segundos.',
              ),
            ),
          );
        }

        return _ReservaDetalleBody(
          reserva: snapshot.data!,
          dateFormat: dateFormat,
        );
      },
    );
  }

  Future<Reserva> _loadReserva(WidgetRef ref) async {
    final apiClient = ref.read(apiClientProvider);

    if ((tipoEspacio ?? '').toUpperCase() == 'SERVICIO') {
      final response = await apiClient.get('/servicios/reservas/detalle/$reservaId');
      return Reserva.fromJson(response as Map<String, dynamic>);
    }

    if ((tipoEspacio ?? '').toUpperCase() == 'ESPACIO') {
      final response = await apiClient.get('/reservas-espacios/$reservaId');
      return Reserva.fromJson(response as Map<String, dynamic>);
    }

    try {
      final response = await apiClient.get('/reservas-espacios/$reservaId');
      return Reserva.fromJson(response as Map<String, dynamic>);
    } catch (_) {
      final response = await apiClient.get('/servicios/reservas/detalle/$reservaId');
      return Reserva.fromJson(response as Map<String, dynamic>);
    }
  }
}

class _ReservaDetalleBody extends StatelessWidget {
  const _ReservaDetalleBody({
    required this.reserva,
    required this.dateFormat,
  });

  final Reserva reserva;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de reserva')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          RvSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  label: 'Recurso',
                  value: reserva.nombreEspacio ?? 'Sin nombre',
                ),
                _DetailRow(
                  label: 'Tipo',
                  value: reserva.tipoEspacio ?? 'No especificado',
                ),
                _DetailRow(
                  label: 'Inicio',
                  value: dateFormat.format(reserva.fechaInicio),
                ),
                _DetailRow(
                  label: 'Fin',
                  value: dateFormat.format(reserva.fechaFin),
                ),
                _DetailRow(
                  label: 'Estado',
                  value: _estadoLabel(reserva.estado),
                ),
                if ((reserva.nombreUsuario ?? '').isNotEmpty)
                  _DetailRow(
                    label: 'Usuario',
                    value: reserva.nombreUsuario!,
                  ),
                if ((reserva.observaciones ?? '').trim().isNotEmpty)
                  _DetailRow(
                    label: 'Observaciones',
                    value: reserva.observaciones!,
                  ),
                _DetailRow(
                  label: 'Tokens consumidos',
                  value: '${reserva.tokensConsumidos}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _estadoLabel(EstadoReserva estado) {
    switch (estado) {
      case EstadoReserva.pendiente:
        return 'Pendiente';
      case EstadoReserva.aprobada:
        return 'Aprobada';
      case EstadoReserva.rechazada:
        return 'Rechazada';
      case EstadoReserva.cancelada:
        return 'Cancelada';
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
