-- ============================================================
-- RESERVIVES - Datos de prueba (Seed Data)
-- IES Luis Vives - TFG DAM
-- ============================================================
-- Datos de ejemplo para desarrollo y pruebas.
-- Incluye usuarios de cada rol, espacios, servicios, cafetería y anuncios.
-- ============================================================

-- ============================================================
-- USUARIOS DE PRUEBA
-- ============================================================
-- Nota: En producción los usuarios se crean mediante EntraID.
-- Las contraseñas aquí son placeholders (la auth real es via Microsoft).
INSERT INTO usuarios (id, nombre, apellidos, email, microsoft_id, rol, tokens, activo) VALUES
    -- Administrador
    ('a0000000-0000-0000-0000-000000000001', 'Admin', 'RESERVIVES', 'admin@iesluisvives.org', 'ms-admin-001', 'ADMIN', 0, TRUE),
    -- Profesores
    ('b0000000-0000-0000-0000-000000000001', 'María', 'García López', 'maria.garcia@profesor.iesluisvives.org', 'ms-prof-001', 'PROFESOR', 0, TRUE),
    ('b0000000-0000-0000-0000-000000000002', 'Carlos', 'Martínez Ruiz', 'carlos.martinez@profesor.iesluisvives.org', 'ms-prof-002', 'PROFESOR', 0, TRUE),
    ('b0000000-0000-0000-0000-000000000003', 'Ana', 'Fernández Díaz', 'ana.fernandez@profesor.iesluisvives.org', 'ms-prof-003', 'PROFESOR', 0, TRUE),
    -- Alumnos
    ('c0000000-0000-0000-0000-000000000001', 'Gonzalo', 'Sánchez Moreno', 'gonzalo.sanchez@alumno.iesluisvives.org', 'ms-alum-001', 'ALUMNO', 20, TRUE),
    ('c0000000-0000-0000-0000-000000000002', 'Laura', 'Pérez Navarro', 'laura.perez@alumno.iesluisvives.org', 'ms-alum-002', 'ALUMNO', 20, TRUE),
    ('c0000000-0000-0000-0000-000000000003', 'Pablo', 'Rodríguez Gómez', 'pablo.rodriguez@alumno.iesluisvives.org', 'ms-alum-003', 'ALUMNO', 20, TRUE),
    ('c0000000-0000-0000-0000-000000000004', 'Sofía', 'López Castro', 'sofia.lopez@alumno.iesluisvives.org', 'ms-alum-004', 'ALUMNO', 15, TRUE),
    ('c0000000-0000-0000-0000-000000000005', 'Diego', 'Torres Vega', 'diego.torres@alumno.iesluisvives.org', 'ms-alum-005', 'ALUMNO', 5, TRUE);

-- ============================================================
-- ESPACIOS: PISTAS DEPORTIVAS
-- ============================================================
INSERT INTO espacios (id, nombre, descripcion, tipo, precio_tokens, reservable, requiere_autorizacion, antelacion_dias, ubicacion, capacidad, activo) VALUES
    ('d0000000-0000-0000-0000-000000000001', 'Pista de Fútbol Sala', 'Pista cubierta de fútbol sala con césped artificial. Incluye porterías y balones.', 'PISTA', 3, TRUE, FALSE, 7, 'Pabellón Deportivo - Planta Baja', 22, TRUE),
    ('d0000000-0000-0000-0000-000000000002', 'Pista de Baloncesto', 'Cancha de baloncesto reglamentaria al aire libre con dos canastas.', 'PISTA', 3, TRUE, FALSE, 7, 'Patio Exterior - Zona Norte', 20, TRUE),
    ('d0000000-0000-0000-0000-000000000003', 'Pista de Voleibol', 'Pista de voleibol con red reglamentaria. Superficie de arena.', 'PISTA', 2, TRUE, FALSE, 7, 'Patio Exterior - Zona Sur', 12, TRUE),
    ('d0000000-0000-0000-0000-000000000004', 'Pista de Tenis de Mesa', 'Dos mesas de ping-pong profesionales en sala climatizada.', 'PISTA', 1, TRUE, FALSE, 7, 'Pabellón Deportivo - Planta 1', 4, TRUE),
    ('d0000000-0000-0000-0000-000000000005', 'Pista de Bádminton', 'Pista interior de bádminton con suelo de parquet.', 'PISTA', 2, TRUE, FALSE, 7, 'Pabellón Deportivo - Planta Baja', 4, TRUE);

-- Roles permitidos para pistas (alumnos y profesores)
INSERT INTO espacio_rol_permitido (espacio_id, rol) VALUES
    ('d0000000-0000-0000-0000-000000000001', 'ALUMNO'),
    ('d0000000-0000-0000-0000-000000000001', 'PROFESOR'),
    ('d0000000-0000-0000-0000-000000000002', 'ALUMNO'),
    ('d0000000-0000-0000-0000-000000000002', 'PROFESOR'),
    ('d0000000-0000-0000-0000-000000000003', 'ALUMNO'),
    ('d0000000-0000-0000-0000-000000000003', 'PROFESOR'),
    ('d0000000-0000-0000-0000-000000000004', 'ALUMNO'),
    ('d0000000-0000-0000-0000-000000000004', 'PROFESOR'),
    ('d0000000-0000-0000-0000-000000000005', 'ALUMNO'),
    ('d0000000-0000-0000-0000-000000000005', 'PROFESOR');

-- ============================================================
-- ESPACIOS: AULAS
-- ============================================================
INSERT INTO espacios (id, nombre, descripcion, tipo, precio_tokens, reservable, requiere_autorizacion, antelacion_dias, ubicacion, capacidad, activo) VALUES
    ('e0000000-0000-0000-0000-000000000001', 'Aula de Informática 1', 'Aula con 30 ordenadores de última generación y proyector 4K.', 'AULA', 0, TRUE, TRUE, 14, 'Edificio Principal - Planta 2', 30, TRUE),
    ('e0000000-0000-0000-0000-000000000002', 'Aula de Informática 2', 'Aula con 25 ordenadores y pizarra digital interactiva.', 'AULA', 0, TRUE, TRUE, 14, 'Edificio Principal - Planta 2', 25, TRUE),
    ('e0000000-0000-0000-0000-000000000003', 'Sala de Reuniones', 'Sala de reuniones con videoconferencia y capacidad para 12 personas.', 'AULA', 0, TRUE, TRUE, 7, 'Edificio Principal - Planta 1', 12, TRUE),
    ('e0000000-0000-0000-0000-000000000004', 'Salón de Actos', 'Salón de actos con sistema de sonido profesional y escenario.', 'AULA', 0, TRUE, TRUE, 21, 'Edificio Principal - Planta Baja', 200, TRUE),
    ('e0000000-0000-0000-0000-000000000005', 'Laboratorio de Electrónica', 'Laboratorio equipado con instrumental de medición y soldadura.', 'AULA', 0, TRUE, TRUE, 14, 'Edificio Talleres - Planta 1', 20, TRUE);

-- Roles permitidos para aulas (solo profesores)
INSERT INTO espacio_rol_permitido (espacio_id, rol) VALUES
    ('e0000000-0000-0000-0000-000000000001', 'PROFESOR'),
    ('e0000000-0000-0000-0000-000000000002', 'PROFESOR'),
    ('e0000000-0000-0000-0000-000000000003', 'PROFESOR'),
    ('e0000000-0000-0000-0000-000000000004', 'PROFESOR'),
    ('e0000000-0000-0000-0000-000000000005', 'PROFESOR');

-- ============================================================
-- ANUNCIOS
-- ============================================================
INSERT INTO anuncios (id, autor_id, titulo, contenido, destacado, activo, fecha_publicacion) VALUES
    ('f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
     '🎉 ¡Bienvenidos a RESERVIVES!',
     'Nueva aplicación para gestionar las reservas del IES Luis Vives. Ya podéis reservar pistas deportivas y consultar los servicios disponibles. ¡Esperamos que os sea de gran utilidad!',
     TRUE, TRUE, NOW()),
    ('f0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001',
     '⚽ Torneo de Fútbol Sala Inter-Ciclos',
     'Se abre la inscripción para el Torneo de Fútbol Sala entre ciclos formativos. Equipos de 5 jugadores. Inscripciones hasta el 15 de abril. Premios para los 3 primeros clasificados.',
     TRUE, TRUE, NOW()),
    ('f0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001',
     '📅 Horario especial de Semana Santa',
     'Durante la semana de Semana Santa (14-18 de abril), las instalaciones deportivas estarán cerradas. Las reservas realizadas para esas fechas serán canceladas automáticamente.',
     FALSE, TRUE, NOW()),
    ('f0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001',
     '💇 Nuevo servicio de peluquería',
     'Los alumnos del ciclo de peluquería ofrecen sus servicios de forma gratuita. Podéis pedir cita a través de la sección de Servicios de la app. ¡Aprovechad!',
     FALSE, TRUE, NOW());

-- ============================================================
-- CATEGORÍAS DE CAFETERÍA
-- ============================================================
INSERT INTO categorias_cafeteria (id, nombre, descripcion, orden, activa) VALUES
    ('10000000-0000-0000-0000-000000000001', 'Desayunos', 'Opciones para empezar el día con energía', 1, TRUE),
    ('10000000-0000-0000-0000-000000000002', 'Bocadillos y Sándwiches', 'Bocadillos fríos y calientes para el recreo', 2, TRUE),
    ('10000000-0000-0000-0000-000000000003', 'Bebidas', 'Bebidas frías y calientes', 3, TRUE),
    ('10000000-0000-0000-0000-000000000004', 'Snacks y Bollería', 'Para picar entre horas', 4, TRUE),
    ('10000000-0000-0000-0000-000000000005', 'Menú del Día', 'Menú completo para comer en el instituto', 5, TRUE);

-- ============================================================
-- PRODUCTOS DE CAFETERÍA
-- ============================================================
INSERT INTO productos_cafeteria (categoria_id, nombre, descripcion, precio, disponible, destacado, orden) VALUES
    -- Desayunos
    ('10000000-0000-0000-0000-000000000001', 'Tostada con tomate', 'Tostada de pan artesano con tomate natural rallado y AOVE', 1.80, TRUE, TRUE, 1),
    ('10000000-0000-0000-0000-000000000001', 'Tostada con mantequilla y mermelada', 'Pan tostado con mantequilla y mermelada casera', 1.50, TRUE, FALSE, 2),
    ('10000000-0000-0000-0000-000000000001', 'Croissant plancha con jamón y queso', 'Croissant a la plancha relleno de jamón york y queso gouda', 2.20, TRUE, TRUE, 3),
    -- Bocadillos
    ('10000000-0000-0000-0000-000000000002', 'Bocadillo de jamón serrano', 'Bocadillo en barra de pan con jamón serrano de calidad', 3.00, TRUE, TRUE, 1),
    ('10000000-0000-0000-0000-000000000002', 'Bocadillo de tortilla española', 'Tortilla casera de patata en pan crujiente', 2.80, TRUE, TRUE, 2),
    ('10000000-0000-0000-0000-000000000002', 'Sándwich mixto', 'Sándwich clásico de jamón york y queso a la plancha', 2.00, TRUE, FALSE, 3),
    ('10000000-0000-0000-0000-000000000002', 'Bocadillo vegetal', 'Lechuga, tomate, huevo duro, atún y mayonesa', 2.80, TRUE, FALSE, 4),
    -- Bebidas
    ('10000000-0000-0000-0000-000000000003', 'Café solo', 'Café espresso italiano', 1.10, TRUE, FALSE, 1),
    ('10000000-0000-0000-0000-000000000003', 'Café con leche', 'Café con leche entera o de avena', 1.40, TRUE, TRUE, 2),
    ('10000000-0000-0000-0000-000000000003', 'Zumo de naranja natural', 'Zumo recién exprimido de naranjas valencianas', 2.00, TRUE, TRUE, 3),
    ('10000000-0000-0000-0000-000000000003', 'Agua mineral 50cl', 'Botella de agua mineral natural', 0.80, TRUE, FALSE, 4),
    ('10000000-0000-0000-0000-000000000003', 'Refresco lata', 'Coca-Cola, Fanta, Aquarius o Nestea', 1.30, TRUE, FALSE, 5),
    -- Snacks
    ('10000000-0000-0000-0000-000000000004', 'Napolitana de chocolate', 'Napolitana artesanal rellena de chocolate', 1.20, TRUE, TRUE, 1),
    ('10000000-0000-0000-0000-000000000004', 'Palmera de chocolate', 'Palmera de hojaldre bañada en chocolate negro', 1.50, TRUE, FALSE, 2),
    ('10000000-0000-0000-0000-000000000004', 'Fruta de temporada', 'Manzana, plátano o mandarina', 0.80, TRUE, FALSE, 3),
    -- Menú del día
    ('10000000-0000-0000-0000-000000000005', 'Menú completo', 'Primer plato + segundo plato + postre + bebida', 6.50, TRUE, TRUE, 1),
    ('10000000-0000-0000-0000-000000000005', 'Medio menú', 'Un plato a elegir + bebida', 4.50, TRUE, FALSE, 2);

-- ============================================================
-- SERVICIOS DEL INSTITUTO
-- ============================================================
INSERT INTO servicios_instituto (id, nombre, descripcion, ubicacion, horario, precio_tokens, antelacion_dias, activo, orden) VALUES
    ('20000000-0000-0000-0000-000000000001', 'Peluquería',
     'Servicio de peluquería ofrecido por alumnos del ciclo de Estilismo y Dirección de Peluquería. Cortes, tintes, peinados y tratamientos capilares.',
     'Edificio Talleres - Planta Baja', 'Lunes a Viernes: 10:00 - 13:00', 0, 7, TRUE, 1),
    ('20000000-0000-0000-0000-000000000002', 'Impresión 3D',
     'Servicio de impresión 3D gestionado por el departamento de DAM/DAW. Impresión de piezas en PLA y PETG. Se debe aportar el archivo STL.',
     'Aula de Informática 3 - Planta 2', 'Martes y Jueves: 11:00 - 14:00', 2, 7, TRUE, 2),
    ('20000000-0000-0000-0000-000000000003', 'Experiencia de Realidad Virtual',
     'Sesiones de realidad virtual con distintas experiencias: juegos, visitas virtuales, simulaciones educativas. Equipos Meta Quest 3.',
     'Sala VR - Edificio Principal Planta 3', 'Miércoles: 10:00 - 14:00', 3, 7, TRUE, 3),
    ('20000000-0000-0000-0000-000000000004', 'Taller de Electrónica',
     'Reparación básica de dispositivos electrónicos (smartphones, tablets, portátiles) por alumnos del ciclo de Electrónica.',
     'Laboratorio de Electrónica - Edificio Talleres', 'Viernes: 09:00 - 13:00', 1, 7, TRUE, 4);

-- ============================================================
-- RESERVAS DE EJEMPLO
-- ============================================================
INSERT INTO reservas (usuario_id, espacio_id, fecha_inicio, fecha_fin, observaciones, estado, tokens_consumidos) VALUES
    -- Alumno reserva pista de fútbol (mañana)
    ('c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001',
     NOW() + INTERVAL '1 day' + TIME '10:00', NOW() + INTERVAL '1 day' + TIME '11:00',
     'Partido amistoso entre compañeros de DAM', 'APROBADA', 3),
    -- Profesora reserva aula de informática (pasado mañana, pendiente aprobación)
    ('b0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001',
     NOW() + INTERVAL '2 days' + TIME '09:00', NOW() + INTERVAL '2 days' + TIME '11:00',
     'Clase extra de programación web', 'PENDIENTE', 0),
    -- Alumno reserva ping-pong
    ('c0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000004',
     NOW() + INTERVAL '1 day' + TIME '12:00', NOW() + INTERVAL '1 day' + TIME '13:00',
     NULL, 'APROBADA', 1);

-- Historial de tokens para las reservas
INSERT INTO historial_tokens (usuario_id, cantidad, tipo, motivo) VALUES
    ('c0000000-0000-0000-0000-000000000001', -3, 'CONSUMO_RESERVA', 'Reserva Pista de Fútbol Sala'),
    ('c0000000-0000-0000-0000-000000000002', -1, 'CONSUMO_RESERVA', 'Reserva Pista de Tenis de Mesa');

-- Reservas de servicios de ejemplo
INSERT INTO reservas_servicios (usuario_id, servicio_id, fecha_inicio, fecha_fin, observaciones, estado, tokens_consumidos) VALUES
    ('c0000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001',
     NOW() + INTERVAL '3 days' + TIME '10:00', NOW() + INTERVAL '3 days' + TIME '10:30',
     'Corte de pelo clásico', 'APROBADA', 0),
    ('c0000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001', 
     NOW() + INTERVAL '5 days' + TIME '11:00', NOW() + INTERVAL '5 days' + TIME '11:30',
     'Sesión de VR - Juegos', 'PENDIENTE', 3);

-- ============================================================
-- FAVORITOS DE EJEMPLO
-- ============================================================
INSERT INTO favoritos_espacios (usuario_id, espacio_id) VALUES
    ('c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001'), -- Gonzalo -> Fútbol Sala
    ('c0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001'); -- Gonzalo -> Informática 1

INSERT INTO favoritos_servicios (usuario_id, servicio_id) VALUES
    ('c0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001'); -- Gonzalo -> Peluquería

-- ============================================================
-- TRAMOS HORARIOS (catálogo fijo del instituto)
-- ============================================================
INSERT INTO tramos_horarios (nombre, turno, numero, hora_inicio, hora_fin, es_recreo) VALUES
    -- TURNO MAÑANA
    ('Clase 1',  'MAÑANA', 1, '08:25', '09:20', FALSE),
    ('Clase 2',  'MAÑANA', 2, '09:20', '10:15', FALSE),
    ('Clase 3',  'MAÑANA', 3, '10:15', '11:10', FALSE),
    ('Clase 4',  'MAÑANA', 4, '11:10', '12:05', FALSE),
    ('Recreo',   'MAÑANA', 0, '12:05', '12:30', TRUE),
    ('Clase 5',  'MAÑANA', 5, '12:30', '13:25', FALSE),
    ('Clase 6',  'MAÑANA', 6, '13:25', '14:20', FALSE),
    ('Clase 7',  'MAÑANA', 7, '14:20', '15:15', FALSE),
    -- TURNO TARDE
    ('Clase 1',  'TARDE',  1, '15:15', '16:10', FALSE),
    ('Clase 2',  'TARDE',  2, '16:10', '17:05', FALSE),
    ('Clase 3',  'TARDE',  3, '17:05', '18:00', FALSE),
    ('Clase 4',  'TARDE',  4, '18:00', '18:55', FALSE),
    ('Recreo',   'TARDE',  0, '18:55', '19:20', TRUE),
    ('Clase 5',  'TARDE',  5, '19:20', '20:15', FALSE),
    ('Clase 6',  'TARDE',  6, '20:15', '21:10', FALSE)
ON CONFLICT (turno, numero) DO NOTHING;
