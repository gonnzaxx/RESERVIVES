import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict

class FavoritoBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

class FavoritoEspacioCreate(FavoritoBase):
    espacio_id: uuid.UUID

class FavoritoServicioCreate(FavoritoBase):
    servicio_id: uuid.UUID

class FavoritoEspacioResponse(FavoritoBase):
    id: uuid.UUID
    usuario_id: uuid.UUID
    espacio_id: uuid.UUID
    created_at: datetime

class FavoritoServicioResponse(FavoritoBase):
    id: uuid.UUID
    usuario_id: uuid.UUID
    servicio_id: uuid.UUID
    created_at: datetime