from collections import defaultdict, deque
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.middleware.auth_middleware import get_current_user
from app.models.usuario import Usuario
from app.services.ai_service import AiService

router = APIRouter(prefix="/ai", tags=["IA"])

_RATE_LIMIT_WINDOW = timedelta(minutes=1)
_RATE_LIMIT_MAX_REQUESTS = 10
_user_hits: dict[UUID, deque[datetime]] = defaultdict(deque)


class AiChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)


class AiChatResponse(BaseModel):
    response: str


def _check_rate_limit(user_id: UUID) -> None:
    now = datetime.now(timezone.utc)
    queue = _user_hits[user_id]
    min_allowed = now - _RATE_LIMIT_WINDOW

    while queue and queue[0] < min_allowed:
        queue.popleft()

    if len(queue) >= _RATE_LIMIT_MAX_REQUESTS:
        raise HTTPException(
            status_code=429,
            detail="Has alcanzado el límite temporal de uso del chat IA.",
        )

    queue.append(now)


@router.post("/chat", response_model=AiChatResponse, summary="Chat con IA")
async def chat_with_ai(
    data: AiChatRequest,
    current_user: Usuario = Depends(get_current_user),
):
    _check_rate_limit(current_user.id)
    ai_service = AiService()
    response = await ai_service.chat(data.message)
    return AiChatResponse(response=response)
