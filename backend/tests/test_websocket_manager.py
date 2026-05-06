import uuid

import pytest

from app.services.websocket_manager import ConnectionManager


class _FakeWebSocket:
    def __init__(self, should_fail: bool = False):
        self.accepted = False
        self.should_fail = should_fail
        self.messages: list[dict] = []

    async def accept(self):
        self.accepted = True

    async def send_json(self, payload: dict):
        if self.should_fail:
            raise RuntimeError("socket failed")
        self.messages.append(payload)


@pytest.mark.asyncio
async def test_broadcast_reservation_event_sends_only_to_target_user():
    manager = ConnectionManager()
    user_a = uuid.uuid4()
    user_b = uuid.uuid4()
    ws_a = _FakeWebSocket()
    ws_b = _FakeWebSocket()

    await manager.connect_reservations(ws_a, user_a)
    await manager.connect_reservations(ws_b, user_b)

    payload = {"type": "reservation_updated", "data": {"reservation_id": "r1"}}
    await manager.broadcast_reservation_event(user_a, payload)

    assert ws_a.messages == [payload]
    assert ws_b.messages == []


@pytest.mark.asyncio
async def test_broadcast_reservation_event_disconnects_broken_socket():
    manager = ConnectionManager()
    user_id = uuid.uuid4()
    broken = _FakeWebSocket(should_fail=True)

    await manager.connect_reservations(broken, user_id)
    await manager.broadcast_reservation_event(user_id, {"type": "reservation_updated"})

    assert manager.active_reservation_connections.get(user_id, []) == []
