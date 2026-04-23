from fastapi import WebSocket
from typing import List

class ConnectionManager:
    def __init__(self):
        self.active_admin_connections: List[WebSocket] = []

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

admin_ws_manager = ConnectionManager()
