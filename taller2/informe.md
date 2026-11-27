# Taller 2 · Informe · equipo ing_cluade_pro

Brayan Andrés Muñoz Bedoya (analista y modelador SQL) · Julián Andrés Urrea Escobar (ingeniero de datos) · Diego Alejandro Miranda Marín (operador cloud y calidad, anfitrión)

## 1. La pregunta y la respuesta

**Pregunta.** En enero de 2024, ¿los viajes de Uber y Lyft que salen de los aeropuertos (JFK y LaGuardia) cambian más con la lluvia que los viajes que salen del resto de la ciudad?

**Hipótesis.** Con lluvia, los viajes del resto de la ciudad suben más (en porcentaje) que los de los aeropuertos, porque dentro de la ciudad la gente cambia caminar o el metro por un carro, mientras que los viajes del aeropuerto dependen de los vuelos.

**Respuesta.** <Con lluvia, los viajes diarios del resto de la ciudad cambian X % y los de los aeropuertos Y % (n = A días con lluvia y B días sin lluvia). La hipótesis se sostiene / se contradice.>

| Tipo de zona | Días con lluvia | Días sin lluvia | Viajes/día con lluvia | Viajes/día sin lluvia | Diferencia |
|---|---|---|---|---|---|
| aeropuerto | | | | | |
| resto | | | | | |

**Para qué sirve.** <Una frase para la autoridad de movilidad: dónde reforzar recogida y control en días lluviosos.>

**Limitaciones.** Enero tiene pocos días con lluvia (n pequeño). La comparación no controla el día de la semana: <si los días con lluvia cayeron más en fin de semana o en festivo (1 y 15 de enero), decirlo aquí>. Es un mes, no un año.

## 2. La tabla del equipo y sus decisiones

Para responder la pregunta agregamos una tabla de gold propia, `ing_cluade_pro_aeropuertos_lluvia`
(función `aeropuertos_lluvia` en `src/pipeline/gold.py`). En Snowflake se carga en
`BIGDATA.DEV.ING_CLUADE_PRO_AEROPUERTOS_LLUVIA`. El gold de la casa agrupa por barrio y franja
horaria, así que no separa los aeropuertos del resto ni clasifica el día por lluvia; sin esta tabla
la pregunta no se podía responder. El cambio va solo en gold: silver no se toca.

**Grano.** Una fila por fecha y tipo de zona: en enero, 31 días por 2 tipos, 62 filas. Con este
grano la lluvia queda una sola vez por fila y por día, y se evita la trampa del Taller 1 (la lluvia
repetida en todas las filas del día).

**Decisiones:**

- **Qué es aeropuerto.** La zona de recogida es `JFK Airport` o `LaGuardia Airport`. Todo lo demás
  es `resto`.
- **Newark va en resto.** Está en Nueva Jersey y tiene muy pocas recogidas: <N> viajes en enero
  (consulta 5.1 de `conciliacion.sql`), así que no cambia el resultado.
- **Qué es un día con lluvia.** `con_lluvia` si la lluvia del día es de 1 mm o más; `sin_lluvia`
  si es menor. Usamos 1 mm porque es el umbral habitual de «día de lluvia»: por debajo es llovizna
  que casi no se nota.
- **Días sin dato de clima.** Si la lluvia es nula, el día queda como `sin_dato`, no como seco. Se
  reporta aparte y no entra en la comparación. En enero hubo <N> días sin dato.
- **Zonas fuera del catálogo** (`Zona <id>`). Cuentan como `resto`, porque no son aeropuertos: <N>
  viajes.
- **Qué se mide.** `viajes` es el número de viajes del grupo; `propina_total` y `ingreso_total`
  son sumas, redondeadas a 2 decimales al final. Se guardan sumas y no promedios, para poder
  ponderar después (la trampa de los promedios del Taller 1).

**Cómo lo comprobamos.** Una prueba con valores conocidos (en `tests/test_gold.py`) confirma cada
decisión: JFK y LaGuardia son aeropuerto, Newark es resto, 5 mm es con lluvia, 0,5 mm es sin
lluvia, una lluvia nula queda en `sin_dato` y no se pierde ningún viaje al agrupar. Otra prueba
confirma que el `CREATE TABLE` de Snowflake tiene las mismas columnas que la función. Con los datos
reales, las consultas 3.2, 4.1 y 4.2 de `conciliacion.sql` comprueban el grano (62 filas), que la
lluvia sea una por día y que el umbral se aplicó bien.

## 3. Conciliación entre capas

Corrida: `pipeline_taxi` en el Airflow del Code Editor de Diego, `computo = glue_small`, `mes = 2024-01`, `limite = todos`. Detalle y consultas en `taller2/conciliacion.sql`.

| Cruce | Cifra de un lado | Cifra del otro | ¿Cuadra? |
|---|---|---|---|
| Bronze → silver | <filas únicas de bronze> − <descartes> | <filas de silver> | |
| Silver → gold | <filas de silver> | <SUM(VIAJES) tabla del equipo> | |
| Aeropuerto | <JFK + LaGuardia en silver> | <viajes «aeropuerto» en gold> | |
| Gold → Snowflake | <FILAS de gold en WATERMARK> | <COUNT(*) en Snowflake = 62> | |

**Descartes de silver por tipo** (consulta 1.2):

| Tipo | Filas |
|---|---|
| Distancia cero o nula | |
| Distancia de 100 mi o más | |
| Tarifa cero o negativa | |
| Duración fuera de 1 a 180 min | |
| Fuera del mes | |
| Pickup o zona nula | |
| **Total descartado** | |

<Una frase que explique la diferencia bronze → silver.>

## 4. Calidad de datos: cómo aseguramos que no llegaran duplicados de silver a gold

1. **Qué hace `deduplicar`.** Deja una fila por `_hash_fila` (`dropDuplicates`). Dos filas con el mismo hash tienen los mismos valores en las columnas originales, así que da igual cuál se conserva. Se aplica a las tres tablas de silver después de limpiarlas: si clima o zonas llegaran repetidas, el cruce de `enriquecer` en gold multiplicaría cada viaje.
2. **Antes y después (Athena).** Con `deduplicar` pendiente y un reproceso: filas = <A>, hashes distintos = <B>. Con `deduplicar` escrito y otro reproceso: filas = hashes = <C>. Filas de silver = suma de `viajes` en gold = suma en Snowflake = <D>.
3. **Reproceso de un mes.** Al correr el mismo mes con `reprocesar` marcado, bronze crea un lote nuevo, pero silver y gold no crecen: <cifras antes y después>.
4. **Advertencia.** Gold tiene el mismo número de filas aunque haya duplicados, porque agrupa; lo que se infla es `viajes`. Por eso se compara la suma de `viajes` y no el número de filas.
5. **Otras reglas y qué detectaron.** Los filtros de silver (tabla de la sección 3) y las validaciones de `quality.validar` (llaves y rangos): <qué detectó cada una; una regla que no detectó nada también se reporta>.

Evidencia: capturas en `taller2/evidencia/`.

## 5. Costo

| Concepto | Valor |
|---|---|
| Créditos de Snowflake del taller | |
| Job de Glue (`glue_small`, 2 workers) | <duración> para 1 mes |
| Job de Glue (`glue_medium`, 4 workers), si se corrió | |

<¿Duplicar los workers redujo el tiempo a la mitad? Comparar con la tabla de la clase 7.>

**Configuración elegida para correrlo cada mes:** <cuál y por qué, en una frase>.

## 6. Cambios al contrato

Ver `taller2/contrato.md`, sección 9.
