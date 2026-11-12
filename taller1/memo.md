# Memo · ¿Dónde se concentra el servicio y cómo se comparan los distritos? (Taller 1 · Caso C)

Equipo: Brayan Andres Muñoz Bedoya, Diego Alejandro Miranda Marin y Julian Andres Urrea Escobar · Anfitrión: Diego Alejandro Miranda Marin · Caso: C · Aeropuertos y distritos

## Pregunta y decisión

Este memo responde dónde se concentran los viajes de las plataformas de transporte en Nueva York entre enero y marzo
de 2024: qué distritos y qué zonas reciben más recogidas y qué peso tienen los aeropuertos. Sirve para
decidir dónde reforzar el control de tránsito, los puntos de recogida y la fiscalización de las
plataformas.

## Hallazgos

1. **Manhattan es el centro, pero no la mayoría.** Concentra cerca del 40 % de las recogidas
   (23,9 millones de 60,3 millones en el trimestre), seguido de Brooklyn (26 %), Queens (20 %),
   Bronx (12 %) y Staten Island (1,5 %). Es decir, 6 de cada 10 viajes empiezan fuera de Manhattan.
   Además, la demanda crece más rápido fuera de Manhattan: de enero a marzo, los viajes por día
   subieron 13 % en el Bronx y 12 % en Brooklyn, frente a 5 % en Manhattan.
2. **Los aeropuertos son los puntos más fuertes de la ciudad.** LaGuardia (1,07 millones de recogidas)
   y JFK (1,06 millones) son las dos zonas con más viajes de Nueva York, por encima de East Village,
   la zona líder de Manhattan (0,84 millones). En el resto de la ciudad el servicio está muy
   repartido: en Manhattan, ninguna zona pasa del 4 % de los viajes del distrito, y las 3 primeras
   suman menos del 10 %. Ese mapa es estable: de un mes a otro ninguna zona grande cambió su peso
   en su distrito más de 1 punto porcentual.
3. **Los aeropuertos van a contracorriente de la ciudad.** Reciben unas 23 000 recogidas al día
   (3,5 % del total), pero su ritmo es distinto: su día más fuerte es el domingo o el lunes (unas
   27 000) y el más flojo el sábado (17 000), justo al revés que el resto de la ciudad, que tiene su
   pico el sábado. En el trimestre, la demanda en aeropuertos cae desde inicios de enero hasta
   mediados de febrero y se recupera en marzo; el día récord fue el lunes festivo 19 de febrero
   (31 347 recogidas). El refuerzo de control en aeropuertos debe planearse para domingos, lunes y
   el cierre de los fines de semana largos, no para los sábados.
4. **La propina depende mucho del distrito.** En Manhattan el pasajero deja en promedio cerca de
   1,45 dólares por viaje; en el Bronx, unos 0,33, más de 4 veces menos. La diferencia no se explica
   solo porque los viajes del Bronx sean más baratos: allí la propina es apenas el 1,5 % de lo
   pagado, frente a cerca del 4 % en Manhattan. Entre empresas la diferencia es pequeña: en 4 de los 5
   distritos Lyft recibe algo más de propina por viaje que Uber, aunque Uber hace 3 de cada 4 viajes.

## Supuestos y definiciones

- **Zonas con nombre repetido.** El catálogo de zonas de la TLC repite 2 nombres: Corona (2 identificadores)
  y Governor's Island/Ellis Island/Liberty Island (3). Dejamos una fila por nombre porque los repetidos
  comparten distrito y tipo de zona: 262 zonas en lugar de 265.
- **Lluvia y festivos.** No están en el modelo: el caso C no los necesita. El festivo del 19 de febrero
  se menciona solo para ubicar la fecha.
- **Aeropuertos.** Contamos como aeropuerto `SERVICE_ZONE = 'Airports'` (JFK y LaGuardia). Newark (en Nueva Jersey) **no** se cuenta
  como aeropuerto de la ciudad: está fuera de los cinco distritos y el catálogo lo clasifica aparte
  (`EWR`). En el trimestre solo tiene 2 recogidas, frente a más de 2,1 millones de JFK y LaGuardia,
  así que incluirlo o no cambia nada.
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

- **Solo tres meses de un año** (enero a marzo de 2024): no muestran la temporada de verano ni permiten
  separar una tendencia de la estacionalidad.
- **Lugar de recogida, no de destino.** En los aeropuertos medimos llegadas de pasajeros, no los viajes
  hacia el aeropuerto.
- **Solo las dos plataformas de viajes.** No incluye taxis amarillos, verdes ni transporte público, así que no es la
  movilidad total de la ciudad.
- **Volumen, no causas.** Las cifras dicen dónde hay más viajes, pero no por qué (población, tamaño de
  la zona, vuelos, clima o festivos no se controlan).
- **Propinas aproximadas.** El paquete trae promedios redondeados a 2 decimales y solo la propina
  registrada en la app.
