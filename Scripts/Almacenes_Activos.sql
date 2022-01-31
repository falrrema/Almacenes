/***************************************************************************************
--****************************************************************************************
--** DSCRPCN: Número de almacenes registrados por semana                                **
--**                                                                                    **
--** AUTOR  : Fabian Reyes                                                              **
--** FECHA  : 2021-10-25                                                                **
--***************************************************************************************/
/***************************************************************************************
--**TABLA DE ENTRADA: almacenes_digitales.producto_almacen                               **
--**                   almacenes_digitales.boleta                                        **
--****************************************************************************************
--***************************************************************************************/

-- Se calcularan los clientes activos estos cumplen los siguientes criterios:
-- 1) Tener mas de 20 productos
-- 2) Tener mas de 5 ventas la última semana

-- Filtrando todos los almacenes con al menos 20 productos
-- registrados en la plataformas
WITH almacenes_20_prod AS (
    select almacen_id
    , count(DISTINCT producto_id) AS n_prod
    from almacenes_digitales.producto_almacen
    WHERE almacen_id NOT IN (1,2,3)
    GROUP BY almacen_id
    HAVING n_prod >= 20
),

-- Filtrando todos los almacenes anteriores que tengan 
-- al menos 5 ventas por semana
almacenes_semana_activos AS (
    SELECT a.almacen_id
    , YEARWEEK(fecha) AS semana_agg
    , min(CAST(fecha AS date)) AS semana
    , count(DISTINCT boleta_id) AS n_ventas
    FROM almacenes_digitales.boleta a 
    INNER JOIN almacenes_20_prod b ON a.almacen_id = b.almacen_id -- filtro
    GROUP BY almacen_id, semana_agg
    HAVING n_ventas >= 5 -- condicion de actividad
)

-- Calculo los almacenes activos por semana 
SELECT semana_agg
, min(semana) AS semana
, count(DISTINCT almacen_id) AS n_almacenes_activos
FROM almacenes_semana_activos
GROUP BY semana_agg
ORDER BY semana_agg; 


