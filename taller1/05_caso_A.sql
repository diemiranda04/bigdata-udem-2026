/*
  Taller 1 - Reto R1 - 05_caso_A.sql

  Como reto hicimos también el caso A (competencia entre plataformas) con la misma estrella del
  caso C. La pregunta es si alguna de las dos empresas domina el mercado por zona y cómo cambia
  eso mes a mes. Debajo de cada consulta va lo que interpretamos.

  Ventanas que usamos: SUM() OVER (A1 y A4), RANK con QUALIFY (A3) y LAG (A5).
  A5c es una consulta de apoyo para ubicar la zona donde Lyft pasa de 70 %.

  Cómo correrlo: primero las líneas USE; después cada consulta por separado (se selecciona y se
  pulsa Run), porque Run All solo muestra el resultado de la última.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;


-- A1. Ingresos y viajes por empresa y mes

SELECT E.EMPRESA, D.MES,
       SUM(F.VIAJES) AS VIAJES,
       ROUND(SUM(F.INGRESO_TOTAL), 2) AS INGRESO,
       ROUND(100 * SUM(F.VIAJES) / SUM(SUM(F.VIAJES)) OVER (PARTITION BY D.MES), 2) AS PCT_VIAJES_MES,
       ROUND(100 * SUM(F.INGRESO_TOTAL) / SUM(SUM(F.INGRESO_TOTAL)) OVER (PARTITION BY D.MES), 2) AS PCT_INGRESO_MES,
       ROUND(SUM(F.INGRESO_TOTAL) / SUM(F.VIAJES), 2) AS INGRESO_POR_VIAJE
FROM FACT_VIAJES_DIA F
JOIN DIM_EMPRESA E ON E.EMPRESA_KEY = F.EMPRESA_KEY
JOIN DIM_FECHA   D ON D.FECHA       = F.FECHA
GROUP BY E.EMPRESA, D.MES
ORDER BY D.MES, E.EMPRESA;

/*
  Resultado:
  EMPRESA   MES       VIAJES     INGRESO         PCT_VIAJES_MES   PCT_INGRESO_MES   INGRESO_POR_VIAJE
  Lyft      2024-01    5222393   151065543.37    26.58            25.60             28.93
  Uber      2024-01   14427630   439012762.36    73.42            74.40             30.43
  Lyft      2024-02    4948252   146652622.57    25.58            24.91             29.64
  Uber      2024-02   14396472   442015343.77    74.42            75.09             30.70
  Lyft      2024-03    5657133   176930975.63    26.59            26.06             31.28
  Uber      2024-03   15616586   502018342.30    73.41            73.94             32.15
  Los viajes de cada mes suman lo mismo que el paquete (19650023, 19344724 y 21273719).

  Interpretación: el mercado está concentrado en una empresa. Uber hace casi 3 de cada 4 viajes
  (73.7 % en el trimestre, 44,4 millones frente a 15,8 millones de Lyft) y se lleva una parte un
  poco mayor del dinero (74.5 % de 1 858 millones de dólares), porque su viaje promedio cuesta más
  (31.12 frente a 29.99 dólares). La división casi no se mueve: la cuota de Uber va de 73.42 % a
  74.42 % y vuelve a 73.41 %. En febrero Lyft pierde un punto (por día, Lyft crece 1.3 % frente a
  enero y Uber 6.7 %), pero en marzo lo recupera: de enero a marzo los viajes de las dos crecen
  igual (8.3 % y 8.2 %). El ingreso por viaje sube en las dos todos los meses (Lyft de 28.93 a
  31.28 y Uber de 30.43 a 32.15), así que el ingreso crece más que los viajes.
  Lo que no dice: el ingreso es lo que paga el pasajero (tarifa, peajes, cargos y propina), no lo
  que gana la empresa. Y es la cuota de toda la ciudad; en A4 se mira zona por zona.
*/


-- A2. Propina promedio por empresa, ponderada por viajes

-- SUM(PROPINA_TOTAL) / SUM(VIAJES), no AVG de promedios (trampa 2). Para mostrar la diferencia
-- dejamos también el promedio simple (mal calculado) al lado.
SELECT E.EMPRESA,
       SUM(F.VIAJES) AS VIAJES,
       ROUND(SUM(F.PROPINA_TOTAL) / SUM(F.VIAJES), 2) AS PROPINA_PONDERADA,
       ROUND(AVG(F.PROPINA_TOTAL / NULLIF(F.VIAJES, 0)), 2) AS PROPINA_SIMPLE_MAL,
       ROUND(100 * SUM(F.PROPINA_TOTAL) / SUM(F.INGRESO_TOTAL), 2) AS PROPINA_PCT_INGRESO
FROM FACT_VIAJES_DIA F
JOIN DIM_EMPRESA E ON E.EMPRESA_KEY = F.EMPRESA_KEY
GROUP BY E.EMPRESA
ORDER BY E.EMPRESA;

/*
  Resultado:
  EMPRESA   VIAJES     PROPINA_PONDERADA   PROPINA_SIMPLE_MAL   PROPINA_PCT_INGRESO
  Lyft      15827778   1.18                1.00                 3.95
  Uber      44440688   1.06                0.89                 3.39

  Interpretación: en Lyft el pasajero deja en promedio 1.18 dólares de propina por viaje y en Uber
  1.06, unos 12 centavos más (11 %). Como el viaje de Lyft además es un poco más barato, la
  diferencia es mayor si se mira como parte de lo pagado: 3.95 % frente a 3.39 %.
  La columna PROPINA_SIMPLE_MAL muestra la trampa 2: si se promedian los promedios de cada fila sin
  pesar por viajes, sale 1.00 y 0.89, unos 17 centavos menos (cerca de 15 % por debajo) en las
  dos empresas. Pasa porque las filas con pocos viajes (zonas y días flojos, donde la propina es
  más baja) pesan lo mismo que las filas con miles de viajes. El orden entre empresas no cambia,
  pero el valor sí: con el promedio simple se subestima la propina.
  Lo que no dice: es la propina registrada en la app, y el gold ya venía redondeado a 2 decimales,
  así que es aproximado al centavo.
*/


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
  Resultado:
  EMPRESA   ZONA                BOROUGH     VIAJES   PUESTO
  Lyft      LaGuardia Airport   Queens      295689   1
  Lyft      JFK Airport         Queens      247170   2
  Lyft      East Village        Manhattan   227918   3
  Uber      JFK Airport         Queens      810070   1
  Uber      LaGuardia Airport   Queens      773675   2
  Uber      East Village        Manhattan   614619   3

  Interpretación: las dos empresas tienen las mismas tres zonas en su top: los dos aeropuertos
  (LaGuardia y JFK, en Queens) y East Village en Manhattan. Lo que cambia es el orden: a Lyft le
  va mejor en LaGuardia y a Uber en JFK. En esas zonas Uber hace entre 2.6 y 3.3 veces más viajes
  que Lyft (en JFK, 810070 frente a 247170).
  Lo que no dice: esto mide volumen, no cuota de mercado; qué parte se lleva cada empresa en cada
  zona se ve en A4.
*/


-- A4. Cuota de mercado de cada empresa en cada zona y mes

-- Armamos todas las combinaciones zona x mes x empresa (con COALESCE), para que una empresa sin
-- viajes en una zona cuente con cuota 0 y no desaparezca. La cuota es viajes de la empresa sobre
-- SUM(viajes) OVER (PARTITION BY ZONA, MES). Mostramos el resumen por empresa y mes: cuota en
-- toda la ciudad, cuota promedio de las zonas y en cuántas zonas tiene más de la mitad.
-- (Para ver la cuota de cada zona, se cambia el SELECT final por SELECT * FROM CUOTA.)
WITH MESES AS (
  SELECT DISTINCT MES FROM DIM_FECHA
),
ZONAS AS (
  SELECT DISTINCT F.ZONA_KEY FROM FACT_VIAJES_DIA F
),
VIAJES_ZME AS (
  SELECT F.ZONA_KEY, D.MES, F.EMPRESA_KEY, SUM(F.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA F
  JOIN DIM_FECHA D ON D.FECHA = F.FECHA
  GROUP BY 1, 2, 3
),
MALLA AS (
  SELECT Z.ZONA_KEY, M.MES, E.EMPRESA_KEY, E.EMPRESA, COALESCE(V.VIAJES, 0) AS VIAJES
  FROM ZONAS Z
  CROSS JOIN MESES M
  CROSS JOIN DIM_EMPRESA E
  LEFT JOIN VIAJES_ZME V
    ON V.ZONA_KEY = Z.ZONA_KEY AND V.MES = M.MES AND V.EMPRESA_KEY = E.EMPRESA_KEY
),
CUOTA AS (
  SELECT DZ.ZONA, DZ.BOROUGH, M.MES, M.EMPRESA, M.VIAJES,
         SUM(M.VIAJES) OVER (PARTITION BY M.ZONA_KEY, M.MES) AS VIAJES_ZONA,
         100 * M.VIAJES / NULLIF(SUM(M.VIAJES) OVER (PARTITION BY M.ZONA_KEY, M.MES), 0) AS CUOTA
  FROM MALLA M
  JOIN DIM_ZONA DZ ON DZ.ZONA_KEY = M.ZONA_KEY
)
SELECT EMPRESA, MES,
       ROUND(100 * SUM(VIAJES) / SUM(VIAJES_ZONA), 2) AS CUOTA_CIUDAD,
       ROUND(AVG(CUOTA), 2) AS CUOTA_PROMEDIO_ZONAS,
       COUNT_IF(CUOTA > 50) AS ZONAS_CON_MAS_DE_50,
       COUNT_IF(VIAJES_ZONA > 0) AS ZONAS_CON_VIAJES
FROM CUOTA
GROUP BY EMPRESA, MES
ORDER BY MES, EMPRESA;

/*
  Resultado:
  EMPRESA   MES       CUOTA_CIUDAD   CUOTA_PROMEDIO_ZONAS   ZONAS_CON_MAS_DE_50   ZONAS_CON_VIAJES
  Lyft      2024-01   26.58          27.93                  3                     261
  Uber      2024-01   73.42          72.07                  258                   261
  Lyft      2024-02   25.58          26.30                  3                     261
  Uber      2024-02   74.42          73.70                  258                   261
  Lyft      2024-03   26.59          26.97                  2                     260
  Uber      2024-03   73.41          73.03                  257                   260

  Interpretación: el dominio de Uber no está en unas pocas zonas, está en casi toda la ciudad.
  Uber tiene más de la mitad de los viajes en 258 de las 261 zonas con viajes en enero y febrero,
  y en 257 de 260 en marzo; Lyft solo es mayoría en 2 o 3 zonas. La cuota promedio por zona es
  casi igual a la de toda la ciudad (Lyft 27.93 % frente a 26.58 % en enero), es decir, la
  competencia se reparte de forma pareja en el mapa. Que el promedio de zonas de Lyft sea un poco
  más alto que su cuota en la ciudad indica que le va algo mejor en zonas pequeñas que en las
  grandes. Mes a mes casi nada cambia: Lyft baja un punto en febrero y lo recupera en marzo.
  Lo que no dice: cuáles son las zonas donde gana Lyft; eso y el cambio por zona se ven en A5.
*/


-- A5. Variación mensual de la cuota y zonas donde una empresa pasa de 70 %

-- Mismo cálculo de cuota que en A4, y LAG para compararla con el mes anterior de la misma
-- empresa en la misma zona (por eso la malla completa: LAG mira el mes anterior, no la fila
-- anterior). Solo zonas con al menos 1000 viajes en el mes, para no sacar conclusiones de zonas
-- casi vacías.
-- A5a: resumen de zonas por encima del 70 % por empresa y mes.
-- A5b: las 20 zonas donde la cuota cambió más frente al mes anterior.
WITH MESES AS (
  SELECT DISTINCT MES FROM DIM_FECHA
),
ZONAS AS (
  SELECT DISTINCT F.ZONA_KEY FROM FACT_VIAJES_DIA F
),
VIAJES_ZME AS (
  SELECT F.ZONA_KEY, D.MES, F.EMPRESA_KEY, SUM(F.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA F
  JOIN DIM_FECHA D ON D.FECHA = F.FECHA
  GROUP BY 1, 2, 3
),
MALLA AS (
  SELECT Z.ZONA_KEY, M.MES, E.EMPRESA_KEY, E.EMPRESA, COALESCE(V.VIAJES, 0) AS VIAJES
  FROM ZONAS Z
  CROSS JOIN MESES M
  CROSS JOIN DIM_EMPRESA E
  LEFT JOIN VIAJES_ZME V
    ON V.ZONA_KEY = Z.ZONA_KEY AND V.MES = M.MES AND V.EMPRESA_KEY = E.EMPRESA_KEY
),
CUOTA AS (
  SELECT M.ZONA_KEY, M.MES, M.EMPRESA, M.VIAJES,
         SUM(M.VIAJES) OVER (PARTITION BY M.ZONA_KEY, M.MES) AS VIAJES_ZONA,
         100 * M.VIAJES / NULLIF(SUM(M.VIAJES) OVER (PARTITION BY M.ZONA_KEY, M.MES), 0) AS CUOTA
  FROM MALLA M
),
CAMBIO AS (
  SELECT C.*,
         LAG(CUOTA) OVER (PARTITION BY ZONA_KEY, EMPRESA ORDER BY MES) AS CUOTA_MES_ANT,
         CUOTA - LAG(CUOTA) OVER (PARTITION BY ZONA_KEY, EMPRESA ORDER BY MES) AS CAMBIO_PP
  FROM CUOTA C
)
SELECT EMPRESA, MES,
       COUNT(*) AS ZONAS_CON_1000_O_MAS,
       COUNT_IF(CUOTA > 70) AS ZONAS_SOBRE_70,
       ROUND(100 * COUNT_IF(CUOTA > 70) / COUNT(*), 1) AS PCT_ZONAS_SOBRE_70,
       ROUND(MAX(CUOTA), 2) AS CUOTA_MAXIMA
FROM CAMBIO
WHERE VIAJES_ZONA >= 1000
GROUP BY EMPRESA, MES
ORDER BY MES, EMPRESA;

/*
  Resultado A5a:
  EMPRESA   MES       ZONAS_CON_1000_O_MAS   ZONAS_SOBRE_70   PCT_ZONAS_SOBRE_70   CUOTA_MAXIMA
  Lyft      2024-01   249                    1                 0.4                 85.47
  Uber      2024-01   249                    194              77.9                 81.40
  Lyft      2024-02   249                    1                 0.4                 85.59
  Uber      2024-02   249                    224              90.0                 82.29
  Lyft      2024-03   250                    1                 0.4                 84.75
  Uber      2024-03   250                    211              84.4                 81.77

  Interpretación A5a: Uber pasa de 70 % en la mayoría de las zonas con al menos 1000 viajes en el
  mes: 194 de 249 en enero (77.9 %), 224 en febrero (90 %) y 211 de 250 en marzo (84.4 %). El salto
  de febrero es el mismo punto que Lyft pierde en A1 y A4, y en marzo se devuelve una parte. Aun
  así, Uber nunca pasa de 82.3 % en ninguna zona: Lyft conserva por lo menos 1 de cada 6 viajes en
  todas partes, así que no hay monopolio en ninguna zona. Lyft pasa de 70 % en una sola zona, los
  tres meses, con cerca de 85 %: Saint Michaels Cemetery/Woodside, en Queens (A5c).
*/

-- A5b. Las 20 zonas con mayor cambio de cuota (se mira la de Lyft; la de Uber es el espejo,
-- porque entre las dos suman 100 %).
WITH MESES AS (
  SELECT DISTINCT MES FROM DIM_FECHA
),
ZONAS AS (
  SELECT DISTINCT F.ZONA_KEY FROM FACT_VIAJES_DIA F
),
VIAJES_ZME AS (
  SELECT F.ZONA_KEY, D.MES, F.EMPRESA_KEY, SUM(F.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA F
  JOIN DIM_FECHA D ON D.FECHA = F.FECHA
  GROUP BY 1, 2, 3
),
MALLA AS (
  SELECT Z.ZONA_KEY, M.MES, E.EMPRESA_KEY, E.EMPRESA, COALESCE(V.VIAJES, 0) AS VIAJES
  FROM ZONAS Z
  CROSS JOIN MESES M
  CROSS JOIN DIM_EMPRESA E
  LEFT JOIN VIAJES_ZME V
    ON V.ZONA_KEY = Z.ZONA_KEY AND V.MES = M.MES AND V.EMPRESA_KEY = E.EMPRESA_KEY
),
CUOTA AS (
  SELECT M.ZONA_KEY, M.MES, M.EMPRESA, M.VIAJES,
         SUM(M.VIAJES) OVER (PARTITION BY M.ZONA_KEY, M.MES) AS VIAJES_ZONA,
         100 * M.VIAJES / NULLIF(SUM(M.VIAJES) OVER (PARTITION BY M.ZONA_KEY, M.MES), 0) AS CUOTA
  FROM MALLA M
),
CAMBIO AS (
  SELECT C.*,
         LAG(CUOTA) OVER (PARTITION BY ZONA_KEY, EMPRESA ORDER BY MES) AS CUOTA_MES_ANT,
         CUOTA - LAG(CUOTA) OVER (PARTITION BY ZONA_KEY, EMPRESA ORDER BY MES) AS CAMBIO_PP
  FROM CUOTA C
)
SELECT Z.BOROUGH, Z.ZONA, C.MES, C.VIAJES_ZONA,
       ROUND(C.CUOTA, 2) AS CUOTA_LYFT,
       ROUND(C.CUOTA_MES_ANT, 2) AS CUOTA_LYFT_MES_ANT,
       ROUND(C.CAMBIO_PP, 2) AS CAMBIO_PP,
       IFF(C.CUOTA < 30, 'Uber pasa de 70 %', IFF(C.CUOTA > 70, 'Lyft pasa de 70 %', '')) AS SOBRE_70
FROM CAMBIO C
JOIN DIM_ZONA Z ON Z.ZONA_KEY = C.ZONA_KEY
WHERE C.EMPRESA = 'Lyft'
  AND C.VIAJES_ZONA >= 1000
ORDER BY ABS(C.CAMBIO_PP) DESC NULLS LAST
LIMIT 20;

/*
  Resultado A5b:
  BOROUGH         ZONA                              MES       VIAJES_ZONA  CUOTA_LYFT  ANT     CAMBIO_PP  SOBRE_70
  Queens          Broad Channel                     2024-03     1053       18.23       22.68   -4.45      Uber pasa de 70 %
  Staten Island   Bloomfield/Emerson Hill           2024-02    29799       30.88       34.81   -3.92
  Brooklyn        South Williamsburg                2024-03    39079       24.40       20.51    3.89      Uber pasa de 70 %
  Staten Island   Heartland Village/Todt Hill       2024-02    18964       28.95       32.62   -3.66      Uber pasa de 70 %
  Staten Island   Mariners Harbor                   2024-02    26184       32.96       36.37   -3.41
  Queens          Glen Oaks                         2024-02    16075       25.15       28.48   -3.33      Uber pasa de 70 %
  Queens          Rosedale                          2024-02    35652       27.46       30.76   -3.30      Uber pasa de 70 %
  Brooklyn        Marine Park/Floyd Bennett Field   2024-03     2071       25.59       28.81   -3.22      Uber pasa de 70 %
  Staten Island   Arrochar/Fort Wadsworth           2024-02     9995       33.28       36.40   -3.13
  Staten Island   Oakwood                           2024-02     6162       27.98       31.10   -3.12      Uber pasa de 70 %
  Brooklyn        Borough Park                      2024-02   106845       21.73       24.83   -3.10      Uber pasa de 70 %
  Staten Island   Great Kills                       2024-02    11941       28.36       31.44   -3.08      Uber pasa de 70 %
  Manhattan       Upper West Side North             2024-03   107473       29.86       26.79    3.07      Uber pasa de 70 %
  Staten Island   Rossville/Woodrow                 2024-02     4500       24.33       27.37   -3.04      Uber pasa de 70 %
  Manhattan       Upper West Side South             2024-03   137971       28.97       25.96    3.01      Uber pasa de 70 %
  Staten Island   Westerleigh                       2024-02    14377       28.75       31.73   -2.97      Uber pasa de 70 %
  Brooklyn        Ocean Parkway South               2024-02    21098       21.96       24.88   -2.92      Uber pasa de 70 %
  Staten Island   West Brighton                     2024-02    13825       29.19       32.09   -2.89      Uber pasa de 70 %
  Queens          Fresh Meadows                     2024-02    16192       25.70       28.57   -2.88      Uber pasa de 70 %
  Staten Island   South Beach/Dongan Hills          2024-02    16016       31.06       33.93   -2.86

  Interpretación A5: los cambios de cuota de un mes a otro son pequeños: el mayor es de 4.45
  puntos (Broad Channel, una zona con apenas 1053 viajes) y casi todos están entre 3 y 4 puntos.
  La dirección es clara: 17 de los 20 cambios más grandes son caídas de Lyft, 15 de ellas en
  febrero, que es el mes en que Uber pasa de 70 % en el 90 % de las zonas (A5a). La mitad de esas
  20 zonas son de Staten Island, justamente donde Lyft tenía más peso (entre 27 % y 36 % en enero),
  así que febrero le quitó terreno donde era más fuerte. Las únicas subidas de Lyft son en marzo y
  en zonas grandes: Upper West Side Sur y Norte (+3.0 y +3.1 puntos, más de 100000 viajes cada una)
  y South Williamsburg (+3.9). En 16 de las 20 zonas Uber está por encima del 70 %; en las otras
  cuatro, todas de Staten Island, Lyft se mantiene por encima del 30 %.
  Lo que no dice: con 3 meses no se sabe si la caída de febrero es una tendencia o algo de ese mes,
  y la cuota no dice por qué cambia (precios, promociones o número de conductores no están en los
  datos).
*/


-- A5c. La zona donde Lyft pasa de 70 % (A5a dice que hay una sola).

SELECT Z.ZONA, Z.BOROUGH, D.MES, SUM(F.VIAJES) AS VIAJES,
       ROUND(100 * SUM(IFF(E.EMPRESA = 'Lyft', F.VIAJES, 0)) / SUM(F.VIAJES), 2) AS CUOTA_LYFT
FROM FACT_VIAJES_DIA F
JOIN DIM_ZONA    Z ON Z.ZONA_KEY    = F.ZONA_KEY
JOIN DIM_EMPRESA E ON E.EMPRESA_KEY = F.EMPRESA_KEY
JOIN DIM_FECHA   D ON D.FECHA       = F.FECHA
GROUP BY 1, 2, 3
HAVING SUM(F.VIAJES) >= 1000 AND CUOTA_LYFT > 70
ORDER BY D.MES;

/*
  Resultado A5c:
  ZONA                              BOROUGH   MES       VIAJES   CUOTA_LYFT
  Saint Michaels Cemetery/Woodside  Queens    2024-01   3124     85.47
  Saint Michaels Cemetery/Woodside  Queens    2024-02   2789     85.59
  Saint Michaels Cemetery/Woodside  Queens    2024-03   3076     84.75

  Interpretación A5c: la única zona donde Lyft domina es Saint Michaels Cemetery/Woodside, en
  Queens, con cerca del 85 % de los viajes los tres meses. Es una excepción pequeña: unas 3000
  recogidas al mes, frente a las 257 o 258 zonas donde Uber tiene la mayoría (A4). Que la cuota casi no se
  mueva (85.47 %, 85.59 %, 84.75 %) muestra que no es un caso de un mes, sino algo estable de esa
  zona. Los datos no dicen por qué (puede ser un acuerdo, un punto de recogida o una base de
  conductores cercana), así que no lo afirmamos.
*/
