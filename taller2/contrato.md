# Contrato del Taller 2

Equipo: ing_cluade_pro · Anfitrión (dueño del fork): Diego Alejandro Miranda Marin

## 1. Integrantes y roles

| Integrante | Rol en el Taller 1 | Rol en el Taller 2 |
|---|---|---|
| Brayan Andres Muñoz Bedoya | Calidad y costos | Analista de negocio y cumplimiento |
| Brayan Andres Muñoz Bedoya | Calidad y costos | Modelador SQL (somos tres: el analista asume también este rol) |
| Julian Andres Urrea Escobar | Analista | Ingeniero de datos |
| Diego Alejandro Miranda Marin | Modelador e Ingeniero de datos | Operador cloud y calidad |

## 2. Pregunta de negocio

> En enero de 2024, ¿los viajes de Uber y Lyft que salen de los aeropuertos (JFK y LaGuardia) cambian más con la lluvia que los viajes que salen del resto de la ciudad?

**Para quién es la respuesta y qué decisión apoyaría:** para la autoridad de movilidad de NYC. Si la demanda en los aeropuertos se comporta distinto con lluvia, sirve para decidir dónde reforzar puntos de recogida y control en días lluviosos (aeropuertos o resto de la ciudad).

## 3. Hipótesis

> Con lluvia, los viajes del resto de la ciudad suben más (en porcentaje) que los de los aeropuertos. La gente que se mueve dentro de la ciudad cambia caminar o el metro por un carro cuando llueve, mientras que los viajes del aeropuerto dependen de los vuelos y se hacen llueva o no. Puede resultar falsa: si los aeropuertos suben igual o más, la lluvia no está cambiando la forma de moverse sino algo común a toda la ciudad.

## 4. Cambio elegido

| Campo | Respuesta |
|---|---|
| Capa | gold |
| Archivo y función donde va | `src/pipeline/gold.py`, función nueva `aeropuertos_lluvia`, registrada en `TABLAS_GOLD` como `ing_cluade_pro_aeropuertos_lluvia`; su `CREATE TABLE` en `src/pipeline/carga.py` (`TABLAS_A_CARGAR`) |
| Qué se agrega o cambia | Una tabla de gold con grano **una fila por fecha y tipo de zona**. Columnas: `fecha`, `tipo_zona`, `lluvia_mm`, `nivel_lluvia`, `viajes`, `propina_total`, `ingreso_total` |
| Definición exacta | `tipo_zona` = `aeropuerto` si la zona de recogida es `JFK Airport` o `LaGuardia Airport`; `resto` en cualquier otro caso. Newark (EWR) **no** se cuenta como aeropuerto: está en Nueva Jersey y tiene muy pocas recogidas (se confirma con una consulta en Athena sobre silver). `lluvia_mm` es la lluvia del día (una sola por día, viene de `enriquecer`). `nivel_lluvia` = `con_lluvia` si `lluvia_mm >= 1.0`, `sin_lluvia` si `lluvia_mm < 1.0`, y `sin_dato` si `lluvia_mm` es nulo. Usamos 1 mm porque es el umbral habitual para llamar «día de lluvia»: menos que eso es llovizna que casi no se nota. `viajes` = número de viajes; `propina_total` = suma de `propina`; `ingreso_total` = suma de `total_pagado`. |
| Por qué lo necesita la pregunta | El gold de la casa agrupa por barrio y franja horaria: no separa los aeropuertos del resto ni clasifica el día por lluvia. Sin esta tabla no se pueden comparar los viajes por día de los aeropuertos y del resto en días con y sin lluvia. |

## 5. Cómo se comprobará

- **Cifras de Athena:** en silver, `COUNT(*)` contra `COUNT(DISTINCT _hash_fila)` del mes (deben ser iguales). Viajes de JFK y LaGuardia en silver, para cruzar con la parte `aeropuerto` de nuestra tabla.
- **Cifras de Snowflake:** en la tabla del equipo (`BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA`; no existe en Athena porque sus tablas tienen esquema fijo), conteo de filas por `tipo_zona` y por `nivel_lluvia`: deben salir 2 filas por día (aeropuerto y resto), es decir 62 filas para enero. La suma de `viajes` debe ser igual a las filas de silver del mes (`COUNT(*)` en Athena). La suma de la parte `aeropuerto` debe coincidir con los viajes de JFK más LaGuardia que da silver.
- **CI y revisión:** el PR debe tener los cinco checks en verde antes del merge. Revisor: un integrante distinto de quien escribe el cambio (si lo escribe Julián, revisa Brayan o Diego). El merge lo hace el anfitrión.
- **Corrida en Glue:** `computo = glue_small`, `limite = todos`, `mes = 2024-01`, desde el Airflow del Code Editor del anfitrión.

## 6. Qué cifra responderá la pregunta

- **Tabla de donde sale:** `BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA` (Snowflake).
- **La cifra o comparación:** para cada `tipo_zona`, viajes promedio por día con lluvia frente a viajes promedio por día sin lluvia, y la diferencia en porcentaje. Los días se cuentan con `COUNT(DISTINCT fecha)`, no con filas.
- **Cómo se leerá el resultado:** si la diferencia porcentual del `resto` es mayor que la de `aeropuerto`, la hipótesis se sostiene. Si es igual o menor, se contradice.
- **Conciliación prevista:** filas de bronze del mes menos los descartes de silver (por tipo de filtro) igual a filas de silver; filas de silver igual a la suma de `viajes` de nuestra tabla de gold; filas y suma de `viajes` en Snowflake igual a lo que escribió gold y a la tabla de control (`BIGDATA.CONTROL_DEV.WATERMARK`). Esperamos explicar los descartes de los filtros de silver (distancia, tarifa y duración fuera de rango).

## 7. Riesgos

| Riesgo | Cómo lo manejaremos |
|---|---|
| La lluvia se repite en todas las filas del día | En nuestra tabla queda una vez por fecha y tipo de zona; los días se cuentan con `COUNT(DISTINCT fecha)` |
| Pocos días con lluvia en enero, así que la comparación tiene un n pequeño | Reportamos cuántos días con y sin lluvia hay (n) junto a la cifra |
| Días sin dato de clima (`lluvia_mm` nulo) | Quedan como `sin_dato` y se reportan aparte; no entran en la comparación |
| Zonas que no están en el catálogo (`Zona <id>`) | Cuentan como `resto`; se reporta cuántos viajes son |
| Duplicados al reprocesar un mes | `deduplicar` en silver (ya escrito y comprobado con Athena: 1000 filas = 1000 hashes tras reprocesar) |
| Presupuesto de Glue | Un solo mes; primero `limite = 1000` para probar, luego `todos`; apagar todo al terminar cada sesión |

## 8. Acuerdos de trabajo

- **Reunión del equipo:** grupo de WhatsApp del equipo para el día a día; llamada corta al cerrar cada hito (25, 27 y 28 de nov.).
- **Quién revisa los PR:** cualquiera menos quien escribió el cambio; nadie aprueba su propio PR. El merge lo hace el anfitrión.
- **Cuándo se hace merge:** solo con los cinco checks en verde y una aprobación registrada.
- **Hitos propios:** 25 de nov.: contrato, `agregar_metadatos` y `deduplicar` (hechos) y evidencia de duplicados; 27 de nov.: tabla del equipo con PR y corrida del mes en Glue; 28 de nov.: conciliación, respuesta e informe; 29 de nov.: entrega.
- **Quién apaga las cuentas al terminar cada sesión:** Diego (operador cloud).
- **Si alguien no responde en 24 horas:** el resto toma su parte y lo deja escrito en esta sección.

## 9. Cambios al contrato

| Fecha | Qué cambió | Por qué |
|---|---|---|
| 25 nov. 2026 | Se llenó el contrato | No lo subimos el 18 de noviembre; lo dejamos escrito antes de programar el cambio propio |
| 25 nov. 2026 | Sección 5: el conteo por `tipo_zona` y `nivel_lluvia` se hace en Snowflake, no en Athena; sección 4: lo de Newark se confirma con silver | La tabla del equipo no existe en Athena (esquema fijo), y la cifra de Newark del Taller 1 venía de otra tabla |
