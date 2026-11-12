/*
  Taller 1 - Reto R5 - Rachas de alta demanda en aeropuertos - R5_rachas.sql

  Seguimos con la pregunta del caso C: buscamos los días seguidos en que las recogidas en
  aeropuertos (SERVICE_ZONE = 'Airports', JFK y LaGuardia) estuvieron por encima de lo normal.
  Como umbral usamos el promedio diario del trimestre en aeropuertos, calculado en la misma
  consulta con AVG() OVER (). Es el problema de "huecos e islas": a cada día alto le restamos su
  número de fila (ROW_NUMBER) contado solo entre los días altos; los días seguidos quedan con la
  misma fecha base y forman una racha.

  Primero completamos los 91 días con DIM_FECHA, para que un día sin viajes cuente como 0 y corte
  la racha (si faltara la fila, dos días separados se verían seguidos).

  Cómo correrlo: primero las líneas USE; después cada consulta por separado.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;


-- R5a. Rachas de días seguidos por encima del promedio diario en aeropuertos

WITH AEROP AS (
  SELECT F.FECHA, SUM(F.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA F
  JOIN DIM_ZONA Z ON Z.ZONA_KEY = F.ZONA_KEY
  WHERE Z.SERVICE_ZONE = 'Airports'
  GROUP BY F.FECHA
),
DIARIO AS (
  SELECT D.FECHA, COALESCE(A.VIAJES, 0) AS VIAJES
  FROM DIM_FECHA D
  LEFT JOIN AEROP A ON A.FECHA = D.FECHA
),
MARCADO AS (
  SELECT FECHA, VIAJES,
         AVG(VIAJES) OVER () AS UMBRAL
  FROM DIARIO
),
ISLAS AS (
  SELECT FECHA, VIAJES, UMBRAL,
         DATEADD('day', -ROW_NUMBER() OVER (ORDER BY FECHA), FECHA) AS GRUPO
  FROM MARCADO
  WHERE VIAJES > UMBRAL
)
SELECT MIN(FECHA) AS INICIO,
       MAX(FECHA) AS FIN,
       DAYNAME(MIN(FECHA)) AS DIA_INICIO,
       DAYNAME(MAX(FECHA)) AS DIA_FIN,
       COUNT(*) AS DIAS,
       ROUND(AVG(VIAJES), 0) AS PROMEDIO_RACHA,
       ROUND(MAX(UMBRAL), 0) AS UMBRAL
FROM ISLAS
GROUP BY GRUPO
ORDER BY INICIO;

/*
  Resultado R5a (19 rachas; umbral = 23369 recogidas por día, el promedio del trimestre):
  INICIO       FIN          DIA_INICIO  DIA_FIN  DIAS  PROMEDIO_RACHA
  2024-01-01   2024-01-03   Mon         Wed      3     26066
  2024-01-07   2024-01-08   Sun         Mon      2     25636
  2024-01-10   2024-01-12   Wed         Fri      3     24928
  2024-01-14   2024-01-17   Sun         Wed      4     26496
  2024-01-21   2024-01-22   Sun         Mon      2     26941
  2024-01-28   2024-01-29   Sun         Mon      2     25307
  2024-02-04   2024-02-05   Sun         Mon      2     25128
  2024-02-09   2024-02-09   Fri         Fri      1     23867
  2024-02-11   2024-02-12   Sun         Mon      2     24768
  2024-02-19   2024-02-20   Mon         Tue      2     28126
  2024-02-22   2024-02-23   Thu         Fri      2     23986
  2024-02-25   2024-03-01   Sun         Fri      6     25877
  2024-03-03   2024-03-04   Sun         Mon      2     28691
  2024-03-07   2024-03-08   Thu         Fri      2     24538
  2024-03-10   2024-03-15   Sun         Fri      6     25805
  2024-03-17   2024-03-22   Sun         Fri      6     26186
  2024-03-24   2024-03-26   Sun         Tue      3     28572
  2024-03-28   2024-03-29   Thu         Fri      2     24053
  2024-03-31   2024-03-31   Sun         Sun      1     27531
  Las rachas suman 53 de los 91 días.
*/


-- R5b. Resumen por mes: días altos, número de rachas y la racha más larga

WITH AEROP AS (
  SELECT F.FECHA, SUM(F.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA F
  JOIN DIM_ZONA Z ON Z.ZONA_KEY = F.ZONA_KEY
  WHERE Z.SERVICE_ZONE = 'Airports'
  GROUP BY F.FECHA
),
DIARIO AS (
  SELECT D.FECHA, D.MES, COALESCE(A.VIAJES, 0) AS VIAJES
  FROM DIM_FECHA D
  LEFT JOIN AEROP A ON A.FECHA = D.FECHA
),
MARCADO AS (
  SELECT FECHA, MES, VIAJES, AVG(VIAJES) OVER () AS UMBRAL
  FROM DIARIO
),
ISLAS AS (
  SELECT FECHA, MES,
         DATEADD('day', -ROW_NUMBER() OVER (ORDER BY FECHA), FECHA) AS GRUPO
  FROM MARCADO
  WHERE VIAJES > UMBRAL
),
RACHAS AS (
  SELECT GRUPO, MIN(MES) AS MES, COUNT(*) AS DIAS
  FROM ISLAS
  GROUP BY GRUPO
)
SELECT MES,
       SUM(DIAS) AS DIAS_ALTOS,
       COUNT(*) AS RACHAS,
       MAX(DIAS) AS RACHA_MAS_LARGA
FROM RACHAS
GROUP BY MES
ORDER BY MES;

/*
  Resultado R5b (cada racha se asigna al mes en que empieza):
  MES       DIAS_ALTOS   RACHAS   RACHA_MAS_LARGA
  2024-01   16           6        4
  2024-02   15           6        6
  2024-03   22           7        6
  La racha del 25 de febrero al 1 de marzo cuenta en febrero, porque ahí empieza.

  Interpretación: en el trimestre hubo 19 rachas de días seguidos con recogidas en aeropuertos
  por encima del promedio (23369 por día), que suman 53 de los 91 días. El sábado nunca supera el
  promedio, así que cada sábado corta la racha y la más larga posible es de domingo a viernes:
  6 días. Esas rachas largas solo aparecen desde finales de febrero (25 de febrero, 10 y 17 de
  marzo); antes casi todas duran 1 o 2 días y son "domingo y lunes", el regreso del fin de semana.
  Marzo es el mes de demanda más sostenida: 22 días altos, frente a 16 en enero y 15 en febrero.
  Las rachas con el promedio más alto son cortas y caen en fechas de regreso: 3 y 4 de marzo
  (28691), 24 a 26 de marzo (28572) y 19 y 20 de febrero (28126, el puente de Presidents' Day).
  Para planear: el refuerzo en aeropuertos debe cubrir domingos y lunes todo el trimestre, y en
  marzo, la semana completa de domingo a viernes.
  Lo que no dice: el umbral es el promedio del mismo trimestre; con otro umbral (por ejemplo, el
  percentil 75) las rachas serían más cortas. Y no explica la causa de los picos (vuelos, clima o
  vacaciones no están en el modelo).
*/
