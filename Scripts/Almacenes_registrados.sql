/***************************************************************************************
--****************************************************************************************
--** DSCRPCN: Número de almacenes registrados por semana                                **
--**                                                                                    **
--** AUTOR  : Fabian Reyes                                                              **
--** FECHA  : 2021-10-23                                                                **
--***************************************************************************************/
/***************************************************************************************
--**TABLA DE ENTRADA: almacenes_digitales.almacen                                       **
--**                                                                                    **
--****************************************************************************************
--***************************************************************************************/

-- Se calcularan 2 métricas de clientes registrados:
-- 1. Aquellos que se registran y llenan toda la información necesaria para 
--  utilizar la plataforma ('activo = 1')
-- 2. Aquellos que se registran parcialmente o se registran y decide no hacer 
--  uso de la plataforma ('activo = 0')

WITH semana_agregada AS (
    SELECT YEARWEEK(fecha_creacion) AS semana_agg
    , CASE WHEN activo = 1 THEN 'ACTIVO' 
        ELSE 'INACTIVO' END AS tipo_registro
    , min(fecha_creacion) AS semana
    , count(DISTINCT almacen_id) AS n_almacenes
    FROM almacenes_digitales.almacen
    WHERE run_propietario NOT IN (16356198, 14119783)
    GROUP BY semana_agg, activo
    ORDER BY semana_agg, tipo_registro
)

-- Suma acumulativa aperturada por tipo de registro
SELECT semana
  , tipo_registro
  , n_almacenes
  , sum(n_almacenes) over (PARTITION BY tipo_registro ORDER BY semana) AS n_acumulado
FROM semana_agregada
ORDER BY semana;