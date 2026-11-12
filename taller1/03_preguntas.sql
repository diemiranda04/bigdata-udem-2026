/*
  Taller 1 - Caso C (aeropuertos y distritos) - 03_preguntas.sql

  Queremos ver dónde se concentran los viajes y cómo se comparan los distritos. Usamos el hecho
  con DIM_ZONA (distrito y tipo de zona), DIM_EMPRESA y DIM_FECHA. Para aeropuertos tomamos
  SERVICE_ZONE = 'Airports' (JFK y LaGuardia). Newark no lo contamos como aeropuerto: está en
  Nueva Jersey, el enunciado define aeropuerto como 'Airports' y en el trimestre tiene solo 2
  recogidas (ver la consulta de Newark), así que no cambia ningún resultado.
  Debajo de cada consulta va el resultado y lo que interpretamos.

  Ventanas que usamos: RANK con QUALIFY (C2), SUM() OVER (C1, C2 y C5), AVG() OVER con ROWS (C4)
  y LAG (C5).

  Cómo correrlo: primero las líneas USE y SET; después cada consulta por separado (se selecciona
  y se pulsa Run), porque Run All solo muestra el resultado de la última.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- Si decidiéramos contar Newark como aeropuerto, se cambia a TRUE (solo afecta a C4).
SET INCLUIR_NEWARK = FALSE;


-- Newark. Recogidas en las zonas de aeropuerto, para decidir si Newark cuenta.

SELECT Z.ZONA, Z.BOROUGH, Z.SERVICE_ZONE,
       SUM(F.VIAJES) AS VIAJES,
       ROUND(100 * SUM(F.VIAJES) / SUM(SUM(F.VIAJES)) OVER (), 2) AS PCT_DE_AEROPUERTOS
FROM FACT_VIAJES_DIA F
JOIN DIM_ZONA Z ON Z.ZONA_KEY = F.ZONA_KEY
WHERE Z.SERVICE_ZONE IN ('Airports', 'EWR')
GROUP BY 1, 2, 3
ORDER BY VIAJES DESC;

/*
  Resultado:
  ZONA                BOROUGH   SERVICE_ZONE   VIAJES      PCT_DE_AEROPUERTOS
  LaGuardia Airport   Queens    Airports       1069364     50.29
  JFK Airport         Queens    Airports       1057240     49.71
  Newark Airport      EWR       EWR            2           0.00

  Interpretación: los dos aeropuertos de la ciudad suman 2126604 recogidas, el 3.53 % de los
  60268466 viajes, casi por mitades entre LaGuardia y JFK. Newark tiene solo 2: las plataformas
  con licencia de NYC prácticamente no recogen allí, porque esos viajes los registra Nueva Jersey.
  Por eso lo dejamos fuera. Ojo: son recogidas (gente que llega); los viajes hacia el aeropuerto
  empiezan en otras zonas y no se ven aquí.
*/


-- C1. Viajes por distrito y mes

SELECT Z.BOROUGH, D.MES,
       SUM(F.VIAJES) AS VIAJES,
       ROUND(100 * SUM(F.VIAJES) / SUM(SUM(F.VIAJES)) OVER (PARTITION BY D.MES), 2) AS PCT_DEL_MES
FROM FACT_VIAJES_DIA F
JOIN DIM_ZONA  Z ON Z.ZONA_KEY = F.ZONA_KEY
JOIN DIM_FECHA D ON D.FECHA    = F.FECHA
GROUP BY Z.BOROUGH, D.MES
ORDER BY D.MES, VIAJES DESC;

-- Control de C1: total del trimestre por distrito. TOTAL_GENERAL debe dar 60268466.
SELECT Z.BOROUGH,
       SUM(F.VIAJES) AS VIAJES_TRIMESTRE,
       ROUND(100 * SUM(F.VIAJES) / SUM(SUM(F.VIAJES)) OVER (), 2) AS PCT_TOTAL,
       SUM(SUM(F.VIAJES)) OVER () AS TOTAL_GENERAL
FROM FACT_VIAJES_DIA F
JOIN DIM_ZONA Z ON Z.ZONA_KEY = F.ZONA_KEY
GROUP BY Z.BOROUGH
ORDER BY VIAJES_TRIMESTRE DESC;

/*
  Resultado (viajes y % del mes; 20 filas):
  BOROUGH         2024-01             2024-02             2024-03
  Manhattan       7858501 (39.99)     7746254 (40.04)     8251302 (38.79)
  Brooklyn        5104932 (25.98)     5086133 (26.29)     5695991 (26.77)
  Queens          4037147 (20.55)     3833362 (19.82)     4329102 (20.35)
  Bronx           2367200 (12.05)     2398868 (12.40)     2682403 (12.61)
  Staten Island    281479  (1.43)      279373  (1.44)      314126  (1.48)
  N/A                 763  (0.00)         733  (0.00)         795  (0.00)
  EWR                   1  (0.00)           1  (0.00)     (sin fila)
  Unknown no aparece porque no tiene viajes. Los meses suman 19650023, 19344724 y 21273719,
  igual que el paquete, y el control da 60268466.

  Interpretación: Manhattan tiene cerca del 40 % de las recogidas los tres meses (23,9 millones
  en el trimestre, 39.6 %), después vienen Brooklyn (26.4 %), Queens (20.2 %), Bronx (12.4 %) y
  Staten Island (1.5 %). El orden no cambia de un mes a otro, pero 6 de cada 10 viajes empiezan
  fuera de Manhattan. Marzo es el mes más alto (8.3 % más que enero, con los mismos 31 días) y
  fuera de Manhattan se crece más: en viajes por día, de enero a marzo el Bronx sube 13.3 %,
  Brooklyn y Staten Island 11.6 %, Queens 7.2 % y Manhattan 5.0 %; por eso Manhattan baja a
  38.79 % en marzo. Febrero tiene menos viajes que enero, pero por día tiene más (667059 frente a
  633872): solo tiene 29 días.
  Lo que no dice: es el distrito donde empieza el viaje, no el destino. Los distritos tienen
  tamaños y poblaciones distintos, así que más viajes no es más viajes por habitante.
*/


-- C2. Ranking de zonas dentro de cada distrito

-- PCT_DEL_DISTRITO se calcula antes del QUALIFY, así que es sobre todas las zonas del distrito.
WITH VIAJES_ZONA AS (
  SELECT Z.BOROUGH, Z.ZONA, SUM(F.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA F
  JOIN DIM_ZONA Z ON Z.ZONA_KEY = F.ZONA_KEY
  GROUP BY Z.BOROUGH, Z.ZONA
)
SELECT BOROUGH,
       RANK() OVER (PARTITION BY BOROUGH ORDER BY VIAJES DESC) AS PUESTO,
       ZONA, VIAJES,
       ROUND(100 * VIAJES / SUM(VIAJES) OVER (PARTITION BY BOROUGH), 2) AS PCT_DEL_DISTRITO,
       COUNT(*) OVER (PARTITION BY BOROUGH) AS ZONAS_EN_DISTRITO
FROM VIAJES_ZONA
QUALIFY RANK() OVER (PARTITION BY BOROUGH ORDER BY VIAJES DESC) <= 3
ORDER BY BOROUGH, PUESTO;

/*
  Resultado (17 filas):
  BOROUGH         PUESTO  ZONA                               VIAJES    PCT    ZONAS
  Bronx           1       Mott Haven/Port Morris             361546     4.85  43
  Bronx           2       East Concourse/Concourse Village   307645     4.13  43
  Bronx           3       West Concourse                     287166     3.86  43
  Brooklyn        1       Crown Heights North                807434     5.08  61
  Brooklyn        2       Bushwick South                     653528     4.11  61
  Brooklyn        3       East New York                      650424     4.09  61
  EWR             1       Newark Airport                          2   100.00   1
  Manhattan       1       East Village                       842537     3.53  67
  Manhattan       2       Times Sq/Theatre District          738384     3.10  67
  Manhattan       3       Midtown Center                     716124     3.00  67
  N/A             1       Outside of NYC                       2291   100.00   1
  Queens          1       LaGuardia Airport                 1069364     8.77  68
  Queens          2       JFK Airport                       1057240     8.67  68
  Queens          3       Astoria                            588138     4.82  68
  Staten Island   1       Saint George/New Brighton          122492    14.00  20
  Staten Island   2       Bloomfield/Emerson Hill             91950    10.51  20
  Staten Island   3       Stapleton                           83475     9.54  20

  Interpretación: dentro de cada distrito el servicio está muy repartido. En Manhattan la primera
  zona (East Village) tiene solo el 3.53 % y las tres primeras suman 9.6 %; en Brooklyn (13.3 %) y
  el Bronx (12.8 %) es parecido. La excepción es Queens: LaGuardia y JFK tienen 8.77 % y 8.67 %
  (17.4 % juntas), casi el doble que Astoria, y son las dos zonas con más recogidas de toda la
  ciudad, por encima de East Village, que es la primera de Manhattan. Staten Island es el más
  concentrado (34 % en el top 3), pero con pocas zonas y pocos viajes. EWR y N/A tienen una sola
  zona y por eso salen con 100 %; eso no es un hallazgo.
*/


-- C3. Propina promedio por distrito y empresa, ponderada por viajes

-- Ponderamos con SUM(PROPINA_TOTAL) / SUM(VIAJES), no con AVG de promedios (trampa 2).
-- Agregamos el ingreso por viaje y la propina como % del ingreso para comparar mejor.
SELECT Z.BOROUGH, E.EMPRESA,
       SUM(F.VIAJES) AS VIAJES,
       ROUND(SUM(F.PROPINA_TOTAL) / NULLIF(SUM(F.VIAJES), 0), 2) AS PROPINA_PROMEDIO,
       ROUND(SUM(F.INGRESO_TOTAL) / NULLIF(SUM(F.VIAJES), 0), 2) AS INGRESO_PROMEDIO,
       ROUND(100 * SUM(F.PROPINA_TOTAL) / NULLIF(SUM(F.INGRESO_TOTAL), 0), 2) AS PROPINA_PCT_INGRESO
FROM FACT_VIAJES_DIA F
JOIN DIM_ZONA    Z ON Z.ZONA_KEY    = F.ZONA_KEY
JOIN DIM_EMPRESA E ON E.EMPRESA_KEY = F.EMPRESA_KEY
GROUP BY Z.BOROUGH, E.EMPRESA
ORDER BY Z.BOROUGH, E.EMPRESA;

/*
  Resultado (13 filas):
  BOROUGH         EMPRESA   VIAJES     PROPINA   INGRESO   PROPINA_%_INGRESO
  Bronx           Lyft       1715707    0.38     23.21      1.62
  Bronx           Uber       5732764    0.31     22.04      1.41
  Brooklyn        Lyft       4360166    0.99     25.66      3.86
  Brooklyn        Uber      11526890    0.73     25.35      2.87
  EWR             Uber             2   11.91     73.65     16.16
  Manhattan       Lyft       6135640    1.50     34.01      4.42
  Manhattan       Uber      17720417    1.43     36.35      3.93
  N/A             Lyft           867    0.34     24.77      1.38
  N/A             Uber          1424    0.72     29.07      2.48
  Queens          Lyft       3341443    1.30     32.24      4.04
  Queens          Uber       8858168    1.23     34.38      3.59
  Staten Island   Lyft        273955    0.70     23.88      2.92
  Staten Island   Uber        601023    0.91     26.33      3.46

  Interpretación: la propina cambia mucho según el distrito. En Manhattan es de 1.43 a 1.50
  dólares por viaje y en Queens de 1.23 a 1.30; en el Bronx apenas de 0.31 a 0.38, unas 4 veces
  menos. No es solo que en el Bronx los viajes cuesten menos (22 a 23 dólares frente a 34 a 36 en
  Manhattan): también la propina es una parte menor de lo pagado (1.4 % a 1.6 % frente a 3.9 % a
  4.4 %). Entre empresas la diferencia es pequeña: en 4 de los 5 distritos Lyft recibe más
  propina por viaje que Uber (la mayor diferencia es Brooklyn: 0.99 frente a 0.73); la excepción
  es Staten Island, donde Uber recibe más (0.91 frente a 0.70). Uber hace casi 3 de cada 4 viajes
  (73.7 %).
  Lo que no dice: el gold ya venía redondeado a 2 decimales, así que es aproximado al centavo, y
  es la propina registrada en la app. EWR (2 viajes) y N/A tienen tan pocos viajes que su promedio
  no sirve para comparar.
*/


-- C4. Media móvil de 7 días de las zonas de aeropuerto frente al resto

-- Primero sumamos viajes por día y grupo. Después completamos los 91 días con DIM_FECHA (LEFT
-- JOIN y COALESCE), para que ROWS BETWEEN 6 PRECEDING tome 7 días y no 7 filas. Al final ponemos
-- los dos grupos lado a lado. Del 1 al 6 de enero la ventana tiene menos de 7 días (DIAS_VENTANA).
WITH GRUPOS AS (
  SELECT 'Aeropuerto' AS GRUPO UNION ALL SELECT 'Resto'
),
DIARIO AS (
  SELECT F.FECHA,
         IFF(Z.SERVICE_ZONE = 'Airports' OR ($INCLUIR_NEWARK AND Z.SERVICE_ZONE = 'EWR'),
             'Aeropuerto', 'Resto') AS GRUPO,
         SUM(F.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA F
  JOIN DIM_ZONA Z ON Z.ZONA_KEY = F.ZONA_KEY
  GROUP BY 1, 2
),
SERIE AS (
  SELECT D.FECHA, G.GRUPO, COALESCE(X.VIAJES, 0) AS VIAJES
  FROM DIM_FECHA D
  CROSS JOIN GRUPOS G
  LEFT JOIN DIARIO X ON X.FECHA = D.FECHA AND X.GRUPO = G.GRUPO
),
MOVIL AS (
  SELECT FECHA, GRUPO, VIAJES,
         AVG(VIAJES) OVER (PARTITION BY GRUPO ORDER BY FECHA
                           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS MM7,
         COUNT(*)    OVER (PARTITION BY GRUPO ORDER BY FECHA
                           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS DIAS_VENTANA
  FROM SERIE
)
SELECT FECHA, DAYNAME(FECHA) AS DIA,
       MAX(IFF(GRUPO = 'Aeropuerto', VIAJES, NULL))        AS VIAJES_AEROPUERTO,
       ROUND(MAX(IFF(GRUPO = 'Aeropuerto', MM7, NULL)), 0) AS MM7_AEROPUERTO,
       MAX(IFF(GRUPO = 'Resto', VIAJES, NULL))             AS VIAJES_RESTO,
       ROUND(MAX(IFF(GRUPO = 'Resto', MM7, NULL)), 0)      AS MM7_RESTO,
       ROUND(100 * MAX(IFF(GRUPO = 'Aeropuerto', MM7, NULL))
             / (MAX(IFF(GRUPO = 'Aeropuerto', MM7, NULL)) + MAX(IFF(GRUPO = 'Resto', MM7, NULL))), 2)
                                                           AS PCT_AEROPUERTO_MM7,
       MAX(DIAS_VENTANA)                                   AS DIAS_VENTANA
FROM MOVIL
GROUP BY 1, 2
ORDER BY FECHA;

-- Resumen por mes: viajes promedio por día de cada grupo y % de los aeropuertos.
SELECT D.MES,
       ROUND(SUM(IFF(Z.SERVICE_ZONE = 'Airports' OR ($INCLUIR_NEWARK AND Z.SERVICE_ZONE = 'EWR'),
                     F.VIAJES, 0)) / COUNT(DISTINCT F.FECHA), 0) AS PROM_DIARIO_AEROPUERTO,
       ROUND(SUM(IFF(Z.SERVICE_ZONE = 'Airports' OR ($INCLUIR_NEWARK AND Z.SERVICE_ZONE = 'EWR'),
                     0, F.VIAJES)) / COUNT(DISTINCT F.FECHA), 0) AS PROM_DIARIO_RESTO,
       ROUND(100 * SUM(IFF(Z.SERVICE_ZONE = 'Airports' OR ($INCLUIR_NEWARK AND Z.SERVICE_ZONE = 'EWR'),
                           F.VIAJES, 0)) / SUM(F.VIAJES), 2) AS PCT_AEROPUERTO
FROM FACT_VIAJES_DIA F
JOIN DIM_ZONA  Z ON Z.ZONA_KEY = F.ZONA_KEY
JOIN DIM_FECHA D ON D.FECHA    = F.FECHA
GROUP BY D.MES
ORDER BY D.MES;

/*
  Resultado: 91 filas, una por día, sin NULL. Algunas filas:
  FECHA        DIA   VIAJES_AEROP  MM7_AEROP  VIAJES_RESTO  MM7_RESTO  PCT_AEROP_MM7  DIAS
  2024-01-01   Mon   25452         25452      612633        612633     3.99           1
  2024-01-08   Mon   24138         23864      495273        544125     4.20           7   (mayor %)
  2024-02-03   Sat   13955         20945      766494        638343     3.18           7   (día más bajo en aeropuertos)
  2024-02-18   Sun   22135         20649      659846        656266     3.05           7   (media más baja en aeropuertos)
  2024-02-19   Mon   31347         21517      521246        648845     3.21           7   (día más alto en aeropuertos)
  2024-03-06   Wed   23239         24432      695948        684705     3.45           7   (media más alta del resto)
  2024-03-26   Tue   24771         25338      567709        656818     3.71           7   (media más alta en aeropuertos)
  2024-03-31   Sun   27531         24304      630755        638485     3.67           7
  La serie suma 2126604 en aeropuertos y 58141862 en el resto: 60268466, igual que el paquete.

  Resumen por mes:
  MES       PROM_DIARIO_AEROPUERTO   PROM_DIARIO_RESTO   PCT_AEROPUERTO
  2024-01   23168                    610703              3.66
  2024-02   22403                    644656              3.36
  2024-03   24474                    661775              3.57

  Promedio por día de la semana (aeropuertos / resto), sacado de la serie:
  lun 27837 / 543538, mar 22641 / 563904, mié 22479 / 608753, jue 23602 / 639778,
  vie 23579 / 701036, sáb 16890 / 777497, dom 26557 / 637945.

  Interpretación: los aeropuertos tienen unas 23000 recogidas al día y el resto de la ciudad unas
  640000 (los aeropuertos son el 3.5 %). Las dos series no se mueven igual. En la semana, los
  aeropuertos tienen su pico el domingo y el lunes (unas 27000) y su día más bajo el sábado
  (17000), mientras el resto de la ciudad tiene su pico el sábado y su día más bajo el lunes: la
  demanda en aeropuertos sube justo cuando la de la ciudad baja. En el trimestre, la media móvil
  de los aeropuertos baja desde inicios de enero (regreso de vacaciones) hasta 20649 el 18 de
  febrero y sube a 25338 a finales de marzo; la del resto crece más parejo, de 544000 a 685000.
  Por eso el peso de los aeropuertos pasa de 4.2 % a 3.05 % y vuelve a cerca de 3.7 %. El día con
  más recogidas en aeropuertos fue el lunes 19 de febrero (31347), festivo de Presidents' Day.
  Lo que no dice: la media móvil suaviza el día de la semana pero reacciona con unos días de
  retraso, y no explica las causas (vuelos, clima o festivos no están en el modelo).
*/


-- C5. Participación de cada zona en su distrito y cambio frente al mes anterior

-- Armamos todas las combinaciones zona x mes (con COALESCE), para que LAG compare con el mes
-- anterior aunque una zona no tenga viajes algún mes. La participación es viajes de la zona sobre
-- SUM(viajes) OVER (PARTITION BY BOROUGH, MES), y CAMBIO_PP es la diferencia en puntos
-- porcentuales con el mes anterior. Mostramos las 20 zonas que más cambiaron entre las que tienen
-- al menos 10000 viajes en el mes (sin el WHERE y el LIMIT sale la tabla completa).
WITH MESES AS (
  SELECT DISTINCT MES FROM DIM_FECHA
),
VIAJES_ZM AS (
  SELECT F.ZONA_KEY, D.MES, SUM(F.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA F
  JOIN DIM_FECHA D ON D.FECHA = F.FECHA
  GROUP BY F.ZONA_KEY, D.MES
),
MALLA AS (
  SELECT Z.BOROUGH, Z.ZONA, M.MES, COALESCE(V.VIAJES, 0) AS VIAJES
  FROM DIM_ZONA Z
  CROSS JOIN MESES M
  LEFT JOIN VIAJES_ZM V ON V.ZONA_KEY = Z.ZONA_KEY AND V.MES = M.MES
),
PARTICIPACION AS (
  SELECT BOROUGH, ZONA, MES, VIAJES,
         100 * VIAJES / NULLIF(SUM(VIAJES) OVER (PARTITION BY BOROUGH, MES), 0) AS PART
  FROM MALLA
),
CAMBIO AS (
  SELECT BOROUGH, ZONA, MES, VIAJES,
         ROUND(PART, 2) AS PARTICIPACION_PCT,
         ROUND(LAG(PART) OVER (PARTITION BY BOROUGH, ZONA ORDER BY MES), 2) AS PARTICIPACION_MES_ANT,
         ROUND(PART - LAG(PART) OVER (PARTITION BY BOROUGH, ZONA ORDER BY MES), 2) AS CAMBIO_PP
  FROM PARTICIPACION
)
SELECT *
FROM CAMBIO
WHERE VIAJES >= 10000
  AND BOROUGH NOT IN ('EWR', 'Unknown', 'N/A')
ORDER BY ABS(CAMBIO_PP) DESC NULLS LAST
LIMIT 20;

/*
  Resultado (20 filas):
  BOROUGH         ZONA                        MES       VIAJES   PART    PART_ANT   CAMBIO_PP
  Queens          JFK Airport                 2024-02   313396    8.18    9.25      -1.07
  Staten Island   West Brighton               2024-03    17142    5.46    4.95       0.51
  Staten Island   Bloomfield/Emerson Hill     2024-03    32147   10.23   10.67      -0.43
  Staten Island   Stapleton                   2024-02    26871    9.62    9.24       0.38
  Queens          JFK Airport                 2024-03   370474    8.56    8.18       0.38
  Staten Island   Grymes Hill/Clifton         2024-02    15849    5.67    5.42       0.25
  Queens          Sunnyside                   2024-02   111934    2.92    3.16      -0.24
  Manhattan       Lower East Side             2024-02   214935    2.77    2.54       0.24
  Queens          LaGuardia Airport           2024-02   336304    8.77    8.54       0.23
  Staten Island   Mariners Harbor             2024-03    28713    9.14    9.37      -0.23
  Staten Island   South Beach/Dongan Hills    2024-03    17303    5.51    5.73      -0.22
  Queens          Jamaica                     2024-02   139010    3.63    3.41       0.21
  Queens          LaGuardia Airport           2024-03   388213    8.97    8.77       0.19
  Staten Island   Saint George/New Brighton   2024-02    39241   14.05   13.87       0.18
  Staten Island   Great Kills                 2024-03    13979    4.45    4.27       0.18
  Brooklyn        Borough Park                2024-02   106845    2.10    2.28      -0.18
  Queens          Maspeth                     2024-02    60046    1.57    1.39       0.18
  Bronx           West Concourse              2024-02    94855    3.95    3.78       0.17
  Staten Island   New Dorp/Midland Beach      2024-03    13038    4.15    3.98       0.17
  Manhattan       Morningside Heights         2024-02    95344    1.23    1.07       0.16

  Interpretación: el peso de cada zona en su distrito casi no cambia de un mes a otro. Solo un
  cambio pasa de 1 punto: JFK, que en febrero baja de 9.25 % a 8.18 % de Queens (-1.07) y en marzo
  se recupera en parte a 8.56 % (+0.38). Cuadra con C4, donde febrero es el mes más flojo de los
  aeropuertos. LaGuardia, en cambio, sube los dos meses (8.54 %, 8.77 %, 8.97 %) y en marzo queda
  por encima de JFK. Lo demás cambia medio punto o menos, y casi la mitad de las filas son de
  Staten Island, donde hay pocos viajes y cualquier variación mueve más el porcentaje.
  Lo que no dice: enero no tiene mes anterior. Que una zona pierda participación no quiere decir
  que pierda viajes; puede ser que el resto del distrito crezca más. Con 3 meses no se puede
  separar una tendencia de la temporada.
*/
