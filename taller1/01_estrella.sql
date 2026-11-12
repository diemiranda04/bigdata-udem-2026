-- GRANO: una fila de FACT_VIAJES_DIA es una fecha, en una zona de recogida, para una empresa.

/*
  Taller 1 - Caso C (aeropuertos y distritos) - 01_estrella.sql
  Equipo: <nombres>

  Aquí solo creamos las tablas vacías de la estrella en CURSO.T1; la carga va en 02_carga.sql.
  Armamos un hecho (FACT_VIAJES_DIA) y tres dimensiones: zona, empresa y fecha.

  Lo que decidimos:
  - DIM_ZONA queda con una fila por nombre de zona, porque el gold trae la zona por nombre y el
    catálogo de la TLC repite dos nombres (Corona y Governor's Island). Si no, se duplican viajes.
  - En el hecho guardamos la propina y la distancia como totales (promedio x viajes) y no como
    promedios, para después poder sacar promedios ponderados.
  - No metimos la lluvia ni los festivos porque el caso C no los usa.

  Cómo se une cada dimensión con el hecho:
  - DIM_ZONA por ZONA_KEY (única: una fila por nombre, 262 zonas).
  - DIM_EMPRESA por EMPRESA_KEY (única: sale de un SELECT DISTINCT de las empresas).
  - DIM_FECHA por FECHA (única: un día por fila, 91 días).
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
CREATE SCHEMA IF NOT EXISTS CURSO.T1;
USE SCHEMA CURSO.T1;

CREATE OR REPLACE TABLE DIM_EMPRESA (
  EMPRESA_KEY NUMBER(38,0) NOT NULL PRIMARY KEY,
  EMPRESA     VARCHAR
);

CREATE OR REPLACE TABLE DIM_ZONA (
  ZONA_KEY     NUMBER(38,0) NOT NULL PRIMARY KEY,
  ZONA         VARCHAR,
  BOROUGH      VARCHAR,
  SERVICE_ZONE VARCHAR,
  LOCATION_ID  NUMBER(38,0)
);

CREATE OR REPLACE TABLE DIM_FECHA (
  FECHA   DATE NOT NULL PRIMARY KEY,
  ANIO    NUMBER(4,0),
  MES_NUM NUMBER(2,0),
  MES     VARCHAR(7)
);

CREATE OR REPLACE TABLE FACT_VIAJES_DIA (
  FECHA           DATE NOT NULL,
  ZONA_KEY        NUMBER(38,0),
  EMPRESA_KEY     NUMBER(38,0),
  VIAJES          NUMBER(38,0),
  INGRESO_TOTAL   FLOAT,
  PROPINA_TOTAL   FLOAT,
  DISTANCIA_TOTAL FLOAT
);

SHOW TABLES IN SCHEMA CURSO.T1;
