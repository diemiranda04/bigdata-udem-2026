/*
  Taller 1 - Reto R2 - DIM_FECHA con fin de semana y festivos - R2_dim_fecha.sql

  Le agregamos a DIM_FECHA el día de la semana, si es fin de semana y si es festivo, y lo usamos
  para comparar las recogidas en aeropuertos según el tipo de día. Los festivos salen de
  CURSO.LAB4.FESTIVOS_2024 (los federales de 2024; de enero a marzo hay 3, los tres lunes).

  Solo agregamos columnas: las llaves y las filas de DIM_FECHA no cambian, así que el hecho y las
  demás consultas siguen igual. Se puede correr varias veces (ADD COLUMN IF NOT EXISTS y los UPDATE
  dejan siempre lo mismo). Si se vuelve a correr 01_estrella.sql, que recrea DIM_FECHA, hay que
  correr este archivo otra vez.

  Si CURSO.LAB4.FESTIVOS_2024 no existe en la cuenta, primero se corre datos/festivos_2024.sql en
  el esquema CURSO.LAB4 (sección 3 del README).

  Cómo correrlo: Run All hasta el control (paso 3); después la consulta R2 por separado.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- 1. Columnas nuevas de DIM_FECHA
ALTER TABLE DIM_FECHA ADD COLUMN IF NOT EXISTS DIA_SEMANA VARCHAR(3);
ALTER TABLE DIM_FECHA ADD COLUMN IF NOT EXISTS ES_FIN_DE_SEMANA BOOLEAN;
ALTER TABLE DIM_FECHA ADD COLUMN IF NOT EXISTS ES_FESTIVO BOOLEAN;
ALTER TABLE DIM_FECHA ADD COLUMN IF NOT EXISTS FESTIVO VARCHAR;

-- 2. Llenarlas: primero día de la semana y fin de semana (sábado = 6, domingo = 7 en ISO);
--    después marcamos los festivos con su nombre.
UPDATE DIM_FECHA
SET DIA_SEMANA       = DAYNAME(FECHA),
    ES_FIN_DE_SEMANA = DAYOFWEEKISO(FECHA) IN (6, 7),
    ES_FESTIVO       = FALSE,
    FESTIVO          = NULL;

UPDATE DIM_FECHA D
SET ES_FESTIVO = TRUE,
    FESTIVO    = H.NOMBRE
FROM CURSO.LAB4.FESTIVOS_2024 H
WHERE H.FECHA = D.FECHA;

-- 3. Control: deben salir 91 días, 26 de fin de semana y 3 festivos (1 y 15 de enero y 19 de
--    febrero, los tres lunes).
SELECT COUNT(*) AS DIAS,
       COUNT_IF(ES_FIN_DE_SEMANA) AS FIN_DE_SEMANA,
       COUNT_IF(ES_FESTIVO) AS FESTIVOS,
       LISTAGG(IFF(ES_FESTIVO, TO_CHAR(FECHA) || ' ' || FESTIVO, NULL), ' | ') AS CUALES
FROM DIM_FECHA;

/*
  Resultado del control:
  DIAS   FIN_DE_SEMANA   FESTIVOS   CUALES
  91     26              3          2024-01-01 New Year's Day, 2024-01-15 Birthday of Martin Luther
                                    King, Jr. y 2024-02-19 Washington's Birthday
*/


-- R2. Recogidas en aeropuertos y en el resto según el tipo de día

-- Los festivos son lunes, así que los comparamos también con los lunes normales. El promedio es
-- por día (viajes / días distintos), no por fila (trampa 1: contar filas como días).
WITH DIARIO AS (
  SELECT D.FECHA,
         CASE WHEN D.ES_FESTIVO       THEN '1 Festivo'
              WHEN D.ES_FIN_DE_SEMANA THEN '4 Fin de semana'
              WHEN D.DIA_SEMANA = 'Mon' THEN '2 Lunes normal'
              ELSE '3 Martes a viernes' END AS TIPO_DIA,
         SUM(IFF(Z.SERVICE_ZONE = 'Airports', F.VIAJES, 0)) AS AEROPUERTO,
         SUM(IFF(Z.SERVICE_ZONE = 'Airports', 0, F.VIAJES)) AS RESTO
  FROM FACT_VIAJES_DIA F
  JOIN DIM_FECHA D ON D.FECHA    = F.FECHA
  JOIN DIM_ZONA  Z ON Z.ZONA_KEY = F.ZONA_KEY
  GROUP BY D.FECHA, TIPO_DIA
)
SELECT TIPO_DIA,
       COUNT(*) AS DIAS,
       ROUND(AVG(AEROPUERTO), 0) AS PROM_DIARIO_AEROPUERTO,
       ROUND(AVG(RESTO), 0) AS PROM_DIARIO_RESTO,
       ROUND(100 * SUM(AEROPUERTO) / SUM(AEROPUERTO + RESTO), 2) AS PCT_AEROPUERTO
FROM DIARIO
GROUP BY TIPO_DIA
ORDER BY TIPO_DIA;

/*
  Resultado R2:
  TIPO_DIA             DIAS   PROM_DIARIO_AEROPUERTO   PROM_DIARIO_RESTO   PCT_AEROPUERTO
  1 Festivo            3      28808                    554438              4.94
  2 Lunes normal       10     27545                    540268              4.85
  3 Martes a viernes   52     23075                    628368              3.54
  4 Fin de semana      26     21724                    707721              2.98
  Los días suman 91 (3 + 10 + 52 + 26).

  Interpretación: los festivos son los días de más recogidas en aeropuertos: 28808 por día, 4.6 %
  más que un lunes normal y 25 % más que un día de martes a viernes. En el resto de la ciudad pasa
  lo contrario: en festivo hay 554438 viajes por día, 12 % menos que de martes a viernes. Por eso
  en festivo los aeropuertos pesan casi 5 de cada 100 viajes, y el fin de semana menos de 3. Esto
  confirma lo que vimos en C4 y en R5: los aeropuertos se llenan cuando la gente vuelve de viaje
  (lunes y festivos, que aquí son los tres lunes) y bajan el fin de semana, justo cuando el resto
  de la ciudad tiene su pico.
  Lo que no dice: son solo 3 festivos, todos lunes, así que la comparación justa es con los lunes
  normales, y la diferencia (4.6 %) es pequeña para sacar una conclusión firme con n = 3. Tampoco
  separa el efecto del festivo del de las vacaciones escolares o del clima.
*/
