"""Capa gold: las tablas de negocio. Cada una responde una pregunta.

Ejemplo de la casa (NO es una pregunta del Taller): «¿A qué hora del día y en qué barrio se paga
más por milla?». Se responde con `tarifa_por_milla_por_barrio`, que escribe
`gold/tarifa_por_milla_barrio/mes=AAAA-MM/`.

Cómo se arma una tabla de gold (la receta de `main`, por mes y por tabla):

    leer silver (fhvhv, taxi_zones, clima) -> silver.enriquecer(...) -> tu función
        -> validar -> escribir_capa (reemplaza mes=<mes>/)

Tu función recibe el `enriquecido` (viajes con barrio, zona y clima) y devuelve la tabla de gold.
Para agregar la tuya: escribe la función y súmala al diccionario TABLAS_GOLD (y su CREATE TABLE a
carga.py). Gold no tiene huecos.

Un detalle que se ve al reprocesar: `enriquecer` une zonas y clima, así que si silver trae las
tablas duplicadas (silver no deduplica todavía) cada viaje se repite una vez por cada fila
repetida de zonas y de clima: con dos copias de cada tabla, ×2 · ×2 · ×2 = ×8 viajes.
"""

from __future__ import annotations

from typing import Any

from pyspark.sql import DataFrame
from pyspark.sql import functions as F

from pipeline import quality, silver
from pipeline.herramientas.capas import escribir_capa, leer_capa
from pipeline.herramientas.control import con_control
from pipeline.herramientas.corrida import Resultado
from pipeline.herramientas.rutas import (
    TABLA_CLIMA,
    TABLA_VIAJES,
    TABLA_ZONAS,
    ruta_lake,
)

CAPA = "gold"

# --- el ejemplo de la casa: tarifa por milla por barrio y franja ------------------------------

COLUMNAS_TARIFA_POR_MILLA = [
    "fecha",
    "borough",
    "franja",
    "viajes",
    "distancia_total_mi",
    "ingreso_total",
    "tarifa_por_milla",
]

# Para los viajes cuya zona de recogida no está en el lookup (el barrio queda nulo).
BARRIO_DESCONOCIDO = "Desconocido"


def _franja_del_dia(hora: F.Column) -> F.Column:
    """madrugada (0 a 5 h), mañana (6 a 11), tarde (12 a 17) o noche (18 a 23)."""
    return (
        F.when(hora < 6, "madrugada")
        .when(hora < 12, "mañana")
        .when(hora < 18, "tarde")
        .otherwise("noche")
    )


def tarifa_por_milla_por_barrio(enriquecido: DataFrame) -> DataFrame:
    """Por fecha, barrio y franja del día: viajes, millas, ingreso y cuánto se paga por milla.

    tarifa_por_milla = ingreso_total / distancia_total_mi. Se calcula con las sumas completas y
    se redondea al final; así el redondeo de las sumas no mueve el cociente.
    """
    con_franja = enriquecido.select(
        F.col("pickup_date").alias("fecha"),
        F.coalesce(F.col("borough"), F.lit(BARRIO_DESCONOCIDO)).alias("borough"),
        _franja_del_dia(F.hour("pickup_datetime")).alias("franja"),
        F.col("distancia_mi"),
        F.col("total_pagado"),
    )
    return (
        con_franja.groupBy("fecha", "borough", "franja")
        .agg(
            F.count(F.lit(1)).alias("viajes"),
            F.sum("distancia_mi").alias("distancia"),
            F.sum("total_pagado").alias("ingreso"),
        )
        .select(
            "fecha",
            "borough",
            "franja",
            "viajes",
            F.round("distancia", 2).alias("distancia_total_mi"),
            F.round("ingreso", 2).alias("ingreso_total"),
            F.round(F.col("ingreso") / F.col("distancia"), 2).alias("tarifa_por_milla"),
        )
        .select(*COLUMNAS_TARIFA_POR_MILLA)
    )


# --- la tabla del equipo ing_cluade_pro: aeropuertos frente al resto, con y sin lluvia ---------

# Pregunta (taller2/contrato.md): en enero de 2024, ¿los viajes que salen de JFK y LaGuardia
# cambian más con la lluvia que los que salen del resto de la ciudad?
TABLA_AEROPUERTOS_LLUVIA = "ing_cluade_pro_aeropuertos_lluvia"

COLUMNAS_AEROPUERTOS_LLUVIA = [
    "fecha",
    "tipo_zona",
    "lluvia_mm",
    "nivel_lluvia",
    "viajes",
    "propina_total",
    "ingreso_total",
]

# Newark (EWR) no cuenta: está en Nueva Jersey y casi no tiene recogidas.
ZONAS_AEROPUERTO = ["JFK Airport", "LaGuardia Airport"]

# Un día es «con lluvia» desde 1 mm: por debajo es llovizna que casi no se nota.
UMBRAL_LLUVIA_MM = 1.0


def _nivel_lluvia(lluvia_mm: F.Column) -> F.Column:
    """con_lluvia (>= 1 mm), sin_lluvia (< 1 mm) o sin_dato (lluvia nula)."""
    return (
        F.when(lluvia_mm.isNull(), "sin_dato")
        .when(lluvia_mm >= UMBRAL_LLUVIA_MM, "con_lluvia")
        .otherwise("sin_lluvia")
    )


def aeropuertos_lluvia(enriquecido: DataFrame) -> DataFrame:
    """Por fecha y tipo de zona (aeropuerto o resto): lluvia del día, viajes, propina e ingreso.

    Grano: una fila por fecha y tipo de zona (en un mes de 31 días, 62 filas). La lluvia es una
    sola por día (viene de `enriquecer`), así que queda una vez por fila y no se suma. Las zonas
    que no están en el lookup (`Zona <id>`) cuentan como resto.
    """
    con_tipo = enriquecido.select(
        F.col("pickup_date").alias("fecha"),
        F.when(F.col("zona").isin(ZONAS_AEROPUERTO), "aeropuerto")
        .otherwise("resto")
        .alias("tipo_zona"),
        F.col("lluvia_mm"),
        F.col("propina"),
        F.col("total_pagado"),
    )
    return (
        con_tipo.groupBy("fecha", "tipo_zona")
        .agg(
            F.max("lluvia_mm").alias("lluvia_mm"),
            F.count(F.lit(1)).alias("viajes"),
            F.sum("propina").alias("propina"),
            F.sum("total_pagado").alias("ingreso"),
        )
        .select(
            "fecha",
            "tipo_zona",
            "lluvia_mm",
            _nivel_lluvia(F.col("lluvia_mm")).alias("nivel_lluvia"),
            "viajes",
            F.round("propina", 2).alias("propina_total"),
            F.round("ingreso", 2).alias("ingreso_total"),
        )
        .select(*COLUMNAS_AEROPUERTOS_LLUVIA)
    )


# nombre de la tabla en gold -> función que la arma a partir del enriquecido. El equipo agrega la
# suya aquí.
TABLAS_GOLD = {
    "tarifa_por_milla_barrio": tarifa_por_milla_por_barrio,
    TABLA_AEROPUERTOS_LLUVIA: aeropuertos_lluvia,
}


# --- el paso ----------------------------------------------------------------------------------


def _gold_de_una_tabla(spark: Any, corrida: Any, mes: str, nombre: str, construir) -> Resultado:
    """La puerta decide; si pasa, silver -> enriquecer -> tu función -> validar -> gold."""
    entorno = corrida.entorno
    fuente = ruta_lake(entorno, "silver", TABLA_VIAJES, mes)

    def trabajo() -> tuple[int, int]:
        viajes = leer_capa(spark, entorno, "silver", TABLA_VIAJES, mes)
        zonas = leer_capa(spark, entorno, "silver", TABLA_ZONAS, mes)
        clima = leer_capa(spark, entorno, "silver", TABLA_CLIMA, mes)
        enriquecido = silver.enriquecer(viajes, zonas, clima)
        # Las filas que entran al cálculo: aquí se nota si silver duplicó (cada tabla repetida
        # multiplica los viajes).
        leidas = enriquecido.count()

        gold = construir(enriquecido)
        quality.validar(gold, nombre=f"gold.{nombre}")
        escritas = escribir_capa(gold, entorno, CAPA, nombre, mes)
        return leidas, escritas

    return con_control(corrida, nombre, CAPA, mes, fuente, trabajo)


def main(spark: Any, corrida: Any) -> list[Resultado]:
    """Gold de los meses de la corrida (sin banner ni cierre); un Resultado por tabla."""
    resultados: list[Resultado] = []
    for mes in corrida.meses:
        for nombre, construir in TABLAS_GOLD.items():
            resultados.append(_gold_de_una_tabla(spark, corrida, mes, nombre, construir))
    return resultados
