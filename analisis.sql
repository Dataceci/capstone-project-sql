-- =====================================================================
-- PROYECTO CAPSTONE - Análisis Exploratorio de Datos (EDA) en PostgreSQL
-- Archivo 2 de 2: analisis.sql (limpieza + consultas de análisis)
-- Alumna: Cecilia Nuñez
--
-- Requisito: haber ejecutado estructura.sql en la base capstone_project.
--
-- Problema de negocio: la dirección quiere planificar 2026 (stock,
-- campañas y fidelización) y necesita saber, con los datos de 2025:
--   ¿quiénes son los clientes que más aportan?, ¿en qué meses se vende
--   más?, ¿qué productos casi no rotan? y ¿qué pedidos son los más
--   importantes dentro de cada categoría?
--
-- Criterio general: solo los pedidos ENTREGADOS cuentan como ingreso.
-- Los cancelados no generaron dinero y, si se sumaran, inflarían las
-- ventas y llevarían a comprar stock de más.
-- =====================================================================


-- =====================================================================
-- ETAPA 1: DIAGNÓSTICO DE CALIDAD DE DATOS
-- Antes de analizar, medimos cuántos datos faltan en las columnas
-- críticas. Si analizáramos sin mirar esto, los NULL harían que sumas
-- y agrupaciones por fecha den resultados incompletos sin avisar.
-- =====================================================================

-- 1.a ¿Cuántos NULL hay en cada columna crítica?
SELECT
    COUNT(*)                                   AS total_pedidos,
    COUNT(*) - COUNT(p.fecha_pedido)           AS pedidos_sin_fecha,
    COUNT(*) - COUNT(p.precio_unitario)        AS pedidos_sin_precio
FROM pedidos p;

SELECT
    COUNT(*) - COUNT(pr.categoria)             AS productos_sin_categoria
FROM productos pr;

SELECT
    COUNT(*) - COUNT(c.ciudad)                 AS clientes_sin_ciudad
FROM clientes c;

-- 1.b Verificar que los tipos de datos sean los correctos: las fechas
-- tienen que ser DATE/TIMESTAMP (para poder agrupar por mes) y el dinero
-- NUMERIC (para que las sumas sean exactas).
SELECT
    col.table_name,
    col.column_name,
    col.data_type
FROM information_schema.columns col
WHERE col.table_schema = 'public'
  AND col.column_name IN ('fecha_pedido', 'fecha_registro',
                          'precio_unitario', 'precio_lista', 'cantidad')
ORDER BY col.table_name, col.column_name;


-- =====================================================================
-- ETAPA 2: LIMPIEZA Y TRANSFORMACIÓN
-- Creamos una vista "pedidos_limpios" que resuelve los NULL una sola vez,
-- así todas las consultas de análisis usan los mismos datos corregidos
-- y no hay que repetir la limpieza en cada una.
--
-- Decisiones sobre los datos faltantes:
--   fecha_pedido NULL    -> se usa la fecha en que el sistema registró
--                           el pedido (fecha_registro). Es la mejor
--                           aproximación disponible y evita perder esos
--                           pedidos del análisis mensual.
--   precio_unitario NULL -> se usa el precio de lista del producto. Sin
--                           esto, el importe de esos pedidos sería NULL y
--                           la SUM los ignoraría, subestimando ventas.
--   categoria NULL       -> 'Sin categoría', para que el producto siga
--                           apareciendo en los reportes por categoría y
--                           el equipo de catálogo lo pueda corregir.
--   ciudad NULL          -> 'No informada'.
-- =====================================================================
DROP VIEW IF EXISTS pedidos_limpios;

CREATE VIEW pedidos_limpios AS
SELECT
    p.id_pedido,
    p.id_cliente,
    c.nombre || ' ' || c.apellido                          AS cliente,
    COALESCE(c.ciudad, 'No informada')                     AS ciudad,
    p.id_producto,
    pr.nombre                                              AS producto,
    COALESCE(pr.categoria, 'Sin categoría')                AS categoria,
    COALESCE(p.fecha_pedido, p.fecha_registro::DATE)       AS fecha_pedido,
    p.cantidad,
    COALESCE(p.precio_unitario, pr.precio_lista)           AS precio_unitario,
    p.cantidad * COALESCE(p.precio_unitario, pr.precio_lista) AS importe,
    p.estado
FROM pedidos p
INNER JOIN clientes  c  ON c.id_cliente   = p.id_cliente
INNER JOIN productos pr ON pr.id_producto = p.id_producto;

-- Control de la limpieza: la vista debe tener los mismos 120 pedidos
-- (el JOIN no duplicó ni perdió filas) y ningún NULL en columnas críticas.
SELECT
    COUNT(*)                                   AS pedidos_en_vista,
    COUNT(*) - COUNT(pl.fecha_pedido)          AS fechas_nulas,
    COUNT(*) - COUNT(pl.importe)               AS importes_nulos
FROM pedidos_limpios pl;


-- =====================================================================
-- ETAPA 3: ANÁLISIS
-- =====================================================================

-- ---------------------------------------------------------------------
-- CONSULTA A: TOP 5 CLIENTES POR GASTO TOTAL
-- Por qué: concentrar el programa de fidelización (descuentos, envío
-- gratis) en los clientes que más ingresos generan, y medir qué parte
-- de las ventas totales depende de ellos (riesgo si alguno se va).
-- El porcentaje se calcula con una Window Function: SUM(...) OVER ()
-- da el total general sin perder el detalle de cada cliente.
-- ---------------------------------------------------------------------
SELECT
    pl.cliente,
    pl.ciudad,
    COUNT(pl.id_pedido)                                     AS pedidos,
    SUM(pl.importe)                                         AS gasto_total,
    ROUND(100.0 * SUM(pl.importe) / SUM(SUM(pl.importe)) OVER (), 1)
                                                            AS pct_de_ventas
FROM pedidos_limpios pl
WHERE pl.estado = 'entregado'
GROUP BY pl.id_cliente, pl.cliente, pl.ciudad
ORDER BY gasto_total DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- CONSULTA B: VENTAS TOTALES POR MES
-- Por qué: detectar la estacionalidad para planificar compras de stock
-- y el calendario de campañas. Se agrupa con DATE_TRUNC('month', ...)
-- para llevar todas las fechas de un mes al mismo nivel.
-- LAG() trae la venta del mes anterior para calcular la variación y
-- ver en qué meses se acelera o cae la demanda.
-- ---------------------------------------------------------------------
WITH ventas_mes AS (
    SELECT
        DATE_TRUNC('month', pl.fecha_pedido)::DATE          AS mes,
        COUNT(pl.id_pedido)                                 AS pedidos,
        SUM(pl.importe)                                     AS ventas
    FROM pedidos_limpios pl
    WHERE pl.estado = 'entregado'
    GROUP BY DATE_TRUNC('month', pl.fecha_pedido)::DATE
)
SELECT
    TO_CHAR(vm.mes, 'YYYY-MM')                              AS mes,
    vm.pedidos,
    vm.ventas,
    ROUND(100.0 * (vm.ventas - LAG(vm.ventas) OVER (ORDER BY vm.mes))
                / LAG(vm.ventas) OVER (ORDER BY vm.mes), 1) AS variacion_pct
FROM ventas_mes vm
ORDER BY vm.mes;


-- ---------------------------------------------------------------------
-- CONSULTA C: LOS 3 PRODUCTOS MENOS VENDIDOS
-- Por qué: identificar productos que inmovilizan capital en el depósito,
-- para decidir si se liquidan, se promocionan o se dejan de comprar.
-- Se parte de productos con LEFT JOIN para que también aparezca un
-- producto que no se haya vendido nunca; en ese caso las sumas vienen
-- NULL y COALESCE las convierte en 0.
-- La condición de estado va en el ON (no en el WHERE) para no
-- convertir el LEFT JOIN en un INNER JOIN sin querer.
-- ---------------------------------------------------------------------
SELECT
    pr.nombre                                               AS producto,
    COALESCE(pr.categoria, 'Sin categoría')                 AS categoria,
    COALESCE(SUM(pl.cantidad), 0)                           AS unidades_vendidas,
    COALESCE(SUM(pl.importe), 0)                            AS ingresos
FROM productos pr
LEFT JOIN pedidos_limpios pl ON pl.id_producto = pr.id_producto
                            AND pl.estado      = 'entregado'
GROUP BY pr.id_producto, pr.nombre, pr.categoria
ORDER BY unidades_vendidas ASC, ingresos ASC
LIMIT 3;


-- ---------------------------------------------------------------------
-- CONSULTA D: RANKING DE PEDIDOS POR CATEGORÍA (RANK)
-- Por qué: dentro de cada categoría, identificar los pedidos de mayor
-- importe (los "tickets grandes") para estudiar qué combinaciones de
-- producto y cantidad generan más ingreso y replicarlas en campañas.
-- RANK() con PARTITION BY categoria reinicia el ranking en cada
-- categoría; si dos pedidos empatan en importe, comparten el puesto.
-- Se muestran los 3 primeros puestos de cada categoría.
-- ---------------------------------------------------------------------
WITH ranking_pedidos AS (
    SELECT
        pl.categoria,
        pl.id_pedido,
        pl.cliente,
        pl.producto,
        pl.cantidad,
        pl.importe,
        RANK() OVER (
            PARTITION BY pl.categoria
            ORDER BY pl.importe DESC
        )                                                   AS puesto
    FROM pedidos_limpios pl
    WHERE pl.estado = 'entregado'
)
SELECT
    rp.categoria,
    rp.puesto,
    rp.id_pedido,
    rp.cliente,
    rp.producto,
    rp.cantidad,
    rp.importe
FROM ranking_pedidos rp
WHERE rp.puesto <= 3
ORDER BY rp.categoria, rp.puesto, rp.id_pedido;


-- ---------------------------------------------------------------------
-- CONSULTA E (extra): SEGMENTACIÓN DE CLIENTES CON CASE
-- Por qué: no todos los clientes necesitan la misma acción comercial.
-- Clasificamos a cada cliente según su gasto anual para asignar una
-- estrategia: VIP (retener), Frecuente (subir el ticket), Ocasional
-- (reactivar) y Sin compras (primera compra).
-- Umbrales: VIP desde $500.000, que es aproximadamente el gasto promedio
-- anual por cliente ($508.833): los VIP son los que superan la media.
-- Frecuente desde $200.000, el equivalente a unas 4 compras del ticket
-- promedio ($55.509).
-- ---------------------------------------------------------------------
WITH gasto_cliente AS (
    SELECT
        c.id_cliente,
        c.nombre || ' ' || c.apellido                       AS cliente,
        COALESCE(SUM(pl.importe), 0)                        AS gasto_total
    FROM clientes c
    LEFT JOIN pedidos_limpios pl ON pl.id_cliente = c.id_cliente
                                AND pl.estado     = 'entregado'
    GROUP BY c.id_cliente, c.nombre, c.apellido
)
SELECT
    CASE
        WHEN gc.gasto_total >= 500000 THEN 'VIP'
        WHEN gc.gasto_total >= 200000 THEN 'Frecuente'
        WHEN gc.gasto_total > 0       THEN 'Ocasional'
        ELSE 'Sin compras'
    END                                                     AS segmento,
    COUNT(*)                                                AS clientes,
    SUM(gc.gasto_total)                                     AS gasto_del_segmento,
    STRING_AGG(gc.cliente, ', ' ORDER BY gc.gasto_total DESC) AS integrantes
FROM gasto_cliente gc
GROUP BY 1
ORDER BY gasto_del_segmento DESC;
