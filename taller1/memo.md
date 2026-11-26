# Memo · ¿Dónde se concentra el servicio y cómo se comparan los distritos? (Taller 1 · Caso C)

Equipo: Brayan Andres Muñoz Bedoya, Diego Alejandro Miranda Marin y Julian Andres Urrea Escobar · Anfitrión: Diego Alejandro Miranda Marin · Caso: C · Aeropuertos y distritos · Fecha: 15 de noviembre de 2026

## Pregunta y decisión

¿Dónde se concentran los 60,3 millones de viajes de plataformas en Nueva York entre enero y marzo
de 2024, y qué peso tienen los aeropuertos? Sirve para decidir dónde y cuándo reforzar el control de
tránsito y los puntos de recogida.

## Hallazgos

1. **Manhattan es el centro, pero no la mayoría.** Tiene el 40 % de las recogidas; le siguen
   Brooklyn (26 %), Queens (20 %), Bronx (12 %) y Staten Island (1,5 %). Así, 6 de cada 10 viajes
   empiezan fuera de Manhattan, y fuera de Manhattan se crece más: de enero a marzo, los viajes por
   día subieron 13 % en el Bronx frente a 5 % en Manhattan.
2. **Los aeropuertos son las zonas más fuertes de la ciudad.** LaGuardia (1,07 millones de recogidas)
   y JFK (1,06 millones) superan a la primera zona de Manhattan (0,84 millones). En el resto, el
   servicio está repartido: en Manhattan ninguna zona pasa del 4 %, y ese mapa casi no cambia de un
   mes a otro.
3. **Los aeropuertos van al revés que la ciudad.** Reciben unas 23 000 recogidas al día (3,5 % del
   total). Su pico es el domingo y el lunes (27 000) y su día más bajo el sábado (17 000), cuando el
   resto de la ciudad tiene su pico. El día récord fue el lunes festivo 19 de febrero (31 347). El
   refuerzo en aeropuertos debe ir los domingos, los lunes y al cierre de los puentes.
4. **La propina depende del distrito.** En Manhattan se dejan 1,45 dólares por viaje y en el Bronx
   0,33, más de 4 veces menos; no es solo porque el viaje cueste menos: allí la propina es el 1,5 % de
   lo pagado, frente al 4 % en Manhattan. Entre empresas la diferencia es pequeña: en 4 de los 5
   distritos Lyft recibe algo más de propina que Uber, aunque Uber hace 3 de cada 4 viajes.

Estas cifras dicen dónde hay más viajes, no por qué; y miden recogidas, no destinos.

## Supuestos y definiciones

- **Aeropuerto** es `SERVICE_ZONE = 'Airports'`: JFK y LaGuardia. **Newark no cuenta**: está en
  Nueva Jersey y tuvo solo 2 recogidas en el trimestre, así que no cambia nada.
- **Zonas repetidas.** El catálogo repite Corona y Governor's Island; dejamos una fila por nombre
  (262 zonas en vez de 265), porque comparten distrito y tipo de zona.
- **Promedios ponderados.** La propina se calcula como propina total entre viajes, no como promedio de
  promedios.
- **Calendario completo** de 91 días (1 de enero a 31 de marzo de 2024). La lluvia no se usa.

## Trampa evitada

**Nombre de zona repetido (trampa 4).** Unir los viajes con el catálogo por nombre, sin corregirlo,
contaba dos o tres veces los viajes de esas zonas: 46 911 filas y 60 452 731 viajes, 184 265 de más
(0,3 %). Con una fila por nombre, el hecho queda igual al paquete: 46 715 filas y 60 268 466 viajes.

## Límites

- Solo tres meses de un año: no se puede separar una tendencia de la temporada.
- Lugar de recogida, no de destino: en los aeropuertos vemos llegadas, no viajes hacia ellos.
- Solo las dos plataformas: no incluye taxis ni transporte público.
- No explica causas (población, vuelos, clima); las propinas vienen redondeadas y son las de la app.
