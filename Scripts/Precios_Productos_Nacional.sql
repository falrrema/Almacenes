/***************************************************************************************
--****************************************************************************************
--** DSCRPCN: Ventas por código de producto nacional                                    **
--**                                                                                    **
--** AUTOR  : Fabian Reyes                                                              **
--** FECHA  : 2021-12-05                                                                **
--***************************************************************************************/
/***************************************************************************************
--**TABLA DE ENTRADA:                                                                   **
--** almacenes_digitales.producto_almacen                                               **                                               
--** almacenes_digitales.boleta                                                         **  
--** almacenes_digitales.comuna                                                         **
--** almacenes_digitales.region                                                         **
--** almacenes_digitales.almacen                                                        **                                 
--****************************************************************************************
--***************************************************************************************/

-- Se calcularan el precio compra / venta promedio de los productos 
-- para ello se tomaran las siguientes consideraciones:
-- 1) Almacenes con al menos 10 ventas históricas
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

-- Obteniendo todos los productos con:
-- Precios de compra venta validos
-- Largo de código correcto (9 y 13 caracteres)
productos_codigos_precios_validos AS (
    SELECT a.producto_id
    , a.almacen_id 
    , c.nombre
    , c.marca 
    , c.codigo
    , a.precio_compra_actual 
    , a.precio_venta_actual
    FROM almacenes_digitales.producto_almacen a
    INNER JOIN almacenes_aprobados b ON a.almacen_id = b.almacen_id
    LEFT JOIN almacenes_digitales.producto c ON a.producto_id = c.producto_id
    HAVING precio_compra_actual > 1 -- Remueve 48k registros
    AND precio_venta_actual - precio_compra_actual > 0 -- remueve 2.6k registros
    AND char_length(codigo) >= 9 -- Remueve 25k registros
    AND char_length(codigo) <= 13 -- 3.3k registros
),

-- Extraigo métricas de promedio y desviacion estandar
-- Se anida una query para la extracción de promedios y se saca aquellos
-- Productos que solo vende 1 almacen
productos_precios_metricas AS (
    select a.nombre
    , a.marca
    , a.codigo
    , n
    , precio_compra_prom
    -- Formula de desviacion estandar
    , SQRT(sum(pow(precio_compra_actual - precio_compra_prom, 2))/(n-1)) AS precio_compra_std 
    , precio_venta_prom
    , SQRT(sum(pow(precio_venta_actual - precio_venta_prom, 2))/(n-1)) AS precio_venta_std
    FROM productos_codigos_precios_validos a
    INNER JOIN  (
        SELECT nombre
        , marca
        , codigo
        , count(*) AS n
        , avg(precio_compra_actual) AS precio_compra_prom
        , avg(precio_venta_actual) AS precio_venta_prom
        FROM productos_codigos_precios_validos
        GROUP BY nombre, marca, codigo
        -- Criterio de al menos 2 almacenes
        HAVING n > 1) b ON a.nombre = b.nombre AND a.marca = b.marca AND a.codigo = b.codigo    
    GROUP BY nombre, marca, codigo
)

-- Se calcula metricas de margen de error
-- Se entrega para el precio de compra y venta intervalos de confianza del precio
-- Se deja también un campo referencia de porcentaje margen de error
-- Para facilitar el filtro. 
-- Recomendacion: Precios validos son aquellos con un porcentaje bajo de error (<5%)
-- Jugar con este campo o el número de productos n >= 10
-- Se eliminan productos que no tienen % de error, es decir tiene 1 solo precio lo que es raro
select nombre
    , marca
    , codigo
    , n
    , round(precio_compra_prom, 2) AS precio_compra_prom
    , round(precio_compra_std, 2) AS precio_compra_std
    , round(1.96*precio_compra_std/SQRT(n), 2) AS margen_error_compra
    , round(precio_compra_prom + 1.96*precio_compra_std/SQRT(n),2) AS precio_compra_sup 
    , round(precio_compra_prom - 1.96*precio_compra_std/SQRT(n),2) AS precio_compra_inf 
    , round(1.96*precio_compra_std/SQRT(n)/precio_compra_prom*100, 3) AS perc_error_compra
    , round(precio_venta_prom, 2) AS precio_venta_prom
    , round(precio_venta_std, 2) AS precio_venta_std
    , round(1.96*precio_venta_std/SQRT(n),2) AS margen_error_venta
    , round(precio_venta_prom + 1.96*precio_venta_std/SQRT(n), 2) AS precio_venta_sup 
    , round(precio_venta_prom - 1.96*precio_venta_std/SQRT(n), 2) AS precio_venta_inf 
    , round(1.96*precio_venta_std/SQRT(n)/precio_venta_prom*100, 3) AS perc_error_venta
    FROM productos_precios_metricas
    HAVING perc_error_venta > 0
    AND perc_error_compra > 0;

--