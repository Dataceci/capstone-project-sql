# Proyecto Capstone: Análisis de ventas 2025 de una tienda online

**Alumna:** Cecilia Nuñez · **Motor:** PostgreSQL

Análisis exploratorio de datos (EDA) de las ventas de 2025 de una tienda online ficticia, presentado como informe para el equipo directivo.

## 1. Problema de negocio

La dirección necesita planificar 2026 (compras de stock, calendario de campañas y programa de fidelización) y pide responder, con los datos de 2025:

1. ¿Quiénes son los clientes que más aportan y cuánto dependemos de ellos?
2. ¿En qué meses se vende más? ¿Hay estacionalidad?
3. ¿Qué productos casi no rotan y están inmovilizando capital?
4. ¿Cuáles son los pedidos más grandes de cada categoría?

## 2. Dataset

Dataset propio con 3 tablas relacionadas:

| Tabla | Filas | Contenido |
|---|---|---|
| `clientes` | 12 | Datos de registro de cada cliente |
| `productos` | 10 | Catálogo en 3 categorías, con precio de lista |
| `pedidos` | 120 | Compras de enero a diciembre de 2025 (FK a `clientes` y `productos`) |

Como pasa con los datos reales, el dataset trae **datos faltantes en columnas críticas**, que se resuelven en la etapa de limpieza.

## 3. Archivos del repositorio

| Archivo | Contenido |
|---|---|
| `estructura.sql` | Creación de tablas (PK, FK, CHECK; `DATE`/`TIMESTAMP` para fechas, `NUMERIC` para dinero) y carga de datos dentro de una transacción |
| `analisis.sql` | Diagnóstico de calidad, limpieza (vista `pedidos_limpios` con `COALESCE`) y 5 consultas de análisis comentadas |
| `README.md` | Este informe |

## 4. Cómo ejecutar el código (pgAdmin o DBeaver)

1. Conectado a la base `postgres`, crear la base de datos:
   ```sql
   CREATE DATABASE capstone_project;
   ```
2. Conectarse a la base `capstone_project`.
3. Abrir y ejecutar completo `estructura.sql`. Al final muestra un control de carga: 12 clientes, 10 productos y 120 pedidos.
4. Abrir y ejecutar `analisis.sql`. Cada consulta muestra su resultado.

Desde la terminal:

```bash
createdb capstone_project
psql -d capstone_project -f estructura.sql
psql -d capstone_project -f analisis.sql
```

Los dos scripts se pueden volver a ejecutar desde cero.

## 5. Limpieza de datos

Antes de analizar se midieron los datos faltantes en las columnas críticas, y para cada caso se decidió qué hacer:

| Columna | NULL encontrados | Decisión (`COALESCE`) | Por qué |
|---|---|---|---|
| `pedidos.fecha_pedido` | 3 de 120 | Usar `fecha_registro` (cuándo el sistema guardó el pedido) | Sin fecha, el pedido quedaría fuera del análisis mensual |
| `pedidos.precio_unitario` | 6 de 120 | Usar el `precio_lista` del producto | Sin precio, el importe sería NULL y `SUM` lo ignoraría, subestimando las ventas |
| `productos.categoria` | 1 de 10 | `'Sin categoría'` | Para que el producto siga apareciendo en los reportes por categoría |
| `clientes.ciudad` | 2 de 12 | `'No informada'` | Para reportes más claros |

También se verificó en `information_schema` que las fechas sean `DATE`/`TIMESTAMP` y el dinero `NUMERIC`.

Todo esto queda en una vista, **`pedidos_limpios`**, que usan todas las consultas. Un control posterior confirma que la vista tiene los mismos 120 pedidos (el JOIN no duplicó ni perdió filas) y cero NULL en fechas e importes.

**Criterio de ingreso:** solo cuentan los pedidos **entregados**. Hubo 10 cancelados (8,3%) que no generaron dinero y se excluyen de los totales.

## 6. Hallazgos principales

**Ventas 2025:** $6.106.000 en 110 pedidos entregados, con un ticket promedio de $55.509.

### Hallazgo 1: Tres clientes concentran el 71% de las ventas

| Cliente | Pedidos | Gasto total | % de ventas |
|---|---|---|---|
| Martín Gómez | 26 | $2.047.500 | 33,5% |
| Valentina Sosa | 25 | $1.176.500 | 19,3% |
| Lucía Fernández | 15 | $1.134.500 | 18,6% |
| Camila Herrera | 8 | $448.000 | 7,3% |
| Diego Romero | 11 | $404.000 | 6,6% |

Martín Gómez solo explica un tercio de la facturación, y el top 5 llega al 85%. Es una **dependencia alta**: si uno de los tres primeros deja de comprar, las ventas caen entre un 19% y un 34%.

**Recomendación:** programa de fidelización para los 3 clientes VIP (envío gratis, acceso anticipado a lanzamientos) y, en paralelo, campañas para hacer crecer a los clientes "Frecuentes" y bajar la dependencia.

### Hallazgo 2: Noviembre y diciembre explican un tercio del año

| Mes | Ventas | Variación |
|---|---|---|
| Ene a Oct | entre $290.000 y $548.000 por mes | — |
| Noviembre | $928.500 | +131% |
| Diciembre | $1.137.000 | +22,5% |

Los dos últimos meses suman $2.065.500, el **34% de las ventas del año**, en solo el 17% del calendario. Noviembre más que duplica a octubre, en línea con los eventos de descuentos y las compras de fin de año. El primer trimestre es el período más flojo: marzo fue el peor mes ($290.000).

**Recomendación:** reforzar el stock de los productos más vendidos desde octubre y concentrar el presupuesto de publicidad en noviembre y diciembre. Para el primer trimestre, conviene planificar promociones que sostengan la demanda.

### Hallazgo 3: Un producto no se vendió nunca y dos rotan muy poco

| Producto | Categoría | Unidades | Ingresos |
|---|---|---|---|
| Botella térmica | Sin categoría | 0 | $0 |
| Teclado mecánico | Electrónica | 4 | $248.000 |
| Set de sartenes | Hogar | 5 | $270.000 |

La **botella térmica no tuvo ninguna venta entregada** en todo el año: su único pedido fue cancelado. Además es el producto que no tiene categoría cargada. Una hipótesis a verificar es que, al no tener categoría, no aparezca en los filtros de la tienda y los clientes no la encuentren.

**Recomendación:** cargarle la categoría y medir si empieza a venderse. Si no reacciona, liquidar el stock. El teclado y el set de sartenes rotan poco pero tienen precio alto: conviene promocionarlos antes de reponerlos.

### Hallazgo 4: En cada categoría, los pedidos más grandes son compras múltiples del producto estrella

- **Indumentaria** (45% de las ventas, la categoría más fuerte): los 5 pedidos más grandes empatan en el puesto 1. Son todos 2 pares de zapatillas urbanas ($190.000).
- **Hogar** (28%): los primeros puestos son todos de la cafetera eléctrica, con 2 o 3 unidades (hasta $216.000).
- **Electrónica** (27%): el pedido más grande es de 3 teclados mecánicos ($186.000). El producto que se repite en el ranking es el de los auriculares Bluetooth.

Los tickets grandes no vienen de comprar muchos productos distintos, sino de **varias unidades del mismo producto caro**. Además, los clientes VIP (Martín Gómez, Lucía Fernández y Valentina Sosa) aparecen una y otra vez en el ranking.

**Recomendación:** probar promociones por cantidad ("2da unidad con 20% de descuento") en zapatillas y cafeteras, que son los productos donde ya se ve ese comportamiento.

### Segmentación de clientes (consulta extra con `CASE`)

| Segmento | Clientes | Gasto del segmento | Acción sugerida |
|---|---|---|---|
| VIP (≥ $500.000) | 3 | $4.358.500 | Retener |
| Frecuente (≥ $200.000) | 3 | $1.240.000 | Subir el ticket |
| Ocasional | 5 | $507.500 | Reactivar |
| Sin compras | 1 | $0 | Campaña de primera compra |

## 7. Conclusión

La tienda tiene un negocio **concentrado** en tres sentidos: pocos clientes (3 explican el 71%), pocos meses (noviembre y diciembre, el 34%) y pocos productos estrella (zapatillas y cafeteras lideran los pedidos grandes). Esto permite acciones muy enfocadas, pero también es un riesgo. Las prioridades para 2026 son fidelizar a los VIP mientras se hace crecer al resto de los clientes, preparar stock y campañas para el fin de año, y resolver los productos sin rotación, empezando por completar los datos faltantes del catálogo.

## 8. Checklist de la consigna

| Requisito | Dónde se cumple |
|---|---|
| README con contexto y hallazgos | Secciones 1, 6 y 7 |
| JOINs entre al menos 2 tablas | Vista `pedidos_limpios` (3 tablas) y consultas C y E (`LEFT JOIN`) |
| Agregación y función avanzada | `GROUP BY` + `SUM` en todas; Window Functions (`RANK`, `LAG`, `SUM OVER`) y `CASE` |
| Scripts sin errores en PostgreSQL | Probados en PostgreSQL 16, ejecutados de principio a fin |
| Etapa de limpieza previa | Etapas 1 y 2 de `analisis.sql` (diagnóstico de NULL, tipos y `COALESCE`) |
