-- =====================================================================
-- TALLER 1 · 04_chequeos.sql · Controles de integridad
-- =====================================================================
-- Los cuatro controles del enunciado (filas, grano único, sin huérfanos de zona y viajes contra
-- el origen) y dos propios (sin empresa ni fecha huérfanas).
-- Salida esperada: 6 filas con HECHO = ESPERADO y RESULTADO = OK.
-- CÓMO CORRERLO: pega todo en una hoja y pulsa Run All.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

SELECT CONTROL, HECHO, ESPERADO, IFF(HECHO = ESPERADO, 'OK', 'REVISAR') AS RESULTADO
FROM (
  -- 1 · Filas: el hecho tiene las mismas filas que el gold
  SELECT 1 AS K, 'filas' AS CONTROL, COUNT(*) AS HECHO, 46715 AS ESPERADO
  FROM FACT_VIAJES_DIA
  UNION ALL
  -- 2 · Grano: una sola fila por fecha, zona y empresa
  SELECT 2, 'grano', COUNT(DISTINCT FECHA || '|' || ZONA_KEY || '|' || EMPRESA_KEY), 46715
  FROM FACT_VIAJES_DIA
  UNION ALL
  -- 3 · Sin huérfanos: toda fila del hecho encuentra su zona en DIM_ZONA
  SELECT 3, 'sin zona', COUNT(*), 0
  FROM FACT_VIAJES_DIA F LEFT JOIN DIM_ZONA Z USING (ZONA_KEY)
  WHERE Z.ZONA_KEY IS NULL
  UNION ALL
  -- 4 · Viajes: la suma coincide con el paquete
  SELECT 4, 'viajes', SUM(VIAJES), 60268466
  FROM FACT_VIAJES_DIA
  UNION ALL
  -- 5 · (propio) Sin empresa huérfana
  SELECT 5, 'sin empresa', COUNT(*), 0
  FROM FACT_VIAJES_DIA F LEFT JOIN DIM_EMPRESA E USING (EMPRESA_KEY)
  WHERE E.EMPRESA_KEY IS NULL
  UNION ALL
  -- 6 · (propio) Sin fecha huérfana
  SELECT 6, 'sin fecha', COUNT(*), 0
  FROM FACT_VIAJES_DIA F LEFT JOIN DIM_FECHA D USING (FECHA)
  WHERE D.FECHA IS NULL
)
ORDER BY K;

-- Resultado (pegar aquí la salida de la cuenta del anfitrión):
--   CONTROL     | HECHO    | ESPERADO | RESULTADO
--   filas       |          | 46715    |
--   grano       |          | 46715    |
--   sin zona    |          | 0        |
--   viajes      |          | 60268466 |
--   sin empresa |          | 0        |
--   sin fecha   |          | 0        |
