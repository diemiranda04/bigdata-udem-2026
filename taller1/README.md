# Taller 1 · Caso C · Aeropuertos y distritos

**Pregunta guía:** ¿dónde se concentra el servicio de Uber y Lyft en NYC y cómo se comparan los distritos?

## Equipo

| Integrante | Usuario de GitHub | Rol |
|---|---|---|
| <nombre> (anfitrión) | <usuario> | <Analista / Modelador / Ingeniero de datos / Calidad y costos> |
| <nombre> | <usuario> | <rol> |
| <nombre> | <usuario> | <rol> |
| <nombre> | <usuario> | <rol> |

Roles: **Analista** (preguntas y memo) · **Modelador** (estrella y consultas con ventanas) · **Ingeniero de datos** (carga y chequeos) · **Calidad y costos** (controles contra el origen, trampas y `costos.md`).

## Estado

| Archivo | Estado | Responsable |
|---|---|---|
| `01_estrella.sql` | ✅ Listo (probado en la cuenta del anfitrión) | <nombre> |
| `02_carga.sql` | ✅ Listo: 46715 filas y 60268466 viajes, igual al paquete | <nombre> |
| `diagrama.md` | ✅ Listo | <nombre> |
| `04_chequeos.sql` | 🟡 Escrito; falta pegar el resultado | <nombre> |
| `03_preguntas.sql` | ⬜ Pendiente (C1 a C5) | <nombre> |
| `memo.md` | 🟡 Borrador con los supuestos y la trampa evitada | <nombre> |
| `costos.md` | ⬜ Pendiente | <nombre> |
| `RETOS.md` | ⬜ Pendiente | <nombre> |
| `autoverificacion.txt` | ⬜ Pendiente (correr `verificar_t1.sql` en la cuenta del anfitrión) | <nombre> |

## Cómo replicar la estrella en tu cuenta de Snowflake

Requisito: tener el Lab 4 completo en `CURSO.LAB4` (`DAILY_ZONE_METRICS` con 46715 filas, `DIM_ZONA` con 265 y `FESTIVOS_2024` con 11).

1. Abre `01_estrella.sql` > **Copy raw file** > pégalo en una hoja nueva de Snowsight > **Run All**.
2. Haz lo mismo con `02_carga.sql`. La última consulta debe dar 46715 filas y 60268466 viajes en el hecho, 91 en `DIM_FECHA`, 262 en `DIM_ZONA` y 2 en `DIM_EMPRESA`.
3. Corre `04_chequeos.sql`: todas las filas deben quedar en OK.

Entrega: domingo 15 de noviembre de 2026, 23:59 (hora de Colombia), con el release `t1-entrega` en este fork.
