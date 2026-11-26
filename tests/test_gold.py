from __future__ import annotations

from datetime import date

from pyspark.sql import functions as F

from pipeline import quality
from pipeline.gold import (
    COLUMNAS_AEROPUERTOS_LLUVIA,
    COLUMNAS_TARIFA_POR_MILLA,
    TABLAS_GOLD,
    aeropuertos_lluvia,
    tarifa_por_milla_por_barrio,
)
from pipeline.silver import clima_diario, enriquecer, limpiar_viajes

MESES = ["2024-01"]


# --- el ejemplo de la casa: tarifa por milla por barrio y franja del día -----------------------

ESQUEMA_ENRIQUECIDO = (
    "pickup_date date, pickup_datetime string, borough string, distancia_mi double, "
    "total_pagado double"
)


def _enriquecido(spark, filas):
    """La hora llega como texto y se convierte con Spark: así hora y franja usan la misma zona."""
    df = spark.createDataFrame(filas, ESQUEMA_ENRIQUECIDO)
    return df.withColumn("pickup_datetime", F.to_timestamp("pickup_datetime"))


def test_tabla_de_la_casa_esta_en_tablas_gold():
    assert list(TABLAS_GOLD) == ["tarifa_por_milla_barrio", "ing_cluade_pro_aeropuertos_lluvia"]
    assert TABLAS_GOLD["tarifa_por_milla_barrio"] is tarifa_por_milla_por_barrio
    assert TABLAS_GOLD["ing_cluade_pro_aeropuertos_lluvia"] is aeropuertos_lluvia


# --- la tabla del equipo: aeropuertos frente al resto, con y sin lluvia ------------------------

ESQUEMA_AEROPUERTOS = (
    "pickup_date date, zona string, lluvia_mm double, propina double, total_pagado double"
)


def test_aeropuertos_lluvia_valores_conocidos(spark):
    dia_1, dia_2, dia_3 = date(2024, 1, 1), date(2024, 1, 2), date(2024, 1, 3)
    enriquecido = spark.createDataFrame(
        [
            (dia_1, "JFK Airport", 5.0, 2.0, 50.0),
            (dia_1, "LaGuardia Airport", 5.0, 1.0, 30.0),
            (dia_1, "Astoria", 5.0, 0.5, 20.0),
            (dia_2, "JFK Airport", 0.5, 0.0, 40.0),
            (dia_2, "Newark Airport", 0.5, 3.0, 60.0),
            (dia_3, "Zona 264", None, 1.0, 10.0),
        ],
        ESQUEMA_AEROPUERTOS,
    )
    gold = aeropuertos_lluvia(enriquecido)

    assert gold.columns == COLUMNAS_AEROPUERTOS_LLUVIA
    filas = {(f["fecha"], f["tipo_zona"]): f for f in gold.collect()}
    assert sorted(filas) == [
        (dia_1, "aeropuerto"),
        (dia_1, "resto"),
        (dia_2, "aeropuerto"),
        (dia_2, "resto"),
        (dia_3, "resto"),
    ]

    # JFK y LaGuardia son aeropuerto; 1 mm o más es día con lluvia.
    aeropuerto_1 = filas[(dia_1, "aeropuerto")]
    assert aeropuerto_1["viajes"] == 2
    assert aeropuerto_1["lluvia_mm"] == 5.0
    assert aeropuerto_1["nivel_lluvia"] == "con_lluvia"
    assert aeropuerto_1["propina_total"] == 3.0
    assert aeropuerto_1["ingreso_total"] == 80.0

    # Menos de 1 mm es sin lluvia; Newark cuenta como resto.
    assert filas[(dia_2, "aeropuerto")]["nivel_lluvia"] == "sin_lluvia"
    assert filas[(dia_2, "resto")]["viajes"] == 1
    assert filas[(dia_2, "resto")]["ingreso_total"] == 60.0

    # Sin dato de clima queda sin_dato; una zona fuera del catálogo cuenta como resto.
    assert filas[(dia_3, "resto")]["lluvia_mm"] is None
    assert filas[(dia_3, "resto")]["nivel_lluvia"] == "sin_dato"

    # Gold agrupa, pero no pierde viajes.
    assert sum(f["viajes"] for f in filas.values()) == enriquecido.count()


def test_tarifa_por_milla_valores_conocidos(spark):
    dia = date(2024, 1, 1)
    enriquecido = _enriquecido(
        spark,
        [
            (dia, "2024-01-01 08:00:00", "Manhattan", 2.0, 10.0),
            (dia, "2024-01-01 09:30:00", "Manhattan", 3.0, 20.0),
            (dia, "2024-01-01 08:05:00", "Queens", 10.0, 25.0),
        ],
    )

    gold = tarifa_por_milla_por_barrio(enriquecido)

    assert gold.columns == COLUMNAS_TARIFA_POR_MILLA
    filas = {(r["borough"], r["franja"]): r for r in gold.collect()}
    manhattan = filas[("Manhattan", "mañana")]
    assert manhattan["viajes"] == 2
    assert manhattan["distancia_total_mi"] == 5.0
    assert manhattan["ingreso_total"] == 30.0
    assert manhattan["tarifa_por_milla"] == 6.0  # 30 / 5
    assert filas[("Queens", "mañana")]["tarifa_por_milla"] == 2.5


def test_las_franjas_del_dia_cortan_a_las_6_12_y_18(spark):
    dia = date(2024, 1, 1)
    horas = {0: "madrugada", 5: "madrugada", 6: "mañana", 11: "mañana", 12: "tarde"}
    horas.update({17: "tarde", 18: "noche", 23: "noche"})
    enriquecido = _enriquecido(
        spark,
        [(dia, f"2024-01-01 {h:02d}:30:00", f"B{h}", 1.0, 5.0) for h in horas],
    )
    franjas = {
        r["borough"]: r["franja"] for r in tarifa_por_milla_por_barrio(enriquecido).collect()
    }
    assert franjas == {f"B{h}": franja for h, franja in horas.items()}


def test_un_viaje_sin_barrio_cuenta_como_desconocido(spark):
    enriquecido = _enriquecido(spark, [(date(2024, 1, 1), "2024-01-01 08:00:00", None, 1.0, 5.0)])
    gold = tarifa_por_milla_por_barrio(enriquecido)
    assert gold.first()["borough"] == "Desconocido"


def test_tarifa_por_milla_pasa_calidad_con_la_muestra(muestra_viajes, muestra_zonas, muestra_clima):
    enriquecido = enriquecer(
        limpiar_viajes(muestra_viajes, MESES), muestra_zonas, clima_diario(muestra_clima)
    )
    gold = tarifa_por_milla_por_barrio(enriquecido)

    assert gold.agg({"viajes": "sum"}).first()[0] == 90
    quality.validar(gold, nombre="gold")
    assert gold.where("tarifa_por_milla <= 0").count() == 0
