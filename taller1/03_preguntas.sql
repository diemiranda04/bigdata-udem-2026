-- =====================================================================
-- TALLER 1 · 03_preguntas.sql · Las cinco preguntas del caso C
-- =====================================================================
-- Caso elegido: C · Aeropuertos y distritos
-- Pregunta guía: ¿dónde se concentra el servicio y cómo se comparan los distritos?
-- Tablas: FACT_VIAJES_DIA con DIM_ZONA (distrito y tipo de zona), DIM_EMPRESA y DIM_FECHA.
-- Ventanas exigidas entre las cinco: RANK con QUALIFY (C2), LAG (C5) y SUM o AVG con OVER (C4, C5).
-- Cada pregunta: enunciado arriba, consulta y debajo la interpretación (qué dice y qué no dice).
-- Aeropuertos: SERVICE_ZONE = 'Airports' (JFK y LaGuardia). Decisión sobre Newark (EWR): <...>
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- ---------------------------------------------------------------------
-- C1 · Viajes por distrito (BOROUGH) y mes · GROUP BY
-- ---------------------------------------------------------------------
-- TODO · consulta
-- Interpretación: <...>

-- ---------------------------------------------------------------------
-- C2 · Ranking de zonas dentro de cada distrito · RANK() OVER (PARTITION BY BOROUGH ...) y QUALIFY
-- ---------------------------------------------------------------------
-- TODO · consulta
-- Interpretación: <...>

-- ---------------------------------------------------------------------
-- C3 · Propina promedio por distrito y empresa, ponderada · SUM(PROPINA_TOTAL) / SUM(VIAJES)
-- ---------------------------------------------------------------------
-- TODO · consulta
-- Interpretación: <...>

-- ---------------------------------------------------------------------
-- C4 · Media móvil de 7 días de las zonas de aeropuerto frente al resto · AVG() OVER (ROWS ...)
-- ---------------------------------------------------------------------
-- TODO · consulta (serie diaria completa con DIM_FECHA antes de la ventana)
-- Interpretación: <...>

-- ---------------------------------------------------------------------
-- C5 · Participación de cada zona en su distrito y su cambio frente al mes anterior · SUM() OVER y LAG
-- ---------------------------------------------------------------------
-- TODO · consulta
-- Interpretación: <...>
