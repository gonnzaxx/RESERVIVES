"""
IES LUIS VIVES APP - Servicio de Lista de Espera.

Cuando un tramo está ocupado, el usuario puede unirse a la lista.
Al cancelarse esa reserva, se notifica al primero de la cola.
"""

import uuid
from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lista_espera import EstadoListaEspera, ListaEspera
from app.models.notificacion import TipoNotificacion
from app.models.reserva_espacio import EstadoReserva
from app.models.usuario import Usuario
from app.repositories.lista_espera_repo import ListaEsperaRepository
from app.repositories.reserva_espacio_repo import ReservaEspacioRepository
from app.schemas.reserva import ListaEsperaCreate
from app.services.tramo_service import TramoService
from app.utils.exceptions import (
    ConflictException,
    ForbiddenException,
    NotFoundException,
    ValidationException,
)


class ListaEsperaService:

    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = ListaEsperaRepository(session)
        self.reserva_repo = ReservaEspacioRepository(session)

    # Añade al usuario a la lista de espera para un espacio y tramo concretos.
    # Solo se puede unir si el tramo está realmente ocupado y el usuario no estaba ya en cola.
    async def unirse(self, usuario: Usuario, data: ListaEsperaCreate) -> ListaEspera:
        if data.fecha < date.today():
            raise ValidationException("No puedes unirte a la lista de espera para fechas pasadas")
        if data.fecha.weekday() >= 5:
            raise ValidationException("No se permiten reservas en fin de semana")

        # Verifica que el tramo está realmente ocupado antes de encolar
        tramo_svc = TramoService(self.session)
        tramo = await tramo_svc.get_tramo_by_id(data.tramo_id)
        if not tramo:
            raise ValidationException("Tramo no válido")

        disponibilidad = await tramo_svc.get_disponibilidad_espacio(data.espacio_id, data.fecha)
        disp_tramo = next((d for d in disponibilidad if d.tramo.id == data.tramo_id), None)
        if disp_tramo and disp_tramo.disponible:
            raise ValidationException(
                "El tramo está disponible; puedes reservarlo directamente"
            )

        # Comprobar que no esté ya en la lista
        existente = await self.repo.get_entrada_activa(
            usuario_id=usuario.id,
            espacio_id=data.espacio_id,
            tramo_id=data.tramo_id,
            fecha=data.fecha,
        )
        if existente:
            raise ConflictException("Ya estás en la lista de espera para este tramo")

        posicion = await self.repo.get_proxima_posicion(
            espacio_id=data.espacio_id,
            tramo_id=data.tramo_id,
            fecha=data.fecha,
        )

        entrada = ListaEspera(
            usuario_id=usuario.id,
            espacio_id=data.espacio_id,
            tramo_id=data.tramo_id,
            fecha=data.fecha,
            posicion=posicion,
            estado=EstadoListaEspera.ACTIVA,
        )
        entrada = await self.repo.create(entrada)
        return entrada

    # Cancela la entrada del usuario en la lista de espera
    async def abandonar(self, entrada_id: uuid.UUID, usuario: Usuario) -> ListaEspera:
        entrada = await self.repo.get_by_id(entrada_id)
        if not entrada:
            raise NotFoundException("ListaEspera", str(entrada_id))
        if entrada.usuario_id != usuario.id:
            raise ForbiddenException("No puedes cancelar una entrada de otro usuario")
        if entrada.estado == EstadoListaEspera.CANCELADA:
            raise ValidationException("Esta entrada ya está cancelada")

        entrada.estado = EstadoListaEspera.CANCELADA
        await self.session.flush()
        return entrada

    # Llamado al cancelarse una reserva: notifica al primer usuario de la cola para ese slot
    async def procesar_cancelacion(
        self,
        espacio_id: uuid.UUID,
        tramo_id: uuid.UUID,
        fecha: date,
        notification_service,
    ) -> None:
        siguiente = await self.repo.get_siguiente_en_cola(
            espacio_id=espacio_id,
            tramo_id=tramo_id,
            fecha=fecha,
        )
        if not siguiente:
            return

        siguiente.estado = EstadoListaEspera.NOTIFICADA
        await self.session.flush()

        nombre_espacio = siguiente.espacio.nombre if siguiente.espacio else "el espacio"
        await notification_service.create_for_user(
            usuario_id=siguiente.usuario_id,
            tipo=TipoNotificacion.LISTA_ESPERA_DISPONIBLE,
            titulo="¡Tramo disponible!",
            mensaje=(
                f'Se ha liberado un slot en "{nombre_espacio}" '
                f'para el {siguiente.fecha.strftime("%d/%m/%Y")}. '
                "¡Reserva antes de que se ocupe de nuevo!"
            ),
            referencia_id=str(siguiente.espacio_id),
        )
