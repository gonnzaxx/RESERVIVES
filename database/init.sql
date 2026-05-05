-- ============================================================
-- RESERVIVES - Script de inicialización de Base de Datos
-- IES Luis Vives - TFG DAM
-- ============================================================
-- Este script crea todas las tablas, tipos enumerados, índices
-- y constraints necesarios para la aplicación RESERVIVES.
-- ============================================================

-- Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";   -- Generación de UUIDs
CREATE EXTENSION IF NOT EXISTS "btree_gist";  -- Para exclusion constraints con tsrange

-- ============================================================
-- TIPOS ENUMERADOS
-- ============================================================

-- Roles de usuario en la aplicación
CREATE TYPE rol_usuario AS ENUM (
    'ALUMNO',
    'PROFESOR',
    'ADMIN',
    'CAFETERIA',
    'JEFE_ESTUDIOS',
    'SECRETARIA',
    'PROFESOR_SERVICIO'
);

-- Tipos de espacio reservable
CREATE TYPE tipo_espacio AS ENUM ('PISTA', 'AULA');

-- Estados posibles de una reserva
CREATE TYPE estado_reserva AS ENUM ('PENDIENTE', 'APROBADA', 'RECHAZADA', 'CANCELADA');

-- Tipos de movimiento de tokens
CREATE TYPE tipo_movimiento_token AS ENUM ('RECARGA_MENSUAL', 'CONSUMO_RESERVA', 'AJUSTE_ADMIN', 'DEVOLUCION');

-- Tipos de notificacion in-app
CREATE TYPE tipo_notificacion AS ENUM (
    'RESERVA_APROBADA',
    'RESERVA_RECHAZADA',
    'NUEVO_ESPACIO',
    'NUEVO_SERVICIO',
    'NUEVO_ANUNCIO',
    'NUEVA_RESERVA_PENDIENTE',
    'RESERVA_CANCELADA',
    'RECARGA_TOKENS',
    'NUEVA_ENCUESTA',
    'NUEVA_INCIDENCIA',
    'INCIDENCIA_RESUELTA'
);

CREATE TYPE canal_notificacion AS ENUM ('IN_APP', 'EMAIL', 'PUSH');

CREATE TYPE estado_entrega_notificacion AS ENUM ('ENVIADA', 'FALLIDA', 'LEIDA');

-- ============================================================
-- TABLA: USUARIOS
-- ============================================================
-- Almacena los datos de todos los usuarios registrados.
-- La autenticación se realiza mediante Microsoft EntraID.
-- El rol se determina automáticamente por el dominio del email.
CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(150) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    microsoft_id VARCHAR(255) UNIQUE,          -- ID de Microsoft EntraID
    avatar_url VARCHAR(500),                    -- URL de la imagen de perfil
    rol rol_usuario NOT NULL DEFAULT 'ALUMNO',
    rol_override BOOLEAN NOT NULL DEFAULT FALSE,
    tokens INTEGER NOT NULL DEFAULT 0,          -- Tokens disponibles (maximo acumulable 100)
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- RestricciÃ³n: el email debe ser del dominio del instituto
    CONSTRAINT chk_email_dominio CHECK (
        email LIKE '%@alumno.iesluisvives.org' OR
        email LIKE '%@profesor.iesluisvives.org' OR
        email LIKE '%@iesluisvives.org'
    ),
    CONSTRAINT chk_tokens_range CHECK (tokens >= 0 AND tokens <= 100)
);

-- Ãndices para bÃºsquedas frecuentes
CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_usuarios_rol ON usuarios(rol);
CREATE INDEX idx_usuarios_activo ON usuarios(activo);
CREATE INDEX idx_usuarios_microsoft_id ON usuarios(microsoft_id);

-- ============================================================
-- TABLA: ESPACIOS
-- ============================================================
-- Espacios del instituto que pueden ser reservados.
-- Incluye pistas deportivas y aulas.
CREATE TABLE espacios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    imagen_url VARCHAR(500),
    tipo tipo_espacio NOT NULL,
    precio_tokens INTEGER NOT NULL DEFAULT 0,   -- Coste en tokens para alumnos
    reservable BOOLEAN NOT NULL DEFAULT TRUE,
    requiere_autorizacion BOOLEAN NOT NULL DEFAULT FALSE,
    antelacion_dias INTEGER NOT NULL DEFAULT 7,  -- Días de antelación para reservar
    ubicacion VARCHAR(200),
    capacidad INTEGER,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_espacios_tipo ON espacios(tipo);
CREATE INDEX idx_espacios_activo ON espacios(activo);
CREATE INDEX idx_espacios_reservable ON espacios(reservable);

-- ============================================================
-- TABLA: ESPACIO_ROL_PERMITIDO
-- ============================================================
-- RelaciÃ³n N:M entre espacios y roles que pueden reservarlos.
CREATE TABLE espacio_rol_permitido (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    espacio_id UUID NOT NULL REFERENCES espacios(id) ON DELETE CASCADE,
    rol rol_usuario NOT NULL,

    -- Un espacio no puede tener el mismo rol repetido
    CONSTRAINT uq_espacio_rol UNIQUE (espacio_id, rol)
);

CREATE INDEX idx_espacio_rol_espacio ON espacio_rol_permitido(espacio_id);

-- ============================================================
-- TABLA: RESERVAS_ESPACIOS
-- ============================================================
-- Reservas de espacios realizadas por los usuarios.
-- Incluye control de solapamiento mediante EXCLUDE constraint.
CREATE TABLE reservas_espacios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    espacio_id UUID NOT NULL REFERENCES espacios(id) ON DELETE CASCADE,
    fecha_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
    fecha_fin TIMESTAMP WITH TIME ZONE NOT NULL,
    observaciones TEXT,
    estado estado_reserva NOT NULL DEFAULT 'PENDIENTE',
    tokens_consumidos INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- La fecha de fin debe ser posterior a la de inicio
    CONSTRAINT chk_fechas_reserva CHECK (fecha_fin > fecha_inicio),

    -- EXCLUSION CONSTRAINT: impide reservas solapadas en el mismo espacio
    -- Solo aplica a reservas que estÃ¡n PENDIENTES o APROBADAS
    CONSTRAINT excl_reserva_solapada EXCLUDE USING gist (
        espacio_id WITH =,
        tstzrange(fecha_inicio, fecha_fin) WITH &&
    ) WHERE (estado IN ('PENDIENTE', 'APROBADA'))
);

CREATE INDEX idx_reservas_usuario ON reservas_espacios(usuario_id);
CREATE INDEX idx_reservas_espacio ON reservas_espacios(espacio_id);
CREATE INDEX idx_reservas_estado ON reservas_espacios(estado);
CREATE INDEX idx_reservas_fechas ON reservas_espacios(fecha_inicio, fecha_fin);

-- ============================================================
-- TABLA: ANUNCIOS
-- ============================================================
-- TablÃ³n de anuncios gestionado por el administrador.
CREATE TABLE anuncios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    autor_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    titulo VARCHAR(200) NOT NULL,
    contenido TEXT NOT NULL,
    imagen_url VARCHAR(500),
    destacado BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_publicacion TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    fecha_expiracion TIMESTAMP WITH TIME ZONE,   -- NULL = no expira
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_anuncios_activo ON anuncios(activo);
CREATE INDEX idx_anuncios_destacado ON anuncios(destacado);
CREATE INDEX idx_anuncios_fecha_pub ON anuncios(fecha_publicacion);

-- ============================================================
-- TABLA: CATEGORIAS_CAFETERIA
-- ============================================================
-- Categorías para organizar productos de la cafetería.
CREATE TABLE categorias_cafeteria (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    imagen_url VARCHAR(500),
    orden INTEGER NOT NULL DEFAULT 0,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: PRODUCTOS_CAFETERIA
-- ============================================================
-- Productos que ofrece la cafetería del instituto (informativo).
CREATE TABLE productos_cafeteria (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    categoria_id UUID NOT NULL REFERENCES categorias_cafeteria(id) ON DELETE CASCADE,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    imagen_url VARCHAR(500),
    precio DECIMAL(6,2) NOT NULL,
    disponible BOOLEAN NOT NULL DEFAULT TRUE,
    destacado BOOLEAN NOT NULL DEFAULT FALSE,
    orden INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_productos_categoria ON productos_cafeteria(categoria_id);
CREATE INDEX idx_productos_disponible ON productos_cafeteria(disponible);

-- ============================================================
-- TABLA: SERVICIOS
-- ============================================================
-- Servicios ofrecidos por departamentos (PeluquerÃ­a, ImpresiÃ³n 3D, etc).
CREATE TABLE servicios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    imagen_url VARCHAR(500),
    ubicacion VARCHAR(200),
    horario VARCHAR(300),
    precio_tokens INTEGER NOT NULL DEFAULT 0,
    antelacion_dias INTEGER NOT NULL DEFAULT 7,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    orden INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: RESERVAS_SERVICIOS
-- ============================================================
-- Reservas de servicios especÃ­ficos.
CREATE TABLE reservas_servicios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    servicio_id UUID NOT NULL REFERENCES servicios(id) ON DELETE CASCADE,
    fecha_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
    fecha_fin TIMESTAMP WITH TIME ZONE NOT NULL,
    observaciones TEXT,
    estado estado_reserva NOT NULL DEFAULT 'PENDIENTE',
    tokens_consumidos INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_fechas_reserva_servicio CHECK (fecha_fin > fecha_inicio),

    -- Evitar solapamiento en el mismo servicio
    CONSTRAINT excl_reserva_servicio_solapada EXCLUDE USING gist (
        servicio_id WITH =,
        tstzrange(fecha_inicio, fecha_fin) WITH &&
    ) WHERE (estado IN ('PENDIENTE', 'APROBADA'))
);

CREATE INDEX idx_reservas_servicios_usuario ON reservas_servicios(usuario_id);
CREATE INDEX idx_reservas_servicios_servicio ON reservas_servicios(servicio_id);
CREATE INDEX idx_reservas_servicios_estado ON reservas_servicios(estado);

-- ============================================================
-- TABLA: HISTORIAL_TOKENS
-- ============================================================
-- Registro de todos los movimientos de tokens de los usuarios.
-- Permite auditorí­a completa de recargas y consumos.
CREATE TABLE historial_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    cantidad INTEGER NOT NULL,                   -- Positivo = recarga, negativo = consumo
    tipo tipo_movimiento_token NOT NULL,
    motivo VARCHAR(300),
    reserva_id UUID REFERENCES reservas_espacios(id) ON DELETE SET NULL,
    reserva_servicio_id UUID REFERENCES reservas_servicios(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_historial_tokens_usuario ON historial_tokens(usuario_id);
CREATE INDEX idx_historial_tokens_tipo ON historial_tokens(tipo);
CREATE INDEX idx_historial_tokens_fecha ON historial_tokens(created_at);

-- ============================================================
-- TABLA: NOTIFICACIONES
-- ============================================================
-- Notificaciones in-app por usuario.
CREATE TABLE notificaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo tipo_notificacion NOT NULL,
    titulo VARCHAR(180) NOT NULL,
    mensaje TEXT NOT NULL,
    leida BOOLEAN NOT NULL DEFAULT FALSE,
    referencia_id UUID,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notificaciones_usuario ON notificaciones(usuario_id);
CREATE INDEX idx_notificaciones_leida ON notificaciones(leida);
CREATE INDEX idx_notificaciones_fecha ON notificaciones(created_at);

-- ============================================================
-- TABLA: PREFERENCIAS_NOTIFICACION
-- ============================================================
-- Preferencias del usuario para controlar notificaciones internas y email.
CREATE TABLE preferencias_notificacion (
    usuario_id UUID PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE,
    reserva_aprobada BOOLEAN NOT NULL DEFAULT TRUE,
    reserva_rechazada BOOLEAN NOT NULL DEFAULT TRUE,
    nuevo_espacio BOOLEAN NOT NULL DEFAULT TRUE,
    nuevo_servicio BOOLEAN NOT NULL DEFAULT TRUE,
    nuevo_anuncio BOOLEAN NOT NULL DEFAULT TRUE,
    nueva_encuesta BOOLEAN NOT NULL DEFAULT TRUE,
    lista_espera BOOLEAN NOT NULL DEFAULT TRUE,
    email_reservas BOOLEAN NOT NULL DEFAULT TRUE,
    email_anuncios BOOLEAN NOT NULL DEFAULT TRUE,
    email_incidencias BOOLEAN NOT NULL DEFAULT TRUE,
    email_tokens BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: NOTIFICACION_ENTREGAS
-- ============================================================
-- Historial de entregas por canal para auditoria funcional.
CREATE TABLE notificacion_entregas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    notificacion_id UUID NOT NULL REFERENCES notificaciones(id) ON DELETE CASCADE,
    canal canal_notificacion NOT NULL,
    estado estado_entrega_notificacion NOT NULL DEFAULT 'ENVIADA',
    detalle TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notificacion_entregas_notificacion ON notificacion_entregas(notificacion_id);
CREATE INDEX idx_notificacion_entregas_canal ON notificacion_entregas(canal);
CREATE INDEX idx_notificacion_entregas_estado ON notificacion_entregas(estado);

-- ============================================================
-- TABLA: DISPOSITIVOS_PUSH
-- ============================================================
-- Tokens push por usuario (para movil/web).
CREATE TABLE dispositivos_push (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token VARCHAR(512) NOT NULL,
    plataforma VARCHAR(32) NOT NULL DEFAULT 'unknown',
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_dispositivo_push_usuario_token UNIQUE (usuario_id, token)
);

CREATE INDEX idx_dispositivos_push_usuario ON dispositivos_push(usuario_id);
CREATE INDEX idx_dispositivos_push_activo ON dispositivos_push(activo);

-- ============================================================
-- TABLA: FAVORITOS_ESPACIOS
-- ============================================================
CREATE TABLE favoritos_espacios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    espacio_id UUID NOT NULL REFERENCES espacios(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_favorito_espacio UNIQUE (usuario_id, espacio_id)
);

CREATE INDEX idx_favoritos_espacios_usuario ON favoritos_espacios(usuario_id);

-- ============================================================
-- TABLA: FAVORITOS_SERVICIOS
-- ============================================================
CREATE TABLE favoritos_servicios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    servicio_id UUID NOT NULL REFERENCES servicios(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_favorito_servicio UNIQUE (usuario_id, servicio_id)
);

CREATE INDEX idx_favoritos_servicios_usuario ON favoritos_servicios(usuario_id);

-- ============================================================
-- TABLA: INCIDENCIAS
-- ============================================================
CREATE TYPE estado_incidencia AS ENUM ('PENDIENTE', 'RESUELTA', 'DESCARTADA');

CREATE TABLE incidencias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    descripcion TEXT NOT NULL,
    imagen_url VARCHAR(500),
    estado estado_incidencia NOT NULL DEFAULT 'PENDIENTE',
    comentario_admin TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_incidencias_estado ON incidencias(estado);
CREATE INDEX idx_incidencias_usuario ON incidencias(usuario_id);

-- ============================================================
-- TABLA: CONFIGURACION
-- ============================================================
CREATE TABLE configuracion (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clave VARCHAR(100) NOT NULL UNIQUE,
    valor VARCHAR(500) NOT NULL,
    descripcion TEXT,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DATOS INICIALES DE CONFIGURACIÓN
-- ============================================================
INSERT INTO configuracion (clave, valor, descripcion) VALUES
    ('tokens_mensuales_alumno', '20', 'Cantidad de tokens que recibe cada alumno el día 1 de cada mes'),
    ('hora_inicio_reservas', '08:00', 'Hora más temprana a la que se puede hacer una reserva'),
    ('hora_fin_reservas', '21:00', 'Hora más tardía a la que puede terminar una reserva'),
    ('duracion_minima_reserva_minutos', '30', 'Duración mínima de una reserva en minutos'),
    ('duracion_maxima_reserva_minutos', '120', 'Duración máxima de una reserva en minutos'),
    ('max_reservas_activas_alumno', '3', 'Máximo de reservas activas simultáneas para alumnos'),
    ('max_reservas_activas_profesor', '5', 'Maximo de reservas activas simultaneas para profesores'),
    ('auth_dev_bypass_enabled', 'true', 'Permite login temporal sin OAuth en desarrollo');

-- ============================================================
-- FUNCIÓN: Actualizar updated_at automáticamente
-- ============================================================
CREATE OR REPLACE FUNCTION actualizar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para actualizar updated_at en las tablas principales
CREATE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_espacios_updated_at
    BEFORE UPDATE ON espacios
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_reservas_updated_at
    BEFORE UPDATE ON reservas_espacios
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_anuncios_updated_at
    BEFORE UPDATE ON anuncios
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_productos_updated_at
    BEFORE UPDATE ON productos_cafeteria
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_servicios_updated_at
    BEFORE UPDATE ON servicios
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_reservas_servicios_updated_at
    BEFORE UPDATE ON reservas_servicios
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_dispositivos_push_updated_at
    BEFORE UPDATE ON dispositivos_push
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_preferencias_notificacion_updated_at
    BEFORE UPDATE ON preferencias_notificacion
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_configuracion_updated_at
    BEFORE UPDATE ON configuracion
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_favoritos_espacios_updated_at
    BEFORE UPDATE ON favoritos_espacios
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_favoritos_servicios_updated_at
    BEFORE UPDATE ON favoritos_servicios
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

CREATE TRIGGER trg_incidencias_updated_at
    BEFORE UPDATE ON incidencias
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

-- ============================================================
-- TABLA: ENCUESTAS (Votaciones Estudiantiles)
-- ============================================================
CREATE TABLE encuestas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    titulo VARCHAR(500) NOT NULL,
    descripcion TEXT,
    fecha_fin TIMESTAMP WITH TIME ZONE NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE encuesta_opciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    encuesta_id UUID NOT NULL REFERENCES encuestas(id) ON DELETE CASCADE,
    texto VARCHAR(255) NOT NULL,
    orden INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE votos_encuesta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    encuesta_id UUID NOT NULL REFERENCES encuestas(id) ON DELETE CASCADE,
    opcion_id UUID NOT NULL REFERENCES encuesta_opciones(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_voto_usuario_encuesta UNIQUE (usuario_id, encuesta_id)
);

CREATE INDEX idx_encuestas_activa ON encuestas(activa);
CREATE INDEX idx_encuestas_fecha_fin ON encuestas(fecha_fin);
CREATE INDEX idx_votos_encuesta_usuario ON votos_encuesta(usuario_id);
CREATE INDEX idx_votos_encuesta_encuesta ON votos_encuesta(encuesta_id);

CREATE TRIGGER trg_encuestas_updated_at
    BEFORE UPDATE ON encuestas
    FOR EACH ROW EXECUTE FUNCTION actualizar_updated_at();

-- ============================================================
-- TABLA: ANUNCIO_VISUALIZACIONES (KPIs)
-- ============================================================
CREATE TABLE anuncio_visualizaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    anuncio_id UUID NOT NULL REFERENCES anuncios(id) ON DELETE CASCADE,
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_anuncio_vis_anuncio ON anuncio_visualizaciones(anuncio_id);

-- ============================================================
-- ACTUALIZACIÃ“N DE CONFIGURACIÃ“N GLOBAL
-- ============================================================
INSERT INTO configuracion (clave, valor, descripcion) VALUES
    ('dias_caducidad_anuncio_defecto', '10', 'Días tras los cuales un anuncio expira si no tiene fecha fija'),
    ('se_permiten_reservas', 'true', 'Si es false, deshabilita la creación de nuevas reservas');


-- ============================================================
-- TABLA: TRAMOS_HORARIOS
-- ============================================================
-- Catálogo de tramos horarios fijos del instituto.
-- Inmutable una vez insertado; los admins solo configuran
-- qué tramos permite cada espacio/servicio.
CREATE TABLE tramos_horarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(50) NOT NULL,
    turno VARCHAR(10) NOT NULL,          -- 'MAÃ‘ANA' | 'TARDE'
    numero INTEGER NOT NULL,             -- Orden dentro del turno (0 = RECREO)
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    es_recreo BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tramo_turno_numero UNIQUE (turno, numero)
);

CREATE INDEX idx_tramos_turno ON tramos_horarios(turno);
CREATE INDEX idx_tramos_activo ON tramos_horarios(activo);

-- ============================================================
-- TABLA: ESPACIO_TRAMOS_PERMITIDOS
-- ============================================================
-- Configura qué tramos puede usar cada espacio.
-- Sin registros → todos los tramos están permitidos.
-- Con registros → solo esos tramos disponibles.
CREATE TABLE espacio_tramos_permitidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    espacio_id UUID NOT NULL REFERENCES espacios(id) ON DELETE CASCADE,
    tramo_id UUID NOT NULL REFERENCES tramos_horarios(id) ON DELETE CASCADE,

    CONSTRAINT uq_espacio_tramo UNIQUE (espacio_id, tramo_id)
);

CREATE INDEX idx_esp_tramo_espacio ON espacio_tramos_permitidos(espacio_id);

-- ============================================================
-- TABLA: SERVICIO_TRAMOS_PERMITIDOS
-- ============================================================
CREATE TABLE servicio_tramos_permitidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    servicio_id UUID NOT NULL REFERENCES servicios(id) ON DELETE CASCADE,
    tramo_id UUID NOT NULL REFERENCES tramos_horarios(id) ON DELETE CASCADE,

    CONSTRAINT uq_servicio_tramo UNIQUE (servicio_id, tramo_id)
);

CREATE INDEX idx_srv_tramo_servicio ON servicio_tramos_permitidos(servicio_id);

-- ============================================================
-- FK: tramo_id en las tablas de reservas
-- ============================================================
-- Campo nullable para compatibilidad con reservas anteriores al sistema de tramos.
ALTER TABLE reservas_espacios
    ADD COLUMN tramo_id UUID REFERENCES tramos_horarios(id) ON DELETE SET NULL;

ALTER TABLE reservas_servicios
    ADD COLUMN tramo_id UUID REFERENCES tramos_horarios(id) ON DELETE SET NULL;

CREATE INDEX idx_reservas_tramo ON reservas_espacios(tramo_id);
CREATE INDEX idx_reservas_servicios_tramo ON reservas_servicios(tramo_id);

-- ============================================================
-- TIPOS ENUMERADOS NUEVOS (Feature: recurrentes + lista espera)
-- ============================================================

ALTER TYPE tipo_notificacion ADD VALUE IF NOT EXISTS 'RESERVA_RECURRENTE_APROBADA';
ALTER TYPE tipo_notificacion ADD VALUE IF NOT EXISTS 'RESERVA_RECURRENTE_RECHAZADA';
ALTER TYPE tipo_notificacion ADD VALUE IF NOT EXISTS 'NUEVA_RESERVA_RECURRENTE_PENDIENTE';
ALTER TYPE tipo_notificacion ADD VALUE IF NOT EXISTS 'LISTA_ESPERA_DISPONIBLE';

CREATE TYPE tipo_recurrencia AS ENUM ('SEMANAL', 'QUINCENAL', 'MENSUAL');

CREATE TYPE estado_reserva_recurrente AS ENUM (
    'PENDIENTE_APROBACION',
    'APROBADA',
    'RECHAZADA',
    'CANCELADA'
);

CREATE TYPE estado_lista_espera AS ENUM (
    'ACTIVA',
    'NOTIFICADA',
    'RESERVADA',
    'EXPIRADA',
    'CANCELADA'
);

-- ============================================================
-- TABLA: RESERVAS_RECURRENTES
-- ============================================================
-- Almacena patrones de reserva periódica pendientes de aprobación.
-- Una vez aprobadas, el scheduler genera instancias (reservas_espacios).
CREATE TABLE reservas_recurrentes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    espacio_id UUID NOT NULL REFERENCES espacios(id) ON DELETE CASCADE,
    tramo_id UUID NOT NULL REFERENCES tramos_horarios(id) ON DELETE CASCADE,
    tipo_recurrencia tipo_recurrencia NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin_recurrencia DATE NOT NULL,
    estado estado_reserva_recurrente NOT NULL DEFAULT 'PENDIENTE_APROBACION',
    observaciones TEXT,
    motivo_rechazo TEXT,
    tokens_por_instancia INTEGER NOT NULL DEFAULT 0,
    ultima_instancia_generada DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_fechas_recurrencia CHECK (fecha_fin_recurrencia > fecha_inicio)
);

CREATE INDEX idx_rec_usuario ON reservas_recurrentes(usuario_id);
CREATE INDEX idx_rec_espacio ON reservas_recurrentes(espacio_id);
CREATE INDEX idx_rec_estado ON reservas_recurrentes(estado);

-- ============================================================
-- FK: reserva_recurrente_id en reservas_espacios
-- ============================================================
ALTER TABLE reservas_espacios
    ADD COLUMN reserva_recurrente_id UUID REFERENCES reservas_recurrentes(id) ON DELETE SET NULL;

CREATE INDEX idx_reservas_recurrente ON reservas_espacios(reserva_recurrente_id);

-- ============================================================
-- TABLA: LISTA_ESPERA
-- ============================================================
CREATE TABLE lista_espera (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    espacio_id UUID NOT NULL REFERENCES espacios(id) ON DELETE CASCADE,
    tramo_id UUID NOT NULL REFERENCES tramos_horarios(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    posicion INTEGER NOT NULL,
    estado estado_lista_espera NOT NULL DEFAULT 'ACTIVA',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_lista_espera_usuario ON lista_espera(usuario_id);
CREATE INDEX idx_lista_espera_slot ON lista_espera(espacio_id, tramo_id, fecha, estado);
