/*
  Taller 1 - Caso C - 04_chequeos.sql

  Revisamos que la estrella esté bien en una sola consulta. Los cuatro primeros son los que pide
  el enunciado: que el hecho tenga las mismas filas que el gold, que no haya filas repetidas para
  la misma fecha, zona y empresa (el grano), que ningún viaje se quede sin zona y que los viajes
  sumen lo mismo que el paquete. Agregamos dos más: que ningún viaje se quede sin empresa ni sin
  fecha. Si todo está bien, las seis filas salen en OK. Se corre con Run All.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

SELECT CONTROL, HECHO, ESPERADO, IFF(HECHO = ESPERADO, 'OK', 'REVISAR') AS RESULTADO
FROM (
  SELECT 1 AS K, 'filas' AS CONTROL, COUNT(*) AS HECHO, 46715 AS ESPERADO
  FROM FACT_VIAJES_DIA
  UNION ALL
  SELECT 2, 'grano', COUNT(DISTINCT FECHA || '|' || ZONA_KEY || '|' || EMPRESA_KEY), 46715
  FROM FACT_VIAJES_DIA
  UNION ALL
  SELECT 3, 'sin zona', COUNT(*), 0
  FROM FACT_VIAJES_DIA F LEFT JOIN DIM_ZONA Z USING (ZONA_KEY)
  WHERE Z.ZONA_KEY IS NULL
  UNION ALL
  SELECT 4, 'viajes', SUM(VIAJES), 60268466
  FROM FACT_VIAJES_DIA
  UNION ALL
  SELECT 5, 'sin empresa', COUNT(*), 0
  FROM FACT_VIAJES_DIA F LEFT JOIN DIM_EMPRESA E USING (EMPRESA_KEY)
  WHERE E.EMPRESA_KEY IS NULL
  UNION ALL
  SELECT 6, 'sin fecha', COUNT(*), 0
  FROM FACT_VIAJES_DIA F LEFT JOIN DIM_FECHA D USING (FECHA)
  WHERE D.FECHA IS NULL
)
ORDER BY K;

/*
 CONTROL	HECHO	ESPERADO	RESULTADO
filas	46715	46715	OK
grano	46715	46715	OK
sin zona	0	0	OK
viajes	60268466	60268466	OK
sin empresa	0	0	OK
sin fecha	0	0	OK
*/
