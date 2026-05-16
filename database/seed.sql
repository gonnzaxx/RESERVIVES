-- ============================================================
-- RESERVIVES - Datos de prueba (Seed Data)
-- IES Luis Vives - TFG DAM
-- ============================================================
-- Datos de ejemplo para desarrollo y pruebas.

-- ============================================================
-- ESPACIOS: PISTAS DEPORTIVAS
-- ============================================================
INSERT INTO espacios (id, nombre, descripcion, tipo, precio_tokens, reservable, requiere_autorizacion, antelacion_dias, ubicacion, capacidad, activo) VALUES
    ('d0000000-0000-0000-0000-000000000001', 'Pista de Fútbol Sala', 'Pista cubierta de fútbol sala con césped artificial. Incluye porterías y balones.', 'PISTA', 3, TRUE, FALSE, 7, 'Pabellón Deportivo - Planta Baja', 22, TRUE),
    ('d0000000-0000-0000-0000-000000000002', 'Pista de Baloncesto', 'Cancha de baloncesto reglamentaria al aire libre con dos canastas.', 'PISTA', 3, TRUE, FALSE, 7, 'Patio Exterior - Zona Norte', 20, TRUE),
    ('d0000000-0000-0000-0000-000000000003', 'Pista de Voleibol', 'Pista de voleibol con red reglamentaria. Superficie de arena.', 'PISTA', 2, TRUE, FALSE, 7, 'Patio Exterior - Zona Sur', 12, TRUE),
    ('d0000000-0000-0000-0000-000000000004', 'Pista de Tenis de Mesa', 'Dos mesas de ping-pong profesionales en sala climatizada.', 'PISTA', 1, TRUE, FALSE, 7, 'Pabellón Deportivo - Planta 1', 4, TRUE),
    ('d0000000-0000-0000-0000-000000000005', 'Pista de Bádminton', 'Pista interior de bádminton con suelo de parquet.', 'PISTA', 2, TRUE, FALSE, 7, 'Pabellón Deportivo - Planta Baja', 4, TRUE);


-- ============================================================
-- ESPACIOS: AULAS
-- ============================================================
INSERT INTO espacios (id, nombre, descripcion, tipo, precio_tokens, reservable, requiere_autorizacion, antelacion_dias, ubicacion, capacidad, activo) VALUES
    ('e0000000-0000-0000-0000-000000000001', 'Aula de Informática 1', 'Aula con 30 ordenadores de última generación y proyector 4K.', 'AULA', 0, TRUE, TRUE, 14, 'Edificio Principal - Planta 2', 30, TRUE),
    ('e0000000-0000-0000-0000-000000000002', 'Aula de Informática 2', 'Aula con 25 ordenadores y pizarra digital interactiva.', 'AULA', 0, TRUE, TRUE, 14, 'Edificio Principal - Planta 2', 25, TRUE),
    ('e0000000-0000-0000-0000-000000000003', 'Sala de Reuniones', 'Sala de reuniones con videoconferencia y capacidad para 12 personas.', 'AULA', 0, TRUE, TRUE, 7, 'Edificio Principal - Planta 1', 12, TRUE),
    ('e0000000-0000-0000-0000-000000000004', 'Salón de Actos', 'Salón de actos con sistema de sonido profesional y escenario.', 'AULA', 0, TRUE, TRUE, 21, 'Edificio Principal - Planta Baja', 200, TRUE),
    ('e0000000-0000-0000-0000-000000000005', 'Laboratorio de Electrónica', 'Laboratorio equipado con instrumental de medición y soldadura.', 'AULA', 0, TRUE, TRUE, 14, 'Edificio Talleres - Planta 1', 20, TRUE);



-- ============================================================
-- CATEGORÍAS DE CAFETERÍA
-- ============================================================
INSERT INTO categorias_cafeteria (id, nombre, descripcion, orden, activa) VALUES
    ('10000000-0000-0000-0000-000000000001', 'Entre panes', 'Bocadillos variados fríos y calientes', 1, TRUE),
    ('10000000-0000-0000-0000-000000000002', 'Menús', 'Platos del día y combinados', 2, TRUE),
    ('10000000-0000-0000-0000-000000000003', 'Bebidas', 'Cafés, infusiones y zumos', 3, TRUE);

-- ============================================================
-- PRODUCTOS DE CAFETERÍA
-- ============================================================
INSERT INTO productos_cafeteria (categoria_id, nombre, descripcion, precio, disponible, destacado, orden) VALUES
    -- Entre panes
    ('10000000-0000-0000-0000-000000000001', 'Bocadillo de Bacon', 'A la plancha', 2.00, TRUE, FALSE, 1),
    ('10000000-0000-0000-0000-000000000001', 'Bocadillo de Lomo', 'Adobado a la plancha', 2.40, TRUE, FALSE, 2),
    ('10000000-0000-0000-0000-000000000001', 'Bocadillo de tortilla de patata', 'Tortilla de patata cuajada', 2.50, TRUE, FALSE, 3),
    ('10000000-0000-0000-0000-000000000001', 'Bocadillo vegetal con pollo', 'Mayonesa, lechuga, tomate en rodajas y pollo a la plancha', 2.60, TRUE, TRUE, 4),
    ('10000000-0000-0000-0000-000000000001', 'Bocadillo de Jamón serrano', 'Tomate triturado, aceite de oliva y jamón serrano', 2.50, TRUE, TRUE, 5),
    ('10000000-0000-0000-0000-000000000001', 'Bocadillo de Luis Vives', 'Tortilla, bacon y mayonesa', 2.60, TRUE, TRUE, 6),
    ('10000000-0000-0000-0000-000000000001', 'Pollo', 'A la plancha con mayonesa', 2.60, TRUE, FALSE, 7),
    ('10000000-0000-0000-0000-000000000001', 'Vegetal bacon', 'Chistorra, salchichón, jamón york y queso', 2.60, TRUE, FALSE, 8),
    ('10000000-0000-0000-0000-000000000001', 'Bocadillo de Vegetal lomo', 'Mayonesa, lechuga, tomate y lomo adobado', 2.60, TRUE, FALSE, 9),

    -- Menús (Plato del día y Combinados)
    ('10000000-0000-0000-0000-000000000002', 'Plato del día', 'Plato varía de lunes a viernes + pieza de pan + bebida', 5.70, TRUE, TRUE, 1),
    ('10000000-0000-0000-0000-000000000002', 'Ensalada Mixta o César', 'Ensalada + Bebida + pieza de pan', 4.50, TRUE, FALSE, 2),
    ('10000000-0000-0000-0000-000000000002', 'Plato Combinado Nº1: Filete de pollo', 'Filete de pollo a la plancha, bacon, queso, picatostes y salsa', 6.50, TRUE, FALSE, 3),
    ('10000000-0000-0000-0000-000000000002', 'Plato Combinado Nº2: Lomo adobado', 'Lomo a la plancha con ensalada o patatas con huevo frito o tortilla francesa', 6.50, TRUE, FALSE, 4),
    ('10000000-0000-0000-0000-000000000002', 'Plato Combinado Nº3: Tortilla francesa', 'Tortilla francesa con ensalada y patatas + pieza de pan + bebida', 6.50, TRUE, FALSE, 5),

    -- Bebidas
    ('10000000-0000-0000-0000-000000000003', 'Café solo', 'Bebida espresso Royal', 1.00, TRUE, FALSE, 1),
    ('10000000-0000-0000-0000-000000000003', 'Café cortado', 'Espresso con un poco de leche', 1.10, TRUE, FALSE, 2),
    ('10000000-0000-0000-0000-000000000003', 'Café con leche semidesnatada', 'Café clásico con leche', 1.25, TRUE, TRUE, 3),
    ('10000000-0000-0000-0000-000000000003', 'Café con hielo', 'Espresso servido con hielo', 1.25, TRUE, FALSE, 4),
    ('10000000-0000-0000-0000-000000000003', 'ColaCao / Nesquik', 'Leche con cacao', 1.30, TRUE, FALSE, 5),
    ('10000000-0000-0000-0000-000000000003', 'Café con bebida vegetal', 'Opción sin lácteos', 1.35, TRUE, FALSE, 6),
    ('10000000-0000-0000-0000-000000000003', 'Café sin lactosa', 'Para intolerantes a la lactosa', 1.35, TRUE, FALSE, 7),
    ('10000000-0000-0000-0000-000000000003', 'Café bombón', 'Con leche condensada', 1.40, TRUE, FALSE, 8),
    ('10000000-0000-0000-0000-000000000003', 'Café moca chocolate', 'Espresso, sirope y nata', 1.80, TRUE, FALSE, 9),
    ('10000000-0000-0000-0000-000000000003', 'Café moca caramel', 'Espresso, caramelo y nata', 1.80, TRUE, FALSE, 10),
    ('10000000-0000-0000-0000-000000000003', 'Zumo de naranja', 'Zumo natural refrescante', 2.20, TRUE, FALSE, 11),
    ('10000000-0000-0000-0000-000000000003', 'Infusiones', 'Manzanilla, poleo, tila, té negro o rojo', 1.00, TRUE, FALSE, 12),
    ('10000000-0000-0000-0000-000000000003', 'Infusiones especiales', 'Consultar variedades al personal', 1.20, TRUE, FALSE, 13);
-- ============================================================
-- SERVICIOS DEL INSTITUTO
-- ============================================================
INSERT INTO servicios (id, nombre, descripcion, ubicacion, horario, precio_tokens, antelacion_dias, activo, orden) VALUES
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
-- TRAMOS HORARIOS 
-- ============================================================
INSERT INTO tramos_horarios (nombre, turno, numero, hora_inicio, hora_fin, es_recreo) VALUES
    -- TURNO MAÑANA
    ('1a hora',  'MAÑANA', 1, '08:25', '09:20', FALSE),
    ('2a hora',  'MAÑANA', 2, '09:20', '10:15', FALSE),
    ('3a hora',  'MAÑANA', 3, '10:15', '11:10', FALSE),
    ('4a hora',  'MAÑANA', 4, '11:10', '12:05', FALSE),
    ('Recreo',   'MAÑANA', 0, '12:05', '12:30', TRUE),
    ('5a hora',  'MAÑANA', 5, '12:30', '13:25', FALSE),
    ('6a hora',  'MAÑANA', 6, '13:25', '14:20', FALSE),
    ('7a hora',  'MAÑANA', 7, '14:20', '15:15', FALSE),
    -- TURNO TARDE
    ('1a hora',  'TARDE',  1, '15:15', '16:10', FALSE),
    ('2a hora',  'TARDE',  2, '16:10', '17:05', FALSE),
    ('3a hora',  'TARDE',  3, '17:05', '18:00', FALSE),
    ('4a hora',  'TARDE',  4, '18:00', '18:55', FALSE),
    ('Recreo',   'TARDE',  0, '18:55', '19:20', TRUE),
    ('5a hora',  'TARDE',  5, '19:20', '20:15', FALSE),
    ('6a hora',  'TARDE',  6, '20:15', '21:10', FALSE)
ON CONFLICT (turno, numero) DO NOTHING;




-- ============================================================
-- CONFIGURACION: SECCIONES DE BACKOFFICE POR ROL (DEFAULTS)
-- ============================================================
-- Permisos de acceso al backoffice para cada rol del sistema.
INSERT INTO configuracion (clave, valor, descripcion) VALUES
    ('backoffice_sections_ADMINISTRADOR', 'summary,users,bookings,history,polls,incidents,metrics,spaces,services,announcements,cafeteria,configuration', 'Secciones backoffice: ADMINISTRADOR'),
    ('backoffice_sections_JEFATURA',      'summary,users,bookings,history,polls,incidents,metrics,spaces,services,announcements,cafeteria', 'Secciones backoffice: JEFATURA'),
    ('backoffice_sections_SECRETARIA',    'metrics,polls,announcements,incidents', 'Secciones backoffice: SECRETARIA'),
    ('backoffice_sections_GESTOR_SERVICIO', 'history,bookings,services,metrics', 'Secciones backoffice: GESTOR_SERVICIO'),
    ('backoffice_sections_CONTROL',       'bookings,history', 'Secciones backoffice: CONTROL'),
    ('backoffice_sections_CAFETERIA',     'cafeteria', 'Secciones backoffice: CAFETERIA'),
    ('backoffice_sections_ALUMNO',        '', 'Secciones backoffice: ALUMNO'),
    ('backoffice_sections_PROFESOR',      '', 'Secciones backoffice: PROFESOR')
ON CONFLICT (clave) DO NOTHING;
