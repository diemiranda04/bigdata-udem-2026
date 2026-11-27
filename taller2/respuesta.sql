/*
  Taller 2 · Respuesta · equipo ing_cluade_pro

  Pregunta: en enero de 2024, ¿los viajes de Uber y Lyft que salen de JFK y LaGuardia cambian más
  con la lluvia que los que salen del resto de la ciudad?

  Sale de BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA (ya conciliada en conciliacion.sql).
  Días con lluvia = 1 mm o más. Los días sin dato de clima no entran. Los días se cuentan una vez
  (COUNT DISTINCT FECHA) y el promedio es viajes del grupo / días del grupo.
*/

USE ROLE BIGDATA_DEV;
USE WAREHOUSE BIGDATA_WH;
USE DATABASE BIGDATA;

WITH d AS (
  SELECT TIPO_ZONA, NIVEL_LLUVIA,
         COUNT(DISTINCT FECHA) AS DIAS,
         SUM(VIAJES) / COUNT(DISTINCT FECHA) AS PROM_DIA
  FROM BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA
  WHERE NIVEL_LLUVIA <> 'sin_dato'
  GROUP BY TIPO_ZONA, NIVEL_LLUVIA
)
SELECT TIPO_ZONA,
       MAX(IFF(NIVEL_LLUVIA = 'con_lluvia', DIAS, NULL)) AS DIAS_LLUVIA,
       MAX(IFF(NIVEL_LLUVIA = 'sin_lluvia', DIAS, NULL)) AS DIAS_SECOS,
       ROUND(MAX(IFF(NIVEL_LLUVIA = 'con_lluvia', PROM_DIA, NULL)), 0) AS PROM_LLUVIA,
       ROUND(MAX(IFF(NIVEL_LLUVIA = 'sin_lluvia', PROM_DIA, NULL)), 0) AS PROM_SECO,
       ROUND(100 * (PROM_LLUVIA / PROM_SECO - 1), 1) AS DIF_PCT
FROM d
GROUP BY TIPO_ZONA
ORDER BY TIPO_ZONA;

-- Lectura: la hipótesis se sostiene si DIF_PCT de «resto» es mayor que la de «aeropuerto».
-- Resultado: <pegar>
-- Cifra final: <«Con lluvia, los viajes diarios del resto cambian X % y los de los aeropuertos
-- Y %», con el n de días de cada grupo>
