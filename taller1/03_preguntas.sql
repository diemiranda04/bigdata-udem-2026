/*
  Taller 1 - Caso C (aeropuertos y distritos) - 03_preguntas.sql

  Queremos ver dónde se concentran los viajes y cómo se comparan los distritos. Usamos el hecho
  con DIM_ZONA (distrito y tipo de zona), DIM_EMPRESA y DIM_FECHA. Para aeropuertos tomamos
  SERVICE_ZONE = 'Airports' (JFK y LaGuardia). Newark: <lo que decidamos>.
  Debajo de cada consulta va lo que interpretamos del resultado.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- C1. Viajes por distrito y mes

-- Interpretación:


-- C2. Ranking de zonas dentro de cada distrito

-- Interpretación:


-- C3. Propina promedio por distrito y empresa, ponderada por viajes

-- Interpretación:


-- C4. Media móvil de 7 días de las zonas de aeropuerto frente al resto

-- Interpretación:


-- C5. Participación de cada zona en su distrito y cambio frente al mes anterior

-- Interpretación:
