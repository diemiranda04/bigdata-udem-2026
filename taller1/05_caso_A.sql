/*
  Taller 1 - Reto R1 - 05_caso_A.sql

  Como reto hicimos también el caso A (competencia entre plataformas) con la misma estrella del
  caso C. La pregunta es si alguna de las dos empresas domina el mercado por zona y cómo cambia
  eso mes a mes. Debajo de cada consulta va lo que interpretamos.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- A1. Ingresos y viajes por empresa y mes

-- Interpretación:


-- A2. Propina promedio por empresa, ponderada por viajes

-- Interpretación:


-- A3. Las tres zonas con más viajes de cada empresa
SELECT E.EMPRESA,
       Z.ZONA,
       Z.BOROUGH,
       SUM(F.VIAJES) AS VIAJES,
       RANK() OVER (PARTITION BY E.EMPRESA ORDER BY SUM(F.VIAJES) DESC) AS PUESTO
FROM FACT_VIAJES_DIA F
JOIN DIM_EMPRESA E ON E.EMPRESA_KEY = F.EMPRESA_KEY
JOIN DIM_ZONA    Z ON Z.ZONA_KEY    = F.ZONA_KEY
GROUP BY E.EMPRESA, Z.ZONA, Z.BOROUGH
QUALIFY PUESTO <= 3
ORDER BY E.EMPRESA, PUESTO;

-- Interpretación:
/*
Las dos empresas tienen las mismas 3 zonas en su top:
los dos aeropuertos (LaGuardia y JFK, ambos en Queens) y East Village en Manhattan. 
El orden cambia: Lyft tiene más viajes en LaGuardia y Uber en JFK.

Uber hace entre 2.7 y 3.1 veces más viajes que Lyft en cada una de esas zonas. Por ejemplo, en JFK son 810070 contra 247170.
Los aeropuertos encabezan el ranking de las dos empresas.
Esto mide volumen, no cuota. Cuánto del mercado tiene cada una lo dice A4.
*/

-- A4. Cuota de mercado de cada empresa en cada zona y mes

-- Interpretación:

-- A5. Variación mensual de la cuota y zonas donde una empresa pasa del 70 %

-- Interpretación:
