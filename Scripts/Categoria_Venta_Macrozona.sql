/***************************************************************************************
--****************************************************************************************
--** DSCRPCN: Porcentaje de almacenes que venden por categoría por macrozona            **
--**                                                                                    **
--** AUTOR  : Fabian Reyes                                                              **
--** FECHA  : 2022-01-28                                                                **
--***************************************************************************************/
/***************************************************************************************
--**TABLA DE ENTRADA:                                                                   **
--** almacenes_digitales.producto_almacen                                               **                                               
--** almacenes_digitales.boleta                                                         **  
--** almacenes_digitales.comuna                                                         **
--** almacenes_digitales.region                                                         **
--** almacenes_digitales.almacen                                                        **
--** almacenes_digitales.maestro_almacenes_pais                                         **    
--** almacenes_digitales.producto                                                       **                                 
--** almacenes_digitales.maestro_almacenes_pais                                         **                                 
--** almacenes_digitales.maestro_almacenes_pais                                         **                                 
--** almacenes_digitales.categoria_producto                                             **                                 
--** almacenes_digitales.detalle_compra                                                 **                             
--****************************************************************************************
--***************************************************************************************/

-- Similar al criterio para determinar el precio de productos
-- tomaremos las siguientes consideraciones:
-- 1) Almacenes con al menos 10 ventas históricas
-- 2) Almacenes con id de comuna para mapear a macrozona
-- 3) Precio compra / venta mayor a 1
-- 4) Precio Venta > a Precio de compra
-- 5) Códigos válidos de producto (9 a 13 caracteres)
-- 6) Productos vendidos por al menos 2 comercios

-- Identificando almacenes con al menos 10 ventas historicas 
WITH almacenes_aprobados AS ( 
    SELECT almacen_id
    , count(DISTINCT boleta_id) AS n_ventas
    FROM almacenes_digitales.boleta 
    WHERE almacen_id NOT IN (1,2,3)
    GROUP BY almacen_id
    HAVING n_ventas >= 10 -- condicion OK
),

-- Nos quedamos con todos los almacenes que tienen mapeado la comuna_id 
-- Se fabrica el concepto de macrozona
georeferencia_almacen AS ( -- 508 almacenes con georef
SELECT a.almacen_id 
, a.comuna_id 
, b.nombre AS nombre_comuna
, b.region_id
, c.nombre AS nombre_region
, CASE WHEN b.region_id IN (15,1,2) THEN 'MACROZONA_1'
    WHEN b.region_id IN (3,4) THEN 'MACROZONA_2'
    WHEN b.region_id IN (5) THEN 'MACROZONA_3'
    WHEN b.region_id IN (13) THEN 'MACROZONA_4'
    WHEN b.region_id IN (6,7,16,8) THEN 'MACROZONA_5'
    WHEN b.region_id IN (9,14,10,11) THEN 'MACROZONA_6'
    WHEN b.region_id IN (12) THEN 'MACROZONA_7'
    ELSE 'WTF' END AS macrozona
FROM almacenes_digitales.almacen a
LEFT JOIN almacenes_digitales.comuna b ON a.comuna_id = b.comuna_id 
LEFT JOIN almacenes_digitales.region c ON b.region_id = c.codigo 
INNER JOIN almacenes_aprobados d ON a.almacen_id = d.almacen_id
WHERE a.comuna_id IS NOT NULL 
),

-- Preparamos lo mismo que antes pero para la tabla 
-- nacional de almacenes y sumamos el total por macrozona
georeferencia_almacenes_nacionales AS (
SELECT CASE WHEN b.region_id IN (15,1,2) THEN 'MACROZONA_1'
    WHEN b.region_id IN (3,4) THEN 'MACROZONA_2'
    WHEN b.region_id IN (5) THEN 'MACROZONA_3'
    WHEN b.region_id IN (13) THEN 'MACROZONA_4'
    WHEN b.region_id IN (6,7,16,8) THEN 'MACROZONA_5'
    WHEN b.region_id IN (9,14,10,11) THEN 'MACROZONA_6'
    WHEN b.region_id IN (12) THEN 'MACROZONA_7'
    ELSE 'WTF' END AS macrozona
, sum(cantidad) AS n_almacenes
FROM almacenes_digitales.maestro_almacenes_pais a
LEFT JOIN almacenes_digitales.comuna b ON a.comuna_id = b.comuna_id 
LEFT JOIN almacenes_digitales.region c ON b.region_id = c.codigo 
GROUP BY macrozona
),

-- Obtenemos el detalle de cada boleta y cruzamos los productos con sus categorias
-- Luego filtramos los productos vendidos por los almacenes aprobados con macrozona
-- Eliminamos todos los prodcutos que no tienen categorias
prod_cat_macrozona AS (
select a.boleta_id 
, e.almacen_id 
, a.cantidad 
, a.total
, a.nombre_producto 
, b.producto_id
, c.categoria_producto_id 
, d.nombre AS categoria
, f.macrozona
FROM almacenes_digitales.detalle_compra a
LEFT JOIN almacenes_digitales.producto_almacen b ON a.codigo_producto_almacen = b.producto_almacen_id 
LEFT JOIN almacenes_digitales.producto c ON b.producto_id = c.producto_id 
LEFT JOIN almacenes_digitales.categoria_producto d ON c.categoria_producto_id = d.categoria_producto_id 
LEFT JOIN almacenes_digitales.boleta e ON a.boleta_id = e.boleta_id 
INNER JOIN georeferencia_almacen f ON e.almacen_id = f.almacen_id
WHERE d.nombre IS NOT NULL -- que tenga categoria
),

cat_macrozona_agg AS (
SELECT a.categoria
, a.macrozona
, sum(a.total) AS venta_categoria
, b.venta_total
, sum(a.total)/b.venta_total AS porc_categoria
, c.n_almacenes
FROM prod_cat_macrozona a 
LEFT JOIN (
    SELECT macrozona
    , sum(total) AS venta_total
    FROM prod_cat_macrozona
    GROUP BY macrozona) b ON a.macrozona = b.macrozona
LEFT JOIN (
    select macrozona
    , count(*) AS n_almacenes
    from georeferencia_almacen
    GROUP
    BY macrozona) c ON a.macrozona = c.macrozona
GROUP BY categoria, macrozona
)


SELECT a.categoria
, a.macrozona
, a.venta_categoria
, a.venta_total
, a.porc_categoria
, a.n_almacenes AS n_muestra_alm
, b.n_almacenes AS n_total_alm
, round(SQRT((a.porc_categoria * (1 - a.porc_categoria))/a.n_almacenes), 4) AS error_std
, round(a.porc_categoria + 1.96*SQRT((a.porc_categoria * (1 - a.porc_categoria))/a.n_almacenes), 3) AS porc_sup
, round(a.porc_categoria - 1.96*SQRT((a.porc_categoria * (1 - a.porc_categoria))/a.n_almacenes), 3) AS porc_inf
, round(b.n_almacenes*(a.porc_categoria + 1.96*SQRT((a.porc_categoria * (1 - a.porc_categoria))/a.n_almacenes)), 0) AS n_alm_sup
, round(b.n_almacenes*(a.porc_categoria - 1.96*SQRT((a.porc_categoria * (1 - a.porc_categoria))/a.n_almacenes)), 0) AS n_alm_inf
FROM cat_macrozona_agg a
LEFT JOIN georeferencia_almacenes_nacionales b ON a.macrozona = b.macrozona




