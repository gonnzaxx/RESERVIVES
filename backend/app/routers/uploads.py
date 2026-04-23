import uuid
import shutil
from pathlib import Path
from fastapi import APIRouter, HTTPException, UploadFile, File

router = APIRouter(prefix="/uploads", tags=["Uploads"])

@router.post("/imagen", summary="Subir una imagen generica")
async def subir_imagen_generica(
    file: UploadFile = File(...),
    carpeta: str = "general"
):
    """
    Sube una imagen a una subcarpeta especifica (default: general).
    Retorna la URL relativa de la imagen.
    """
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="El archivo debe ser una imagen")

    # Seguridad: Evitar path traversal
    carpeta_segura = "".join([c for c in carpeta if c.isalnum() or c in ("-", "_")])
    if not carpeta_segura:
        carpeta_segura = "general"

    # Crear el directorio si no existe
    upload_dir = Path(f"uploads/{carpeta_segura}")
    upload_dir.mkdir(parents=True, exist_ok=True)

    # Generar un nombre seguro
    extension = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"{uuid.uuid4().hex[:12]}.{extension}"
    file_path = upload_dir / filename

    # Guardar archivo
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    return {"url": f"/api/uploads/{carpeta_segura}/{filename}"}
