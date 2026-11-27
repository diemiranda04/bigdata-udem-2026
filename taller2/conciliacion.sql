/*
  Taller 2 · Conciliación entre capas · equipo ing_cluade_pro

  Se corre en la cuenta del anfitrión (Diego), DESPUÉS de pipeline_taxi con
  computo = glue_small, mes = 2024-01, limite = todos.
  Athena: workgroup bigdata-wg, base bigdata_lake, región us-east-2.
  Snowflake: Snowsight con el USE de abajo.

  Tres cruces: (1) bronze -> silver, (2) silver -> gold, (3) gold -> Snowflake.
  Debajo de cada consulta: qué debe dar, el resultado y si cuadró.
*/


-- =============================================================================================
-- 1. BRONZE -> SILVER (Athena)
-- =============================================================================================

-- 1.1 Lotes de bronze del mes. Las tablas dev_bronze_* leen TODOS los lotes: si hubo pruebas con
--     limite = 1000 o reprocesos, aquí aparecen varios. Por eso el cruce 1.2 cuenta filas
--     únicas (por _hash_fila), que es lo mismo que hace silver al deduplicar.
SELECT regexp_extract("$path", 'lote=([^/]+)', 1) AS lote, count(*) AS filas
FROM bigdata_lake.dev_bronze_fhvhv
WHERE mes = '2024-01'
GROUP BY 1
ORDER BY 1;
-- Resultado: <pegar>

-- 1.2 Filas únicas de bronze clasificadas por el PRIMER filtro de silver que no pasan (mismo
--     orden y mismas reglas de limpiar_viajes en silver.py). Cada fila cae en un solo tipo, así
--     que: filas únicas de bronze = pasa + suma de descartes, y «pasa» debe ser igual a 1.3.
WITH unicas AS (
  SELECT *
  FROM (
    SELECT b.*, row_number() OVER (PARTITION BY "_hash_fila" ORDER BY "_fecha_ingesta") AS rn
    FROM bigdata_lake.dev_bronze_fhvhv b
    WHERE mes = '2024-01'
  )
  WHERE rn = 1
)
SELECT
  CASE
    WHEN pickup_datetime IS NULL THEN '1_pickup_nulo'
    WHEN pulocationid IS NULL THEN '2_zona_recogida_nula'
    WHEN pickup_datetime < TIMESTAMP '2024-01-01 00:00:00'
      OR pickup_datetime >= TIMESTAMP '2024-02-01 00:00:00' THEN '3_fuera_del_mes'
    WHEN trip_miles IS NULL OR trip_miles <= 0 THEN '4_distancia_cero_o_nula'
    WHEN trip_miles >= 100 THEN '5_distancia_100_o_mas'
    WHEN base_passenger_fare IS NULL OR base_passenger_fare <= 0 THEN '6_tarifa_cero_o_negativa'
    WHEN trip_time IS NULL OR trip_time / 60.0 < 1 OR trip_time / 60.0 > 180
      THEN '7_duracion_fuera_de_1_a_180_min'
    ELSE '0_pasa_a_silver'
  END AS resultado,
  count(*) AS filas
FROM unicas
GROUP BY 1
ORDER BY 1;
-- Debe dar: «0_pasa_a_silver» = filas de silver (1.3). La suma de todas las filas = filas
-- únicas de bronze. Los descartes se reportan por tipo en el informe.
-- Resultado: <pegar>

-- 1.3 Silver del mes: filas y huellas distintas (deben ser iguales: sin duplicados).
SELECT count(*) AS filas_silver, count(DISTINCT "_hash_fila") AS hashes_distintos
FROM bigdata_lake.dev_silver_fhvhv
WHERE mes = '2024-01';
-- Debe dar: filas_silver = hashes_distintos = «0_pasa_a_silver» de 1.2.
-- Resultado: <pegar>


-- =============================================================================================
-- 2. SILVER -> GOLD (Athena contra Snowflake)
-- =============================================================================================
-- La tabla del equipo no existe en Athena (sus tablas tienen esquema fijo): su suma de viajes
-- se lee en Snowflake (2.3) y se compara con silver (1.3).

-- 2.1 Viajes de silver que salen de JFK y LaGuardia (para la parte «aeropuerto» de 2.3).
SELECT z.zone AS zona, count(*) AS viajes
FROM bigdata_lake.dev_silver_fhvhv f
JOIN bigdata_lake.dev_silver_taxi_zones z ON z.locationid = f.pu_location_id
WHERE f.mes = '2024-01'
  AND z.zone IN ('JFK Airport', 'LaGuardia Airport')
GROUP BY z.zone
ORDER BY z.zone;
-- Resultado: <pegar>

-- 2.2 Control con el gold de la casa (misma corrida): suma de viajes = filas de silver.
SELECT
  (SELECT sum(viajes) FROM bigdata_lake.dev_gold_tarifa_por_milla_barrio WHERE mes = '2024-01')
    AS viajes_gold_casa,
  (SELECT count(*) FROM bigdata_lake.dev_silver_fhvhv WHERE mes = '2024-01') AS filas_silver;
-- Debe dar: iguales (relación 1; si da ×4 u ×8, deduplicar no está actuando).
-- Resultado: <pegar>

-- 2.3 (Snowflake) Viajes de la tabla del equipo por tipo de zona y total.
USE ROLE BIGDATA_DEV;
USE WAREHOUSE BIGDATA_WH;
USE DATABASE BIGDATA;

SELECT TIPO_ZONA, SUM(VIAJES) AS VIAJES
FROM BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA
GROUP BY TIPO_ZONA
UNION ALL
SELECT 'TOTAL', SUM(VIAJES)
FROM BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA
ORDER BY TIPO_ZONA;
-- Debe dar: TOTAL = filas_silver (1.3) y aeropuerto = JFK + LaGuardia (2.1).
-- Resultado: <pegar>


-- =============================================================================================
-- 3. GOLD -> SNOWFLAKE y tabla de control (Snowflake)
-- =============================================================================================

-- 3.1 Último registro por (TABLA, CAPA, MES). En gold, FILAS = filas de gold (grupos), no viajes.
SELECT TABLA, CAPA, MES, FILAS, LEIDAS, COMPUTO, LIMITE, INICIO
FROM BIGDATA.CONTROL_DEV.WATERMARK
QUALIFY ROW_NUMBER() OVER (PARTITION BY TABLA, CAPA, MES ORDER BY INICIO DESC) = 1
ORDER BY CAPA, TABLA, MES;
-- Debe dar: silver/fhvhv FILAS = 1.3; gold/ing_cluade_pro_aeropuertos_lluvia FILAS = 62;
-- COMPUTO = glue_small y LIMITE = todos en la corrida de la respuesta.
-- Resultado: <pegar>

-- 3.2 La tabla del equipo en Snowflake: grano (62 filas, 31 días, 31 por tipo, sin repetidos).
SELECT COUNT(*) AS FILAS,
       COUNT(DISTINCT FECHA) AS DIAS,
       COUNT_IF(TIPO_ZONA = 'aeropuerto') AS FILAS_AEROPUERTO,
       COUNT_IF(TIPO_ZONA = 'resto') AS FILAS_RESTO,
       COUNT(DISTINCT FECHA || '|' || TIPO_ZONA) AS FECHA_Y_TIPO_DISTINTOS
FROM BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA;
-- Debe dar: 62 | 31 | 31 | 31 | 62, y FILAS = FILAS de gold en 3.1.
-- Resultado: <pegar>


-- =============================================================================================
-- 4. REGLAS DE LA TABLA DEL EQUIPO (Snowflake)
-- =============================================================================================

-- 4.1 La lluvia es una sola por día (aeropuerto y resto tienen la misma).
SELECT COUNT(*) AS DIAS_CON_LLUVIA_DISTINTA
FROM (
  SELECT FECHA
  FROM BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA
  GROUP BY FECHA
  HAVING COUNT(DISTINCT COALESCE(LLUVIA_MM, -1)) > 1 OR COUNT(DISTINCT NIVEL_LLUVIA) > 1
);
-- Debe dar: 0.
-- Resultado: <pegar>

-- 4.2 El nivel sigue la regla del contrato (con_lluvia >= 1 mm, sin_lluvia < 1, sin_dato nulo).
SELECT COUNT(*) AS FILAS_CON_NIVEL_MAL
FROM BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA
WHERE NIVEL_LLUVIA <> CASE WHEN LLUVIA_MM IS NULL THEN 'sin_dato'
                           WHEN LLUVIA_MM >= 1.0 THEN 'con_lluvia'
                           ELSE 'sin_lluvia' END;
-- Debe dar: 0.
-- Resultado: <pegar>

-- 4.3 Qué días fueron con lluvia y qué día de la semana (el n de la comparación y su sesgo).
SELECT FECHA, DAYNAME(FECHA) AS DIA_SEMANA, LLUVIA_MM, NIVEL_LLUVIA
FROM BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA
WHERE TIPO_ZONA = 'resto'
ORDER BY NIVEL_LLUVIA, FECHA;
-- Debe dar: 31 días. Se reporta cuántos son con lluvia, si hay sin_dato y si los días con lluvia
-- caen más en fin de semana o festivo (1 y 15 de enero), porque eso también mueve los viajes.
-- Resultado: <pegar>


-- =============================================================================================
-- 5. DECISIONES QUE SE COMPRUEBAN CON DATOS (Athena)
-- =============================================================================================

-- 5.1 Newark y zonas fuera del catálogo: cuántos viajes son (todos van a «resto»).
SELECT COALESCE(z.zone, 'Zona fuera del catálogo') AS zona, count(*) AS viajes
FROM bigdata_lake.dev_silver_fhvhv f
LEFT JOIN bigdata_lake.dev_silver_taxi_zones z ON z.locationid = f.pu_location_id
WHERE f.mes = '2024-01'
  AND (z.zone IS NULL OR z.zone = 'Newark Airport')
GROUP BY 1;
-- Debe dar: cifras pequeñas frente al total; confirma que dejarlas en «resto» no cambia la
-- respuesta.
-- Resultado: <pegar>
