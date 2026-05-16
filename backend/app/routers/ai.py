from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user
from app.models.usuario import Usuario
from app.services.ai_rate_limit_service import (
    consume_ai_request_quota,
    is_ai_rate_limited,
)
from app.services.ai_service import AiService

router = APIRouter(prefix="/ai", tags=["IA"])


class AiChatHistoryItem(BaseModel):
    role: str
    content: str = Field(..., max_length=4000)


class AiChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)
    history: list[AiChatHistoryItem] = Field(default_factory=list, max_length=50)


class AiChatResponse(BaseModel):
    response: str


# Envía un mensaje al chat IA; rechaza con 429 si el usuario supera el límite de peticiones
@router.post("/chat", response_model=AiChatResponse, summary="Chat con IA")
async def chat_with_ai(
    data: AiChatRequest,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    request_count = await consume_ai_request_quota(db, current_user.id)
    if is_ai_rate_limited(request_count):
        raise HTTPException(
            status_code=429,
            detail="Has alcanzado el limite temporal de uso del chat IA.",
        )

    ai_service = AiService()
    history = [{"role": item.role, "content": item.content} for item in data.history]
    response = await ai_service.chat(data.message, history=history)
    return AiChatResponse(response=response)
