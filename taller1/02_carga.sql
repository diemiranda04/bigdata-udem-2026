-- =====================================================================
-- TALLER 1 · 02_carga.sql · Carga reproducible desde el Lab 4
-- =====================================================================
-- Requisito: haber corrido 01_estrella.sql y tener en CURSO.LAB4 las tablas DAILY_ZONE_METRICS
-- (46715 filas) y DIM_ZONA (265 filas).
-- INSERT OVERWRITE borra y vuelve a llenar cada tabla: el archivo se puede correr muchas veces
-- y deja siempre el mismo resultado (carga idempotente).
-- Orden: primero las dimensiones (crean las llaves) y después el hecho (las usa).
-- CÓMO CORRERLO: pega todo en una hoja y pulsa Run All.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- 1 · DIM_EMPRESA: empresas distintas del gold, numeradas en orden alfabético (Lyft = 1, Uber = 2).
INSERT OVERWRITE INTO DIM_EMPRESA (EMPRESA_KEY, EMPRESA)
SELECT ROW_NUMBER() OVER (ORDER BY EMPRESA) AS EMPRESA_KEY, EMPRESA
FROM (SELECT DISTINCT EMPRESA FROM CURSO.LAB4.DAILY_ZONE_METRICS);

-- 2 · DIM_ZONA: una fila por nombre de zona (trampa 4).
--     Corona (LocationID 56 y 57) y Governor's Island/Ellis Island/Liberty Island (103 a 105) se
--     repiten en el catálogo; los repetidos comparten distrito y tipo de zona, así que MIN no pierde
--     información. Resultado: 262 zonas (de 265 filas del catálogo).
INSERT OVERWRITE INTO DIM_ZONA (ZONA_KEY, ZONA, BOROUGH, SERVICE_ZONE, LOCATION_ID)
SELECT ROW_NUMBER() OVER (ORDER BY ZONA) AS ZONA_KEY, ZONA, BOROUGH, SERVICE_ZONE, LOCATION_ID
FROM (
  SELECT ZONA,
         MIN(BOROUGH)      AS BOROUGH,
         MIN(SERVICE_ZONE) AS SERVICE_ZONE,
         MIN(LOCATION_ID)  AS LOCATION_ID
  FROM CURSO.LAB4.DIM_ZONA
  GROUP BY ZONA
);

-- 3 · DIM_FECHA: una fila por fecha distinta del gold. Se comprueba que son 91 días
--     (calendario completo del 2024-01-01 al 2024-03-31).
INSERT OVERWRITE INTO DIM_FECHA (FECHA, ANIO, MES_NUM, MES)
SELECT FECHA, YEAR(FECHA), MONTH(FECHA), TO_CHAR(FECHA, 'YYYY-MM')
FROM (SELECT DISTINCT FECHA FROM CURSO.LAB4.DAILY_ZONE_METRICS);

-- 4 · FACT_VIAJES_DIA: una fila por fila del gold, con las llaves de las dimensiones.
--     LEFT JOIN para no perder filas (las huérfanas se detectan en 04_chequeos.sql).
--     Los promedios se guardan como totales (promedio x viajes) para ponderar después.
INSERT OVERWRITE INTO FACT_VIAJES_DIA
  (FECHA, ZONA_KEY, EMPRESA_KEY, VIAJES, INGRESO_TOTAL, PROPINA_TOTAL, DISTANCIA_TOTAL)
SELECT G.FECHA,
       Z.ZONA_KEY,
       E.EMPRESA_KEY,
       G.VIAJES,
       G.INGRESO_TOTAL,
       G.PROPINA_PROMEDIO * G.VIAJES,
       G.DISTANCIA_PROMEDIO * G.VIAJES
FROM CURSO.LAB4.DAILY_ZONE_METRICS G
LEFT JOIN DIM_ZONA Z    ON Z.ZONA = G.ZONA
LEFT JOIN DIM_EMPRESA E ON E.EMPRESA = G.EMPRESA;

-- 5 · Conteo de control contra el paquete.
--     Esperado: FACT_VIAJES_DIA 46715 filas y 60268466 viajes; DIM_FECHA 91; DIM_ZONA 262; DIM_EMPRESA 2.
--     Resultado en la cuenta del anfitrión: 46715 filas y 60268466 viajes (cuadra).
SELECT 'FACT_VIAJES_DIA' AS TABLA, COUNT(*) AS FILAS, SUM(VIAJES) AS VIAJES FROM FACT_VIAJES_DIA
UNION ALL SELECT 'DIM_FECHA',   COUNT(*), NULL FROM DIM_FECHA
UNION ALL SELECT 'DIM_ZONA',    COUNT(*), NULL FROM DIM_ZONA
UNION ALL SELECT 'DIM_EMPRESA', COUNT(*), NULL FROM DIM_EMPRESA;
