# Memo · ¿Dónde se concentra el servicio de Uber y Lyft en NYC? (Taller 1 · Caso C)

Equipo: <nombres> · Anfitrión: <nombre> · Caso: C · Aeropuertos y distritos · Fecha: <fecha>

> Una página. Escribe para una persona que no sabe SQL y debe decidir algo con esto. Borra las
> instrucciones entre «>» al terminar.

## Pregunta y decisión

<En una frase: qué responde el memo y qué decisión de la autoridad de movilidad informa.
Ejemplo de forma: «Dónde y cuándo se concentran los viajes, para decidir dónde reforzar control y puntos de recogida.»>

## Hallazgos

> Tres o cuatro, cada uno con su cifra (salen de 03_preguntas.sql) y qué significa y qué no.

1. <C1: distrito con más viajes y su peso en el total.>
2. <C2 o C5: zonas que concentran el servicio dentro de su distrito.>
3. <C4: aeropuertos frente al resto en la media móvil de 7 días.>
4. <C3: diferencias de propina entre distritos o empresas.>

## Supuestos y definiciones

- **Zonas con nombre repetido.** El catálogo de zonas de la TLC repite 2 nombres: Corona (2 identificadores)
  y Governor's Island/Ellis Island/Liberty Island (3). Dejamos una fila por nombre porque los repetidos
  comparten distrito y tipo de zona: 262 zonas en lugar de 265.
- **Lluvia y festivos.** No los usamos: el caso C no los necesita.
- **Aeropuertos.** Contamos como aeropuerto `SERVICE_ZONE = 'Airports'` (JFK y LaGuardia). Newark: <decisión y por qué>.
- **Promedios.** La propina se promedia ponderando por viajes (`SUM(propina total) / SUM(viajes)`), no promediando promedios.
- **Calendario.** 91 días, del 1 de enero al 31 de marzo de 2024 (comprobado: no falta ningún día).

## Trampa evitada

**El nombre de zona repetido (trampa 4).** Si uníamos los viajes con el catálogo de zonas por nombre sin
corregirlo, cada viaje de Corona y de Governor's Island se contaba 2 o 3 veces:

| | Filas | Viajes |
|---|---|---|
| Unión ingenua por nombre | 46 911 | 60 452 731 |
| Nuestra estrella (igual al origen) | 46 715 | 60 268 466 |
| Sobraban | 196 | 184 265 (0.3 %) |

La evitamos dejando una fila por nombre en `DIM_ZONA` y comprobando que el hecho tiene las mismas
filas y viajes que el paquete.

## Límites

<Qué no se puede concluir: tres meses de un solo año, zona de recogida (no de destino), sin controlar
otros factores, solo Uber y Lyft.>
