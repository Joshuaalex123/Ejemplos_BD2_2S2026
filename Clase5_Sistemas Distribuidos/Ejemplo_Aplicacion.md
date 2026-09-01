# Parte practica: bases de datos distribuidas



## Objetivo
- Explicar replicacion y roles (primaria/secundaria)
- Comparar consistencia fuerte vs eventual en lecturas
- Introducir particionado (sharding) y ruteo de consultas
- Conectar consenso con commits distribuidos
- Relacionar casos de uso con el modelo de consistencia

## Actividad 1: replicacion primaria-secundaria
**Meta**: entender el rol del lider y el retraso de replicas.

### Explicacion
En un esquema de replicacion primaria-secundaria, la primaria recibe todas las
escrituras y las replicas aplican los cambios propagados. Este diseno reduce
conflictos y mejora la latencia de escritura, pero concentra el rol critico en
la primaria. Ante una falla, se requiere un proceso de failover para promover
una replica o detener las escrituras.

En la secuencia temporal, el cliente escribe saldo=100 y la primaria responde
con ACK antes de que las replicas apliquen el cambio. En ese intervalo, una
lectura desde una replica puede devolver un valor anterior. Este comportamiento
corresponde a replicacion asincrona: mayor rapidez a costa de riesgo de lectura
desfasada.

Desde la perspectiva del negocio, la fuente de lectura depende de la
criticidad del dato. Para saldos bancarios se prefieren lecturas en primaria
o con quorum, mientras que para contadores de visitas un pequeno retraso puede
ser aceptable. En resumen, la replica mejora disponibilidad y lectura, pero no
elimina el liderazgo de la primaria en las escrituras.

### Diagrama conceptual
```
Cliente -> Primaria -> Replica A
                 \-> Replica B
```
El diagrama resalta el flujo de escrituras: el cliente envia cambios a la
primaria y la primaria los propaga a las replicas. Las lecturas no se muestran
porque pueden dirigirse a primaria o a replicas segun la politica elegida.

### Registro conceptual
```
T0  Cliente WRITE saldo=100 en Primaria
T1  Primaria ACK al cliente
T2  Replica A aplica WRITE
T3  Replica B aplica WRITE
```
El registro marca el orden temporal. El ACK en T1 confirma al cliente, pero no
implica que las replicas ya hayan aplicado el cambio. Por eso T2 y T3 ocurren
despues.

### Resumen
- La primaria confirma primero para reducir la latencia
- Las replicas quedan atras por propagacion
- Las lecturas en replicas pueden estar desactualizadas
Este resumen concentra el intercambio principal: menor latencia de escritura a
cambio de replicas potencialmente atrasadas.

### Puntos clave
- La replicacion no implica copia inmediata; existe retraso real
- La primaria impone un orden unico de escrituras
- La alta disponibilidad requiere mecanismos de failover
Estos puntos funcionan como criterios de evaluacion: tolerancia al retraso,
necesidad de orden total y estrategia de recuperacion ante fallas.

**Preguntas de discusion**
- Donde ocurre el punto unico de fallo?
- Que riesgo hay si leemos desde una replica atrasada?

### Respuestas sugeridas
- El punto unico de fallo es la primaria (lider); si cae, no hay escrituras hasta failover.
- Leer una replica atrasada puede devolver datos obsoletos y llevar a decisiones incorrectas.



## Actividad 2: consistencia de lectura
**Meta**: contrastar lecturas fuertes vs eventuales.

### Explicacion
La consistencia fuerte garantiza que una lectura observe el dato mas reciente
confirmado. Para ello, el sistema coordina replicas y espera a que el dato este
actualizado en la mayoria o en el lider. Esta decision incrementa la latencia,
pero reduce el riesgo de lecturas obsoletas.

La consistencia eventual prioriza una respuesta rapida. Durante el intervalo
de convergencia, clientes distintos pueden leer valores diferentes. Este
comportamiento es aceptable cuando la aplicacion tolera desfases temporales y
busca alta disponibilidad.

Como ejemplo, si un cliente escribe X=10 y otro lee de una replica atrasada,
puede observar X=0 hasta que la propagacion finalice. El tiempo de convergencia
determina cuanto dura el periodo de inconsistencia visible.

### Tabla comparativa
| Caso | Lectura fuerte | Lectura eventual |
| --- | --- | --- |
| Cliente escribe X=10 | Espera mayoria | Responde inmediato |
| Cliente lee X | Siempre 10 | Puede ser 0 o 10 |

La tabla resume el costo de cada modelo. La lectura fuerte espera replicas para
reducir riesgo, mientras que la eventual prioriza rapidez con posible desfase.

### Resumen
- Fuerte: la lectura espera replicas (mas latencia, menos riesgo)
- Eventual: respuesta rapida con posibilidad de desfasaje
El resumen sintetiza la diferencia operativa y facilita decidir politicas por
tipo de consulta o por criticidad del dato.

### Puntos clave
- La consistencia fuerte favorece exactitud
- La consistencia eventual favorece disponibilidad y velocidad
- El modelo debe alinearse con el caso de uso
En la practica, muchos sistemas ofrecen ambos modos y la aplicacion selecciona
segun el contexto de negocio.

**Preguntas de discusion**
- Que preferirias para saldo bancario?
- Que preferirias para feed de noticias?

### Respuestas 
- Saldo bancario: consistencia fuerte (leer en primaria o con quorum).
- Feed de noticias: consistencia eventual (prioriza latencia y disponibilidad).



## Actividad 3: particionado (sharding) y ruteo
**Meta**: ver como se reparte data y como se enruta una consulta.

### Explicacion
El sharding divide los datos en particiones para distribuir carga y
almacenamiento. En lugar de una sola base grande, existen varias bases
pequenas, cada una con un rango de ids. Esto mejora escalabilidad, pero
introduce complejidad operativa. La aplicacion o un router debe dirigir cada
consulta al shard correspondiente.

Con particionado por rango, el ruteo por id es directo. Sin embargo, las
consultas por rango amplio pueden requerir acceso a varios shards y agregacion
de resultados. Este patron de "fan-out" incrementa la latencia.

La seleccion de la shard key es critica. Claves con baja cardinalidad
concentran trafico en pocos shards y generan hotspots. Un balance adecuado
depende mas del diseno de la clave que del hardware.

### Mapa de shards (por rango)
```
Shard 1: id 1-1000
Shard 2: id 1001-2000
Shard 3: id 2001-3000
```
El ejemplo usa rangos continuos para simplificar el ruteo. En escenarios reales
los rangos pueden ajustarse con re-sharding a medida que crece la demanda.

### Ejemplos de ruteo
- Consulta por id=1450 -> Shard 2
- Consulta por id=2500 -> Shard 3
- Consulta por rango 900-1300 -> Shard 1 y 2
Estos ejemplos muestran que las consultas por rango amplio requieren coordinar
varios shards y combinar resultados.

### Resumen
- El router decide a que shard ir
- Consultas por rango pueden tocar varios shards
- El balanceo evita hotspots
El beneficio de escala se acompana de mayor complejidad de ruteo y posibles
impactos en latencia.

### Puntos clave
- El sharding escala escritura y almacenamiento
- Puede complicar joins y transacciones globales
- El costo oculto es el ruteo y la agregacion
Por eso, la shard key y los patrones de consulta deben definirse en conjunto.

**Preguntas de discusion**
- Que pasa si un shard se sobrecarga?
- Como afecta el sharding a joins grandes?

### Respuestas 
- Un shard sobrecargado se vuelve hotspot, aumenta la latencia y degrada el sistema; requiere rebalanceo o re-sharding.
- Los joins grandes se vuelven costosos por fan-out y agregacion entre shards, y a veces son inviables.



## Actividad 4: consenso y commit distribuido
**Meta**: explicar por que se necesita consenso para commits.

### Explicacion
El consenso permite que varios nodos acuerden un unico orden de escrituras
ante fallos. Sin consenso, diferentes nodos podrian aplicar operaciones en un
orden distinto y generar estados divergentes.

El modelo de mayoria establece que un commit es definitivo solo si obtiene
quorum. Los nodos que no respondieron se sincronizan cuando regresan al
cluster. Este enfoque evita duplicados y asegura coherencia.

Algoritmos como Raft o Paxos implementan este proceso de coordinacion y
priorizan seguridad sobre velocidad cuando no se alcanza quorum.

### Registro conceptual (estilo Raft/Paxos)
```
N1 (lider) propone commit #42
N2 vota SI
N3 vota SI
N1 decide COMMIT (mayoria 2/3)
```
El registro describe una propuesta y la recoleccion de votos. La decision se
toma solo con mayoria, lo que evita decisiones contradictorias.

### Resumen
- Sin mayoria no hay commit definitivo
- El consenso asegura un orden unico de escrituras
- Evita duplicados o estados divergentes
Este resumen explica por que el consenso sacrifica disponibilidad ante
particiones para mantener coherencia.

### Puntos clave
- El consenso prioriza seguridad sobre velocidad
- Sin quorum, el sistema prefiere no confirmar
- La mayoria es el minimo que evita dos verdades simultaneas
En escenarios de particion de red, el sistema suele detener commits antes que
aceptar estados inconsistentes.

**Preguntas de discusion**
- Por que la mayoria es critica?
- Que ocurre si hay particion de red?

### Respuestas 
- La mayoria evita dos verdades simultaneas y asegura un orden unico de commits.
- Con particion de red, el lado sin quorum suele detener commits para priorizar coherencia.


## Cierre y conexion con casos de uso
Relaciona el caso con el modelo de consistencia deseado:

- Transferencias bancarias (fuerte)
- Inventario en tiempo real (fuerte o casi fuerte)
- Feed de redes sociales (eventual)
- Logs de analitica masiva (eventual)





### Explicacion
En la conexion con casos de uso, las transferencias bancarias requieren
consistencia fuerte para evitar saldos contradictorios. En inventario en tiempo
real, el nivel de consistencia depende del impacto comercial de vender el ultimo
item; en algunos escenarios se tolera un pequeno retraso.

En redes sociales, la prioridad suele ser disponibilidad y baja latencia, por
lo que la consistencia eventual es adecuada. En logs de analitica masiva, el
volumen y la posterioridad del procesamiento permiten consistencia eventual.

La conclusion es que no existe una unica respuesta. El sistema se disena segun
el costo del error, la latencia aceptable y el volumen de datos.
