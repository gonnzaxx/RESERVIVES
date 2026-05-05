import uuid
from typing import Dict, List

from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.active_admin_connections: List[WebSocket] = []
        self.active_reservation_connections: Dict[uuid.UUID, List[WebSocket]] = {}

    async def connect_admin(self, websocket: WebSocket):
        await websocket.accept()
        self.active_admin_connections.append(websocket)

    def disconnect_admin(self, websocket: WebSocket):
        if websocket in self.active_admin_connections:
            self.active_admin_connections.remove(websocket)

    async def broadcast_admin(self, message: dict):
        for connection in list(self.active_admin_connections):
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect_admin(connection)

    async def connect_reservations(self, websocket: WebSocket, user_id: uuid.UUID):
        await websocket.accept()
        self.active_reservation_connections.setdefault(user_id, []).append(websocket)

    def disconnect_reservations(self, websocket: WebSocket, user_id: uuid.UUID):
        sockets = self.active_reservation_connections.get(user_id, [])
        if websocket in sockets:
            sockets.remove(websocket)
        if not sockets and user_id in self.active_reservation_connections:
            del self.active_reservation_connections[user_id]

    async def broadcast_reservation_event(self, user_id: uuid.UUID, message: dict):
        sockets = list(self.active_reservation_connections.get(user_id, []))
        for connection in sockets:
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect_reservations(connection, user_id)

admin_ws_manager = ConnectionManager()
