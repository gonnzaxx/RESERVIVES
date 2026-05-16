"""
RESERVIVES - Gestor de conexiones WebSocket.

Mantiene las conexiones activas de administradores y de usuarios
para eventos de reservas en tiempo real.
"""

import uuid
from typing import Dict, List

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.active_admin_connections: List[WebSocket] = []
        self.active_reservation_connections: Dict[uuid.UUID, List[WebSocket]] = {}

    # Acepta la conexión WebSocket y la registra como conexión de admin
    async def connect_admin(self, websocket: WebSocket):
        await websocket.accept()
        self.active_admin_connections.append(websocket)

    # Elimina una conexión de admin de la lista (por desconexión o error)
    def disconnect_admin(self, websocket: WebSocket):
        if websocket in self.active_admin_connections:
            self.active_admin_connections.remove(websocket)

    # Envía un mensaje JSON a todos los admins conectados; descarta los que fallen
    async def broadcast_admin(self, message: dict):
        for connection in list(self.active_admin_connections):
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect_admin(connection)

    # Acepta la conexión WebSocket y la asocia al usuario concreto
    async def connect_reservations(self, websocket: WebSocket, user_id: uuid.UUID):
        await websocket.accept()
        self.active_reservation_connections.setdefault(user_id, []).append(websocket)

    # Elimina la conexión de un usuario y limpia la entrada si ya no tiene sockets
    def disconnect_reservations(self, websocket: WebSocket, user_id: uuid.UUID):
        sockets = self.active_reservation_connections.get(user_id, [])
        if websocket in sockets:
            sockets.remove(websocket)
        if not sockets and user_id in self.active_reservation_connections:
            del self.active_reservation_connections[user_id]

    # Envía un evento JSON a todos los sockets activos de un usuario concreto
    async def broadcast_reservation_event(self, user_id: uuid.UUID, message: dict):
        sockets = list(self.active_reservation_connections.get(user_id, []))
        for connection in sockets:
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect_reservations(connection, user_id)


# Instancia global compartida por todos los routers
admin_ws_manager = ConnectionManager()
