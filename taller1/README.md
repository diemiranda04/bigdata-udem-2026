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
| Brayan Andres Muñoz Bedoya | <BAMUNOZ91> | Calidad y costos |

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
| `03_preguntas.sql` · C1 a C5 con interpretación | ✅ Listo: C1 a C5 con resultado e interpretación | Julian Andres Urrea Escobar y Diego Alejandro Miranda Marin |
| `memo.md` · una página | ✅ Listo: 4 hallazgos, supuestos, trampa evitada y límites | Julian Andres Urrea Escobar |
| `costos.md` + `query_profile.png` | ✅ Pendiente | Brayan Andres Muñoz Bedoya |
| `autoverificacion.txt` | ✅ Listo: 4 de 4 controles en OK | Diego Alejandro Miranda Marin |
| `RETOS.md` · R1 (`05_caso_A.sql`), R4 (`04_chequeos.sql`) y R5 (`R5_rachas.sql`) | ✅ Listo: 9 puntos | Julian Andres Urrea Escobar y Diego Alejandro Miranda Marin |
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

## 5. Cómo está organizada la entrega

| Archivo | Qué tiene |
|---|---|
| `01_estrella.sql` | DDL de la estrella; el grano en la primera línea |
| `diagrama.md` | Diagrama de la estrella y sus claves |
| `02_carga.sql` | Carga desde el Lab 4 y conteo de control (46 715 filas, 60 268 466 viajes) |
| `03_preguntas.sql` | C1 a C5 y la consulta de Newark, cada una con su resultado e interpretación |
| `04_chequeos.sql` | Los controles de integridad (6 de 6 en OK); es también el reto R4 |
| `memo.md` | El memo de una página: pregunta, hallazgos, supuestos, trampa evitada y límites |
| `costos.md` + `query_profile.png` | Créditos usados y lectura del Query Profile |
| `autoverificacion.txt` | Salida de `verificar_t1.sql` (4 de 4 en OK) |
| `RETOS.md` | Los retos hechos y dónde está cada uno |
| `05_caso_A.sql` | Reto R1: el caso A completo |
| `R2_dim_fecha.sql` | Reto R2: `DIM_FECHA` con fin de semana y festivos |
| `R5_rachas.sql` | Reto R5: rachas de alta demanda en aeropuertos |
| `athena_data_scanned.png` | Reto R6: captura de Athena (la reconciliación está en `RETOS.md`) |

**Para entregar (anfitrión, antes del domingo 15 a las 23:59):** GitHub → **Releases > Draft a new release > Choose a tag** → escribir `t1-entrega` → **Create new tag** → **Publish release**. Cada integrante llena su **coevaluación** con el enlace del profesor.

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
