from pydantic import BaseModel, Field
from datetime import datetime
from uuid import UUID
from typing import List, Optional


class EncuestaOpcionBase(BaseModel):
    texto: str = Field(..., max_length=255)
    orden: int = 0


class EncuestaOpcionCreate(EncuestaOpcionBase):
    pass


class EncuestaOpcion(EncuestaOpcionBase):
    id: UUID
    encuesta_id: UUID

    class Config:
        from_attributes = True


class EncuestaBase(BaseModel):
    titulo: str
    descripcion: Optional[str] = None
    fecha_fin: datetime
    activa: bool = True


class EncuestaCreate(EncuestaBase):
    opciones: List[EncuestaOpcionCreate] = Field(..., min_length=2)


class EncuestaUpdate(BaseModel):
    titulo: Optional[str] = None
    descripcion: Optional[str] = None
    fecha_fin: Optional[datetime] = None
    activa: Optional[bool] = None


class Encuesta(EncuestaBase):
    id: UUID
    created_at: datetime
    updated_at: datetime
    opciones: List[EncuestaOpcion]

    class Config:
        from_attributes = True


class VotoEncuestaCreate(BaseModel):
    opcion_id: UUID


class EncuestaResultadoOpcion(EncuestaOpcion):
    votos_count: int


class EncuestaResultados(EncuestaBase):
    id: UUID
    created_at: datetime
    updated_at: datetime
    opciones: List[EncuestaResultadoOpcion]
    total_votos: int
    voto_usuario_opcion_id: Optional[UUID] = None

    class Config:
        from_attributes = True