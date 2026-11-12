# Retos opcionales · Taller 1

Equipo: Brayan Andres Muñoz Bedoya, Diego Alejandro Miranda Marin y Julian Andres Urrea Escobar. Los retos suman hasta +15 puntos (los seis suman 17; el máximo que se acredita es 15).

| Id | Reto | Pts | ¿Hecho? | Dónde está (archivo y línea o sección) |
|---|---|---|---|---|
| R1 | Un segundo caso completo (cinco preguntas más) | 3 | sí | `05_caso_A.sql` (caso A: A1 a A5 con resultado e interpretación; ventanas `SUM() OVER`, `RANK` con `QUALIFY` y `LAG`) |
| R2 | `DIM_FECHA` con festivos y fin de semana, usada en una consulta | 2 | no | — |
| R3 | Lluvia fuerte (más de 10 mm) frente a la línea base del mismo día de la semana | 3 | no | — |
| R4 | Suite de chequeos (grano, huérfanos, reconciliación con el conteo del paquete) en un solo archivo ejecutable | 3 | sí | `04_chequeos.sql` (6 controles en una consulta, todos en OK) |
| R5 | Rachas de alta demanda (días consecutivos sobre un umbral; «huecos e islas») | 3 | sí | `R5_rachas.sql` (rachas en aeropuertos sobre el promedio diario; `ROW_NUMBER` para las islas y `AVG() OVER ()` para el umbral) |
| R6 | Tabla externa de Athena sobre el paquete y reconciliación de conteos con Snowflake, con captura de `Data scanned` | 3 | sí | Sección R6 de este archivo y `athena_data_scanned.png` |


## R6 · Reconciliación Athena vs Snowflake

Leímos los mismos archivos del paquete desde Athena (tabla externa `bigdata_lake.gold_publico`, workgroup `bigdata-wg`, us-east-2) y comparamos con nuestro hecho en Snowflake. Dan exactamente lo mismo:

| Mes | Filas Athena | Filas Snowflake | Viajes Athena | Viajes Snowflake |
|---|---|---|---|---|
| 2024-01 | 15909 | 15909 | 19650023 | 19650023 |
| 2024-02 | 14889 | 14889 | 19344724 | 19344724 |
| 2024-03 | 15917 | 15917 | 21273719 | 21273719 |
| **Total** | **46715** | **46715** | **60268466** | **60268466** |

La consulta en Athena leyó 140.18 KB (Datos analizados), aunque los archivos pesan unos 641 KB. Esto pasa porque Parquet guarda los datos por columnas: solo se leyó la columna `viajes`, y el mes sale del nombre de la carpeta (partición). Athena cobra como mínimo 10 MB por consulta, así que costó unos US$0.00005. Captura:  <img width="1411" height="647" alt="Captura de pantalla 2026-11-11 233155" src="https://github.com/user-attachments/assets/3ae73028-5499-478b-a5fe-c2b45c77a39c" /> .
