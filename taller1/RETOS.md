# Retos opcionales · Taller 1

Equipo: Brayan Andres Muñoz Bedoya, Diego Alejandro Miranda Marin y Julian Andres Urrea Escobar. Los retos suman hasta +15 puntos (los seis suman 17; el máximo que se acredita es 15).

| Id | Reto | Pts | ¿Hecho? | Dónde está (archivo y línea o sección) |
|---|---|---|---|---|
| R1 | Un segundo caso completo (cinco preguntas más) | 3 | sí | `05_caso_A.sql` (caso A: A1 a A5 con resultado e interpretación; ventanas `SUM() OVER`, `RANK` con `QUALIFY` y `LAG`) |
| R2 | `DIM_FECHA` con festivos y fin de semana, usada en una consulta | 2 | no | — |
| R3 | Lluvia fuerte (más de 10 mm) frente a la línea base del mismo día de la semana | 3 | no | — |
| R4 | Suite de chequeos (grano, huérfanos, reconciliación con el conteo del paquete) en un solo archivo ejecutable | 3 | sí | `04_chequeos.sql` (6 controles en una consulta, todos en OK) |
| R5 | Rachas de alta demanda (días consecutivos sobre un umbral; «huecos e islas») | 3 | sí | `R5_rachas.sql` (rachas en aeropuertos sobre el promedio diario; `ROW_NUMBER` para las islas y `AVG() OVER ()` para el umbral) |
| R6 | Tabla externa de Athena sobre el paquete y reconciliación de conteos con Snowflake, con captura de `Data scanned` | 3 | no | — |
