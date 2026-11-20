-- =====================================================================
-- PROYECTO CAPSTONE - Análisis Exploratorio de Datos (EDA) en PostgreSQL
-- Archivo 1 de 2: estructura.sql (creación de tablas y carga de datos)
-- Alumna: Cecilia Nuñez
--
-- Dataset: tienda online ficticia, ventas del año 2025.
--   - 12 clientes, 10 productos, 120 pedidos.
--   - Incluye a propósito datos faltantes (NULL) en columnas críticas,
--     como pasa con los datos reales, para resolverlos en la etapa de
--     limpieza (ver analisis.sql).
--
-- PASO 0: crear la base de datos (ejecutar SOLO esta línea, conectado
-- a la base "postgres"), y después conectarse a capstone_project para
-- ejecutar el resto del script:
--
--   CREATE DATABASE capstone_project;
--
-- El script se puede volver a ejecutar desde cero (borra y recrea).
-- =====================================================================

DROP VIEW  IF EXISTS pedidos_limpios;
DROP TABLE IF EXISTS pedidos;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS clientes;

-- ---------------------------------------------------------------------
-- clientes: quién compra.
-- ciudad puede ser NULL porque no es obligatoria en el registro web.
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id_cliente      SERIAL        PRIMARY KEY,
    nombre          VARCHAR(50)   NOT NULL,
    apellido        VARCHAR(50)   NOT NULL,
    email           VARCHAR(100)  NOT NULL UNIQUE,
    ciudad          VARCHAR(60),
    fecha_registro  DATE          NOT NULL
);

-- ---------------------------------------------------------------------
-- productos: qué se vende.
-- NUMERIC para dinero (exacto, sin errores de redondeo de FLOAT).
-- categoria puede venir NULL si el producto se cargó incompleto.
-- ---------------------------------------------------------------------
CREATE TABLE productos (
    id_producto   SERIAL         PRIMARY KEY,
    nombre        VARCHAR(100)   NOT NULL,
    categoria     VARCHAR(50),
    precio_lista  NUMERIC(10,2)  NOT NULL CHECK (precio_lista > 0)
);

-- ---------------------------------------------------------------------
-- pedidos: cada compra (un producto por pedido).
-- fecha_pedido: fecha comercial del pedido; puede faltar por fallas de
--   la integración con la web.
-- fecha_registro: momento en que el sistema guardó el pedido; siempre
--   existe y sirve de respaldo cuando falta fecha_pedido.
-- precio_unitario: precio cobrado; puede faltar en pedidos migrados de
--   un sistema anterior (se usa el precio de lista como respaldo).
-- estado: los pedidos cancelados no son ingresos reales.
-- ---------------------------------------------------------------------
CREATE TABLE pedidos (
    id_pedido        SERIAL         PRIMARY KEY,
    id_cliente       INTEGER        NOT NULL REFERENCES clientes (id_cliente),
    id_producto      INTEGER        NOT NULL REFERENCES productos (id_producto),
    fecha_pedido     DATE,
    fecha_registro   TIMESTAMP      NOT NULL,
    cantidad         INTEGER        NOT NULL CHECK (cantidad > 0),
    precio_unitario  NUMERIC(10,2)  CHECK (precio_unitario > 0),
    estado           VARCHAR(20)    NOT NULL
                     CHECK (estado IN ('entregado', 'cancelado'))
);

-- =====================================================================
-- CARGA DE DATOS (transacción: se carga todo o nada)
-- =====================================================================
BEGIN;

INSERT INTO clientes (nombre, apellido, email, ciudad, fecha_registro) VALUES
    ('Lucía', 'Fernández', 'lucia.fernandez@mail.com', 'La Plata', '2024-11-03'),
    ('Martín', 'Gómez', 'martin.gomez@mail.com', 'Buenos Aires', '2024-12-10'),
    ('Sofía', 'Pereyra', 'sofia.pereyra@mail.com', 'Azul', '2025-01-05'),
    ('Diego', 'Romero', 'diego.romero@mail.com', 'Tandil', '2025-01-20'),
    ('Valentina', 'Sosa', 'valentina.sosa@mail.com', NULL, '2025-02-02'),
    ('Julieta', 'Ramírez', 'julieta.ramirez@mail.com', 'Olavarría', '2025-02-14'),
    ('Tomás', 'Acosta', 'tomas.acosta@mail.com', 'Bahía Blanca', '2025-03-01'),
    ('Camila', 'Herrera', 'camila.herrera@mail.com', 'Mar del Plata', '2025-03-18'),
    ('Nicolás', 'Benítez', 'nicolas.benitez@mail.com', NULL, '2025-04-07'),
    ('Florencia', 'Molina', 'florencia.molina@mail.com', 'Azul', '2025-05-11'),
    ('Agustín', 'Castro', 'agustin.castro@mail.com', 'Tandil', '2025-06-23'),
    ('Paula', 'Ortiz', 'paula.ortiz@mail.com', 'La Plata', '2025-09-30');

INSERT INTO productos (nombre, categoria, precio_lista) VALUES
    ('Auriculares Bluetooth', 'Electrónica', 45000.00),
    ('Mouse inalámbrico', 'Electrónica', 18500.00),
    ('Teclado mecánico', 'Electrónica', 62000.00),
    ('Remera de algodón', 'Indumentaria', 12000.00),
    ('Zapatillas urbanas', 'Indumentaria', 95000.00),
    ('Campera rompevientos', 'Indumentaria', 58000.00),
    ('Cafetera eléctrica', 'Hogar', 72000.00),
    ('Set de sartenes', 'Hogar', 54000.00),
    ('Lámpara de escritorio', 'Hogar', 23000.00),
    ('Botella térmica', NULL, 15500.00);

INSERT INTO pedidos (id_cliente, id_producto, fecha_pedido, fecha_registro, cantidad, precio_unitario, estado) VALUES
    (11, 1, '2025-01-01', '2025-01-01 14:20:00', 1, 45000.00, 'entregado'),
    (5, 1, '2025-01-06', '2025-01-06 18:20:00', 1, 45000.00, 'entregado'),
    (9, 6, '2025-01-08', '2025-01-08 20:50:00', 3, 58000.00, 'cancelado'),
    (5, 9, '2025-01-09', '2025-01-09 20:35:00', 3, 23000.00, 'entregado'),
    (2, 2, '2025-01-26', '2025-01-26 12:05:00', 1, 18500.00, 'cancelado'),
    (2, 5, '2025-01-28', '2025-01-28 11:05:00', 2, 95000.00, 'entregado'),
    (8, 6, '2025-02-04', '2025-02-04 09:20:00', 3, 58000.00, 'cancelado'),
    (3, 4, '2025-02-08', '2025-02-08 20:35:00', 3, 12000.00, 'entregado'),
    (8, 7, '2025-02-09', '2025-02-09 11:50:00', 1, NULL, 'entregado'),
    (4, 8, '2025-02-19', '2025-02-19 20:20:00', 1, 54000.00, 'entregado'),
    (8, 1, '2025-02-19', '2025-02-19 09:05:00', 2, 45000.00, 'entregado'),
    (5, 1, '2025-02-25', '2025-02-25 19:05:00', 1, 45000.00, 'entregado'),
    (1, 10, '2025-02-27', '2025-02-27 20:50:00', 1, 15500.00, 'cancelado'),
    (3, 4, '2025-03-01', '2025-03-01 09:20:00', 1, 12000.00, 'entregado'),
    (3, 4, '2025-03-04', '2025-03-04 19:35:00', 1, 12000.00, 'entregado'),
    (8, 9, '2025-03-08', '2025-03-08 17:05:00', 1, 23000.00, 'entregado'),
    (8, 4, NULL, '2025-03-11 12:05:00', 1, 12000.00, 'entregado'),
    (9, 4, '2025-03-18', '2025-03-18 18:20:00', 1, 12000.00, 'entregado'),
    (2, 6, '2025-03-24', '2025-03-24 11:50:00', 3, 58000.00, 'entregado'),
    (10, 1, '2025-03-25', '2025-03-25 16:20:00', 1, 45000.00, 'entregado'),
    (3, 4, '2025-04-02', '2025-04-02 17:20:00', 1, 12000.00, 'entregado'),
    (5, 2, '2025-04-05', '2025-04-05 17:20:00', 2, 18500.00, 'entregado'),
    (1, 5, '2025-04-06', '2025-04-06 15:20:00', 2, 95000.00, 'entregado'),
    (7, 2, '2025-04-12', '2025-04-12 12:50:00', 2, 18500.00, 'entregado'),
    (2, 2, '2025-04-14', '2025-04-14 14:20:00', 3, 18500.00, 'entregado'),
    (5, 2, '2025-04-17', '2025-04-17 12:05:00', 1, 18500.00, 'entregado'),
    (6, 4, '2025-04-17', '2025-04-17 21:35:00', 2, 12000.00, 'entregado'),
    (2, 4, '2025-04-20', '2025-04-20 16:20:00', 1, 12000.00, 'entregado'),
    (6, 2, '2025-05-01', '2025-05-01 19:05:00', 2, 18500.00, 'cancelado'),
    (8, 4, '2025-05-01', '2025-05-01 13:35:00', 1, 12000.00, 'entregado'),
    (7, 7, '2025-05-06', '2025-05-06 10:35:00', 1, NULL, 'entregado'),
    (6, 2, '2025-05-11', '2025-05-11 17:50:00', 1, 18500.00, 'entregado'),
    (4, 6, '2025-05-12', '2025-05-12 09:35:00', 1, 58000.00, 'entregado'),
    (5, 7, '2025-05-14', '2025-05-14 21:35:00', 2, 72000.00, 'entregado'),
    (5, 4, '2025-05-18', '2025-05-18 10:20:00', 1, 12000.00, 'entregado'),
    (2, 2, '2025-05-22', '2025-05-22 21:50:00', 1, 18500.00, 'entregado'),
    (2, 4, '2025-05-25', '2025-05-25 17:35:00', 2, 12000.00, 'cancelado'),
    (2, 7, '2025-05-27', '2025-05-27 11:20:00', 2, 72000.00, 'entregado'),
    (5, 4, '2025-05-27', '2025-05-27 16:05:00', 2, 12000.00, 'entregado'),
    (5, 8, '2025-06-01', '2025-06-01 14:20:00', 1, 54000.00, 'entregado'),
    (1, 4, '2025-06-02', '2025-06-02 16:20:00', 2, 12000.00, 'entregado'),
    (5, 4, '2025-06-10', '2025-06-10 14:35:00', 1, 12000.00, 'entregado'),
    (11, 5, '2025-06-12', '2025-06-12 13:05:00', 1, 95000.00, 'cancelado'),
    (2, 4, '2025-06-15', '2025-06-15 12:35:00', 1, NULL, 'entregado'),
    (2, 2, '2025-06-18', '2025-06-18 11:20:00', 1, 18500.00, 'entregado'),
    (2, 7, '2025-06-23', '2025-06-23 10:20:00', 3, 72000.00, 'entregado'),
    (2, 4, '2025-07-02', '2025-07-02 15:35:00', 2, 12000.00, 'entregado'),
    (9, 2, '2025-07-02', '2025-07-02 21:05:00', 1, 18500.00, 'entregado'),
    (3, 2, '2025-07-04', '2025-07-04 14:05:00', 1, 18500.00, 'entregado'),
    (1, 4, '2025-07-08', '2025-07-08 15:20:00', 1, 12000.00, 'entregado'),
    (5, 4, '2025-07-11', '2025-07-11 18:20:00', 1, 12000.00, 'entregado'),
    (1, 5, '2025-07-12', '2025-07-12 16:35:00', 1, 95000.00, 'cancelado'),
    (1, 5, '2025-07-19', '2025-07-19 11:35:00', 1, 95000.00, 'entregado'),
    (2, 5, '2025-07-20', '2025-07-20 11:05:00', 1, 95000.00, 'entregado'),
    (1, 5, '2025-07-23', '2025-07-23 14:05:00', 2, 95000.00, 'entregado'),
    (4, 9, '2025-07-24', '2025-07-24 19:05:00', 2, 23000.00, 'entregado'),
    (8, 2, '2025-07-26', '2025-07-26 20:05:00', 2, 18500.00, 'entregado'),
    (1, 9, NULL, '2025-08-01 12:20:00', 1, 23000.00, 'entregado'),
    (10, 1, '2025-08-04', '2025-08-04 13:05:00', 1, 45000.00, 'entregado'),
    (8, 5, '2025-08-05', '2025-08-05 15:20:00', 2, 95000.00, 'entregado'),
    (4, 4, '2025-08-06', '2025-08-06 09:50:00', 1, 12000.00, 'entregado'),
    (4, 4, '2025-08-14', '2025-08-14 09:20:00', 1, 12000.00, 'entregado'),
    (5, 5, '2025-08-14', '2025-08-14 12:35:00', 1, 95000.00, 'entregado'),
    (2, 1, '2025-08-16', '2025-08-16 18:05:00', 1, 45000.00, 'entregado'),
    (5, 4, '2025-08-16', '2025-08-16 19:35:00', 1, 12000.00, 'entregado'),
    (2, 2, '2025-08-21', '2025-08-21 19:05:00', 2, 18500.00, 'entregado'),
    (5, 4, '2025-08-22', '2025-08-22 21:05:00', 2, 12000.00, 'entregado'),
    (8, 4, '2025-08-26', '2025-08-26 13:50:00', 1, 12000.00, 'entregado'),
    (5, 4, '2025-08-28', '2025-08-28 16:35:00', 1, 12000.00, 'entregado'),
    (2, 7, '2025-09-09', '2025-09-09 12:05:00', 2, 72000.00, 'entregado'),
    (2, 2, '2025-09-10', '2025-09-10 18:35:00', 1, 18500.00, 'entregado'),
    (1, 5, '2025-09-11', '2025-09-11 15:20:00', 2, 95000.00, 'entregado'),
    (5, 6, '2025-09-19', '2025-09-19 09:05:00', 1, 58000.00, 'entregado'),
    (2, 7, '2025-09-28', '2025-09-28 20:05:00', 2, 72000.00, 'cancelado'),
    (9, 2, '2025-10-04', '2025-10-04 14:20:00', 1, 18500.00, 'entregado'),
    (10, 8, '2025-10-05', '2025-10-05 10:20:00', 1, 54000.00, 'entregado'),
    (5, 4, '2025-10-12', '2025-10-12 09:50:00', 1, NULL, 'entregado'),
    (2, 7, '2025-10-14', '2025-10-14 17:35:00', 1, 72000.00, 'entregado'),
    (2, 1, '2025-10-16', '2025-10-16 14:50:00', 1, 45000.00, 'entregado'),
    (1, 1, '2025-10-17', '2025-10-17 21:50:00', 2, 45000.00, 'entregado'),
    (3, 4, '2025-10-18', '2025-10-18 18:50:00', 2, 12000.00, 'entregado'),
    (2, 2, '2025-10-21', '2025-10-21 14:50:00', 1, 18500.00, 'entregado'),
    (1, 2, '2025-10-24', '2025-10-24 18:35:00', 1, 18500.00, 'entregado'),
    (4, 4, '2025-10-28', '2025-10-28 18:50:00', 1, 12000.00, 'entregado'),
    (5, 2, '2025-10-28', '2025-10-28 18:05:00', 2, 18500.00, 'entregado'),
    (2, 6, '2025-11-03', '2025-11-03 10:20:00', 3, 58000.00, 'entregado'),
    (2, 7, '2025-11-05', '2025-11-05 11:35:00', 1, 72000.00, 'entregado'),
    (9, 4, '2025-11-05', '2025-11-05 20:20:00', 1, 12000.00, 'entregado'),
    (8, 1, '2025-11-06', '2025-11-06 13:35:00', 2, 45000.00, 'cancelado'),
    (4, 1, '2025-11-08', '2025-11-08 10:05:00', 1, 45000.00, 'entregado'),
    (2, 9, '2025-11-10', '2025-11-10 21:05:00', 2, 23000.00, 'entregado'),
    (4, 2, '2025-11-10', '2025-11-10 18:05:00', 1, 18500.00, 'entregado'),
    (5, 1, NULL, '2025-11-11 13:05:00', 1, 45000.00, 'entregado'),
    (6, 6, '2025-11-11', '2025-11-11 21:35:00', 1, 58000.00, 'entregado'),
    (5, 2, '2025-11-13', '2025-11-13 18:20:00', 1, 18500.00, 'entregado'),
    (6, 4, '2025-11-13', '2025-11-13 21:35:00', 2, 12000.00, 'entregado'),
    (1, 4, '2025-11-15', '2025-11-15 20:50:00', 2, 12000.00, 'entregado'),
    (1, 2, '2025-11-18', '2025-11-18 21:35:00', 2, 18500.00, 'entregado'),
    (3, 8, '2025-11-21', '2025-11-21 14:05:00', 2, 54000.00, 'entregado'),
    (2, 4, '2025-11-22', '2025-11-22 09:50:00', 1, 12000.00, 'entregado'),
    (3, 2, '2025-11-22', '2025-11-22 12:50:00', 1, NULL, 'entregado'),
    (5, 7, '2025-11-26', '2025-11-26 10:35:00', 3, 72000.00, 'entregado'),
    (4, 4, '2025-12-01', '2025-12-01 17:20:00', 1, 12000.00, 'entregado'),
    (5, 2, '2025-12-02', '2025-12-02 20:50:00', 1, 18500.00, 'entregado'),
    (9, 4, '2025-12-02', '2025-12-02 18:35:00', 2, 12000.00, 'entregado'),
    (1, 4, '2025-12-03', '2025-12-03 18:05:00', 1, 12000.00, 'entregado'),
    (3, 1, '2025-12-05', '2025-12-05 20:35:00', 3, 45000.00, 'entregado'),
    (4, 2, '2025-12-05', '2025-12-05 12:35:00', 1, 18500.00, 'entregado'),
    (5, 2, '2025-12-08', '2025-12-08 13:05:00', 2, 18500.00, 'entregado'),
    (2, 4, '2025-12-09', '2025-12-09 21:05:00', 1, 12000.00, 'entregado'),
    (3, 4, '2025-12-09', '2025-12-09 16:05:00', 1, 12000.00, 'entregado'),
    (1, 5, '2025-12-12', '2025-12-12 20:20:00', 1, NULL, 'entregado'),
    (1, 7, '2025-12-14', '2025-12-14 11:35:00', 1, 72000.00, 'entregado'),
    (2, 3, '2025-12-14', '2025-12-14 15:20:00', 3, 62000.00, 'entregado'),
    (4, 6, '2025-12-15', '2025-12-15 21:50:00', 2, 58000.00, 'entregado'),
    (5, 4, '2025-12-16', '2025-12-16 13:05:00', 2, 12000.00, 'entregado'),
    (5, 5, '2025-12-18', '2025-12-18 09:50:00', 1, 95000.00, 'entregado'),
    (1, 3, '2025-12-19', '2025-12-19 19:20:00', 1, 62000.00, 'entregado'),
    (2, 6, '2025-12-22', '2025-12-22 13:35:00', 2, 58000.00, 'entregado'),
    (2, 1, '2025-12-24', '2025-12-24 18:35:00', 2, 45000.00, 'entregado');

COMMIT;

-- Control de carga: deben dar 12, 10 y 120.
SELECT
    (SELECT COUNT(*) FROM clientes)  AS clientes,
    (SELECT COUNT(*) FROM productos) AS productos,
    (SELECT COUNT(*) FROM pedidos)   AS pedidos;
