from app.models.usuario import RolUsuario
from app.services.auth_service import pick_primary_role, resolve_roles_from_group_ids


def test_resolve_roles_from_group_ids_supports_multiple_groups():
    roles = resolve_roles_from_group_ids(
        [
            "c98e0a43-24f4-476c-82bb-f386296a57d9",
            "a99c3475-f50d-4525-bd10-8383f1151ad9",
            "f4880587-dc04-4b40-a9be-b6ffcc064178",
        ]
    )
    assert RolUsuario.ALUMNO in roles
    assert RolUsuario.PROFESOR in roles


def test_pick_primary_role_prioritizes_jefatura_over_profesor():
    primary = pick_primary_role([RolUsuario.PROFESOR, RolUsuario.JEFE_ESTUDIOS])
    assert primary == RolUsuario.JEFE_ESTUDIOS
