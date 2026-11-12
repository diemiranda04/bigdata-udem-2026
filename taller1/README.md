# Taller 1 · Caso C · Aeropuertos y distritos

**Entrega: domingo 15 de noviembre de 2026, 23:59 (hora de Colombia).** Se entrega con un *release* `t1-entrega` en este fork.
Enunciado completo del profesor: [`curso/clase04/taller1/README.md`](../curso/clase04/taller1/README.md).

**Pregunta guía:** ¿dónde se concentra el servicio de Uber y Lyft en NYC y cómo se comparan los distritos?

---

## 1. Equipo y roles

| Integrante | Usuario de GitHub | Rol |
|---|---|---|
| Diego Alejandro Miranda Marin (anfitrión, dueño de este fork) | diemiranda04 | Modelador e Ingeniero de datos |
| Julian Andres Urrea Escobar | julianurreae | Analista |
| Brayan Andres Muñoz Bedoya | <usuario> | Calidad y costos |

| Rol | Responde por |
|---|---|
| Analista | Las preguntas del caso, las definiciones y el memo |
| Modelador | La estrella y las consultas con ventanas |
| Ingeniero de datos | La carga y los chequeos |
| Calidad y costos | Los controles contra el origen, las trampas y `costos.md` |

> La rúbrica da 8 puntos a que los aportes estén **repartidos y se puedan rastrear**: cada uno sube sus partes **desde su propia cuenta de GitHub**.

---

## 2. Estado

| Entregable | Estado | Responsable |
|---|---|---|
| `01_estrella.sql` · DDL y grano | ✅ Listo | Diego Alejandro Miranda Marin |
| `02_carga.sql` · carga y conteo de control | ✅ Listo y probado (46 715 filas, 60 268 466 viajes) | Diego Alejandro Miranda Marin |
| `diagrama.md` · diagrama y claves | ✅ Listo | Diego Alejandro Miranda Marin |
| `04_chequeos.sql` · controles de integridad | ✅ Listo: 6 de 6 en OK en la cuenta del anfitrión | Diego Alejandro Miranda Marin |
| `03_preguntas.sql` · C1 a C5 con interpretación | ✅ En el PR #1: falta validar los valores en la cuenta del anfitrión | Julian Andres Urrea Escobar y Diego Alejandro Miranda Marin |
| `memo.md` · una página | ✅ En el PR #1: completo, falta validar las cifras | Julian Andres Urrea Escobar |
| `costos.md` + `query_profile.png` | ⬜ Pendiente | Brayan Andres Muñoz Bedoya |
| `autoverificacion.txt` | ✅ Listo: 4 de 4 controles en OK | Diego Alejandro Miranda Marin |
| `RETOS.md` | ⬜ Pendiente (opcional) | Todos |
| Release `t1-entrega` | ⬜ Pendiente (lo crea el anfitrión) | Diego Alejandro Miranda Marin |
| Coevaluación | ⬜ Cada integrante, con el enlace del profesor | Todos |

---

## 3. Antes de empezar (cada integrante)

1. **Aceptar la invitación** de colaborador al fork (llega por correo; el anfitrión la envía en *Settings > Collaborators > Add people*).
2. **Tener el Lab 4 completo en tu Snowflake.** Comprueba en una hoja de Snowsight:
   ```sql
   USE ROLE ACCOUNTADMIN;
   USE WAREHOUSE COMPUTE_WH;
   SELECT 'DAILY_ZONE_METRICS' AS TABLA, COUNT(*) AS FILAS FROM CURSO.LAB4.DAILY_ZONE_METRICS
   UNION ALL SELECT 'DIM_ZONA', COUNT(*) FROM CURSO.LAB4.DIM_ZONA
   UNION ALL SELECT 'FESTIVOS_2024', COUNT(*) FROM CURSO.LAB4.FESTIVOS_2024;
   ```
   Debe dar **46715**, **265** y **11**. Si falta alguna tabla:
   - `DAILY_ZONE_METRICS`: ejercicios E1 y E3 de `curso/clase04/lab4.sql` (stage `LAKE_PUBLICO` + `CREATE TABLE` + **un solo** `COPY INTO`).
   - `DIM_ZONA` y `FESTIVOS_2024`: en una hoja nueva escribe `USE ROLE ACCOUNTADMIN; USE WAREHOUSE COMPUTE_WH; USE SCHEMA CURSO.LAB4;`, pega debajo `datos/dim_zona.sql` y `datos/festivos_2024.sql` (botón *Copy raw file*) y pulsa **Run All**.
3. **Replicar la estrella** en tu cuenta (cada cuenta de Snowflake es independiente: no ves las tablas de los demás):
   - `01_estrella.sql` → *Copy raw file* → hoja nueva → **Run All**.
   - `02_carga.sql` → igual. La última consulta debe dar: hecho **46715** filas y **60268466** viajes; `DIM_FECHA` **91**; `DIM_ZONA` **262**; `DIM_EMPRESA` **2**.

> **Consejo en Snowsight:** Ctrl/Cmd+Enter corre **solo la sentencia donde está el cursor**. Para correr un archivo entero usa **Run All**; para varias sentencias, selecciónalas con el mouse y pulsa ▶.

---

## 4. La estrella (ya hecha)

**Grano:** una fila de `FACT_VIAJES_DIA` = **una fecha, en una zona de recogida, para una empresa**.

```
                 DIM_FECHA
              (fecha, mes)
                    |
DIM_ZONA ------ FACT_VIAJES_DIA ------ DIM_EMPRESA
(zona, distrito,   (viajes, ingreso,      (Uber, Lyft)
 tipo de zona)      propina total)
```

Todo vive en `CURSO.T1`.

| Tabla | Columnas | Filas | Llave |
|---|---|---|---|
| `FACT_VIAJES_DIA` | `FECHA`, `ZONA_KEY`, `EMPRESA_KEY`, `VIAJES`, `INGRESO_TOTAL`, `PROPINA_TOTAL`, `DISTANCIA_TOTAL` | 46 715 | — |
| `DIM_ZONA` | `ZONA_KEY`, `ZONA`, `BOROUGH` (distrito), `SERVICE_ZONE` (tipo), `LOCATION_ID` | 262 | `ZONA_KEY` |
| `DIM_EMPRESA` | `EMPRESA_KEY`, `EMPRESA` (Lyft = 1, Uber = 2) | 2 | `EMPRESA_KEY` |
| `DIM_FECHA` | `FECHA`, `ANIO`, `MES_NUM`, `MES` (texto `YYYY-MM`) | 91 | `FECHA` |

**Cómo se unen:**
```sql
FROM FACT_VIAJES_DIA F
JOIN DIM_ZONA    Z ON Z.ZONA_KEY    = F.ZONA_KEY
JOIN DIM_EMPRESA E ON E.EMPRESA_KEY = F.EMPRESA_KEY
JOIN DIM_FECHA   D ON D.FECHA       = F.FECHA
```

**Decisiones de diseño (van en el memo):**

| Decisión | Por qué |
|---|---|
| `DIM_ZONA` con **una fila por nombre** de zona (262, no 265) | El catálogo repite Corona (2 veces) y Governor's Island/Ellis Island/Liberty Island (3). Unir por nombre sin corregirlo duplicaba viajes (trampa 4). |
| El hecho guarda **totales** (`PROPINA_TOTAL` = propina promedio × viajes) | Los promedios no se suman. Promedio ponderado = `SUM(PROPINA_TOTAL) / SUM(VIAJES)` (trampa 2). |
| **Sin lluvia ni festivos** | El caso C no los usa. |
| `DIM_FECHA` desde las fechas distintas del gold | Se comprobó que son 91 días: el calendario completo de enero a marzo de 2024. |

**La trampa evitada, con nuestros números** (ya está en `memo.md`):

| | Filas | Viajes |
|---|---|---|
| Unión ingenua por nombre de zona | 46 911 | 60 452 731 |
| Nuestra estrella (igual al origen) | 46 715 | 60 268 466 |
| Sobraban | 196 | 184 265 (0.3 %) |

---

## 5. Pendientes, paso a paso

### 5.1 Correr los chequeos · `04_chequeos.sql` (Ingeniero de datos)
1. *Copy raw file* → hoja nueva → **Run All** (en la cuenta del anfitrión).
2. Deben salir 6 filas, **todas en OK**: filas 46715, grano 46715, sin zona 0, viajes 60268466, sin empresa 0, sin fecha 0.
3. Pega el resultado en el bloque de comentarios al final del archivo y súbelo.

### 5.2 Las cinco preguntas · `03_preguntas.sql` (Analista + Modelador)
Cada pregunta lleva **su enunciado, la consulta y debajo una interpretación** (qué dice el número y qué *no* dice). La rúbrica exige, entre las cinco, `RANK` con `QUALIFY`, `LAG` y una agregación de ventana (`SUM` o `AVG` con `OVER`).

| # | Pregunta | Técnica | Pistas |
|---|---|---|---|
| C1 | Viajes por distrito (`BOROUGH`) y mes | `GROUP BY` | Une el hecho con `DIM_ZONA` y `DIM_FECHA`; agrupa por `BOROUGH` y `MES`. `BOROUGH` incluye `EWR`, `Unknown` y `N/A`: decidan si los muestran. |
| C2 | Ranking de zonas dentro de cada distrito | `RANK() OVER (PARTITION BY BOROUGH ORDER BY SUM(VIAJES) DESC)` + `QUALIFY` | Primero suma viajes por distrito y zona; luego `QUALIFY RANK() ... <= 3` para el top 3 de cada distrito. |
| C3 | Propina promedio por distrito y empresa, **ponderada** | `SUM / SUM` | `SUM(PROPINA_TOTAL) / SUM(VIAJES)`, nunca `AVG` de promedios. Redondea a 2 decimales. |
| C4 | Media móvil de 7 días: aeropuertos frente al resto | `AVG() OVER (PARTITION BY GRUPO ORDER BY FECHA ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` | Grupo = `IFF(SERVICE_ZONE = 'Airports', 'Aeropuerto', 'Resto')`. Suma viajes por grupo y **día** antes de la ventana. Como cada grupo tiene viajes los 91 días, no hay huecos (compruébenlo: 91 filas por grupo). |
| C5 | Participación de cada zona en su distrito y su cambio frente al mes anterior | `SUM() OVER (PARTITION BY BOROUGH, MES)` + `LAG() OVER (PARTITION BY ZONA ORDER BY MES)` | Participación = viajes de la zona / `SUM(viajes) OVER (PARTITION BY BOROUGH, MES)` × 100. Luego `LAG` de esa participación para el cambio en puntos porcentuales. |

**Decisión pendiente para C4 y el memo: Newark.** En `DIM_ZONA`, *Newark Airport* tiene `SERVICE_ZONE = 'EWR'` y `BOROUGH = 'EWR'` (está en Nueva Jersey), no `'Airports'`. Decidan si lo cuentan como aeropuerto y escríbanlo en el memo. Pueden mirar cuántos viajes tiene antes de decidir:
```sql
SELECT Z.ZONA, Z.SERVICE_ZONE, SUM(F.VIAJES) AS VIAJES
FROM FACT_VIAJES_DIA F JOIN DIM_ZONA Z ON Z.ZONA_KEY = F.ZONA_KEY
WHERE Z.SERVICE_ZONE IN ('Airports', 'EWR')
GROUP BY 1, 2 ORDER BY 3 DESC;
```

### 5.3 El memo · `memo.md` (Analista)
- Una página, para alguien que **no sabe SQL**.
- Ya escrito: supuestos (zonas repetidas, sin lluvia, promedios ponderados, calendario) y **trampa evitada** con la tabla de números.
- Falta: la pregunta y la decisión que informa, **3 o 4 hallazgos con cifra** (salen de C1 a C5), la decisión de Newark y los límites (solo 3 meses de 2024, zona de recogida y no de destino, solo Uber y Lyft).

### 5.4 Costos · `costos.md` + `query_profile.png` (Calidad y costos)
1. En la cuenta del anfitrión, corre la consulta de créditos que está en `costos.md` y pega el valor.
2. Snowsight > **Monitoring > Query History** → ordena por duración → abre la consulta más pesada (probablemente C4 o C5) → pestaña **Query Profile** → captura de pantalla.
3. Súbela como `query_profile.png` (*Add file > Upload files*) y escribe en `costos.md` qué operador concentra el tiempo y qué harías para reducirlo.

### 5.5 Autoverificación · `autoverificacion.txt` (anfitrión)
1. Copia `curso/clase04/taller1/verificar_t1.sql` → hoja nueva → **Run All**.
2. Debe terminar en **RESUMEN = OK · 4 de 4 controles en OK**.
3. Crea `taller1/autoverificacion.txt` y pega la tabla de resultados.

### 5.6 Retos (opcional, hasta +15) · `RETOS.md`
Primero el núcleo. Si queda tiempo, en este orden:

| Reto | Pts | Qué hacer | Esfuerzo |
|---|---|---|---|
| **R4** Suite de chequeos | 3 | Ya es nuestro `04_chequeos.sql`: correrlo y declararlo | Casi nada |
| **R6** Athena y reconciliación | 3 | En Athena (us-east-2, workgroup `bigdata-wg`): tabla externa `gold_publico` de `curso/clase04/athena_demo.sql`, filas por mes y viajes totales; comparar con Snowflake; captura de *Data scanned* | Bajo |
| **R5** Rachas de alta demanda | 3 | Días seguidos con viajes en aeropuertos sobre un umbral («huecos e islas», como el EJ9 del Lab 3A) | Medio |
| R2 `DIM_FECHA` con festivos y fin de semana | 2 | Agregar columnas a `DIM_FECHA` y usarlas en una consulta | Medio |
| R1, R3 | 3 c/u | Otro caso completo / lluvia fuerte | No recomendados (mucho trabajo o necesitan la lluvia) |

### 5.7 Entregar (anfitrión, antes del domingo 15, 23:59)
1. Revisar que todos los archivos de la sección 2 estén en `taller1/` y sin `<...>` por llenar.
2. GitHub → **Releases > Draft a new release > Choose a tag** → escribir `t1-entrega` → **Create new tag** → **Publish release**.
3. Cada integrante llena su **coevaluación** con el enlace del profesor.

---

## 6. Cómo subir y editar archivos en GitHub (sin terminal)

- **Editar:** abre el archivo en `taller1/` → lápiz ✏️ → cambia → **Commit changes**.
- **Crear:** en `taller1/` → **Add file > Create new file** → nombre (por ejemplo `autoverificacion.txt`) → **Commit changes**.
- **Imagen:** en `taller1/` → **Add file > Upload files** → arrastra `query_profile.png` → **Commit changes**.
- **Importante:** cada vez que se sube algo a `main`, se lanza el workflow **Deploy**, que corre Terraform en la cuenta de AWS del anfitrión. Para evitarlo, escribe **`[skip ci]`** al final del mensaje del commit (por ejemplo: `Pregunta C1 [skip ci]`).

---

## 7. Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `Object 'CURSO.LAB4.DAILY_ZONE_METRICS' does not exist` | No terminaste el Lab 4 en tu cuenta | Sección 3, punto 2 |
| `Object 'PARQUET_PUB' does not exist` u otro objeto «no existe» justo después de crearlo | Corriste solo una línea con Ctrl+Enter | Corre cada sentencia en orden, o selecciónalas todas y pulsa ▶ |
| El hecho tiene más de 46 715 filas | Uniste por nombre con un `DIM_ZONA` con nombres repetidos, o cargaste dos veces | Vuelve a correr `01_estrella.sql` y `02_carga.sql` completos |
| La propina promedio no coincide entre consultas | Promediaste promedios | `SUM(PROPINA_TOTAL) / SUM(VIAJES)` |
| `Window function ... appears outside of SELECT, QUALIFY, and ORDER BY` | Pusiste una ventana en `WHERE` | Muévela a `QUALIFY` |
| `Insufficient privileges` | El rol no es `ACCOUNTADMIN` | `USE ROLE ACCOUNTADMIN;` |
| Tu compañero no ve tus tablas | Cada cuenta de Snowflake es independiente | Compartan los `.sql` por el fork y cada uno los corre |
