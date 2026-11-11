-- GRANO: una fila de FACT_VIAJES_DIA es una fecha, en una zona de recogida, para una empresa (Uber o Lyft).
-- =====================================================================
-- TALLER 1 · 01_estrella.sql · DDL de la estrella
-- Equipo: <nombres> · Anfitrión: <nombre> · Caso elegido: C · Aeropuertos y distritos
-- =====================================================================
-- Hecho:        FACT_VIAJES_DIA (medidas aditivas)
-- Dimensiones:  DIM_ZONA, DIM_EMPRESA, DIM_FECHA
-- Este archivo solo crea las tablas vacías; la carga está en 02_carga.sql.
-- Se puede correr varias veces (CREATE OR REPLACE). CÓMO CORRERLO: Run All.
--
-- Decisiones de diseño
--   - La lluvia (LLUVIA_MM) no se incluye: el caso C no la usa. Tampoco los festivos.
--   - DIM_ZONA tiene una fila por NOMBRE de zona, porque el gold identifica la zona por nombre
--     y el catálogo de la TLC repite 2 nombres (trampa 4).
--   - El hecho guarda totales (PROPINA_TOTAL, DISTANCIA_TOTAL) en vez de promedios, para poder
--     calcular promedios ponderados: SUM(PROPINA_TOTAL) / SUM(VIAJES) (trampa 2).
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
CREATE SCHEMA IF NOT EXISTS CURSO.T1;
USE SCHEMA CURSO.T1;

-- DIM_EMPRESA: una fila por empresa (Uber, Lyft).
CREATE OR REPLACE TABLE DIM_EMPRESA (
  EMPRESA_KEY NUMBER(38,0) NOT NULL PRIMARY KEY,
  EMPRESA     VARCHAR
);

-- DIM_ZONA: una fila por nombre de zona, con su distrito y tipo de zona.
CREATE OR REPLACE TABLE DIM_ZONA (
  ZONA_KEY     NUMBER(38,0) NOT NULL PRIMARY KEY,
  ZONA         VARCHAR,       -- nombre de la zona
  BOROUGH      VARCHAR,       -- distrito: Manhattan, Brooklyn, Queens, Bronx, Staten Island, EWR, Unknown, N/A
  SERVICE_ZONE VARCHAR,       -- tipo de zona: Yellow Zone, Boro Zone, Airports, EWR, N/A
  LOCATION_ID  NUMBER(38,0)   -- el menor LocationID de la TLC con ese nombre (referencia)
);

-- DIM_FECHA: un día por fila (para los meses de C1 y C5 y los días seguidos de C4).
CREATE OR REPLACE TABLE DIM_FECHA (
  FECHA   DATE NOT NULL PRIMARY KEY,
  ANIO    NUMBER(4,0),
  MES_NUM NUMBER(2,0),
  MES     VARCHAR(7)          -- texto YYYY-MM, por ejemplo 2024-01
);

-- FACT_VIAJES_DIA: llaves de las dimensiones y medidas que se pueden sumar.
CREATE OR REPLACE TABLE FACT_VIAJES_DIA (
  FECHA           DATE NOT NULL,  -- -> DIM_FECHA.FECHA
  ZONA_KEY        NUMBER(38,0),   -- -> DIM_ZONA.ZONA_KEY
  EMPRESA_KEY     NUMBER(38,0),   -- -> DIM_EMPRESA.EMPRESA_KEY
  VIAJES          NUMBER(38,0),
  INGRESO_TOTAL   FLOAT,
  PROPINA_TOTAL   FLOAT,          -- PROPINA_PROMEDIO * VIAJES
  DISTANCIA_TOTAL FLOAT           -- DISTANCIA_PROMEDIO * VIAJES
);

SHOW TABLES IN SCHEMA CURSO.T1;

-- Claves: cómo se une cada dimensión con el hecho y por qué esa clave es única.
--   DIM_EMPRESA: FACT.EMPRESA_KEY = DIM_EMPRESA.EMPRESA_KEY. Única: se numera con ROW_NUMBER sobre
--                SELECT DISTINCT EMPRESA (una fila por empresa).
--   DIM_ZONA:    FACT.ZONA_KEY = DIM_ZONA.ZONA_KEY. Única: se agrupa por nombre de zona antes de
--                numerar (262 nombres), así unir el gold por nombre no duplica filas.
--   DIM_FECHA:   FACT.FECHA = DIM_FECHA.FECHA. Única: una fila por fecha distinta del gold (91 días).
-- Snowflake no obliga las PRIMARY KEY; la unicidad se comprueba en 04_chequeos.sql.
