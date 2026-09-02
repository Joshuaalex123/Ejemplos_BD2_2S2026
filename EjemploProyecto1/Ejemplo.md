** Sistema de reservas de boletos para cine  

---

## ¿Como funciona Cassandra?

En bases de datos relacionales el flujo es:
```
Entidades → Modelo ER → Normalizar tablas → Escribir queries
```

En Cassandra el flujo es el **inverso**:
```
Queries del negocio → Diseñar tablas para cada query → Modelo físico
```

Una tabla en Cassandra existe para responder **una query específica**. 
Si necesitan responder 5 queries distintas, probablemente necesiten 5 tablas distintas (aunque dupliquen datos).

---

## Fase 1 — Modelo Conceptual (Entidad-Relación)

El modelo conceptual representa la **lógica del negocio**, no la implementación. Aquí sí usamos el pensamiento relacional tradicional para entender qué existe en el dominio.

### Entidades del sistema de cine

```
+----------------+        +------------------+        +-----------------+
|    USUARIO     |        |     BOLETO       |        |    FUNCION      |
+----------------+        +------------------+        +-----------------+
| usuario_id  PK |------->| boleto_id     PK |<-------| funcion_id   PK |
| nombre         |  1:N   | usuario_id    FK |  N:1   | pelicula_id  FK |
| email          |        | funcion_id    FK |        | sala_id      FK |
| telefono       |        | asiento          |        | fecha            |
| documento      |        | precio           |        | hora_inicio      |
|                |        | estado           |        | hora_fin         |
+----------------+        | fecha_compra     |        +-----------------+
                           +------------------+               |
                                                              | N:1
                                                    +-----------------+
                                                    |     SALA        |
                                                    +-----------------+
                                              +---->| sala_id      PK |
                                              |     | nombre          |
                                    +---------+     | capacidad       |
                                    |               | tipo            |
                           +-----------------+      | ubicacion       |
                           |   PELICULA      |      +-----------------+
                           +-----------------+
                           | pelicula_id  PK |
                           | titulo          |
                           | genero          |
                           | duracion_min    |
                           | clasificacion   |
                           +-----------------+
```

### Relaciones clave identificadas

| Relación | Cardinalidad | Notas |
|---|---|---|
| Usuario → Boleto | 1:N | Un usuario puede comprar muchos boletos |
| Boleto → Función | N:1 | Muchos boletos corresponden a una función |
| Función → Sala | N:1 | Una sala puede tener muchas funciones |
| Función → Película | N:1 | Una película puede tener muchas funciones |

### Restricciones de negocio importantes
- Un asiento en una función solo puede venderse **una vez**
- Un boleto puede estar en estado: `ACTIVO`, `CANCELADO`, `USADO`
- No se permiten cancelaciones el mismo día de la función

---

## Fase 2 — Identificar las Queries del Negocio

> **Este paso es el más importante en Cassandra.** Antes de escribir un solo `CREATE TABLE`, listen todas las preguntas que el sistema debe responder.

### Queries requeridas 

| # | Query del negocio | Filtros | Ordenamiento |
|---|---|---|---|
| Q1 | Ver todos los boletos de un usuario | `usuario_id` | `fecha_compra DESC` |
| Q2 | Ver disponibilidad de una sala en una fecha | `sala_id`, `fecha` | `hora_inicio ASC` |
| Q3 | Ver todas las funciones de una película | `pelicula_id` | `fecha ASC` |
| Q4 | Buscar boleto por ID para validar en entrada | `boleto_id` | — |
| Q5 | Ver ocupación de todas las salas en un rango de fechas | `fecha` | `sala_id`, `hora_inicio` |

> **Nota:** Cada query de esta tabla generará (al menos) una tabla en Cassandra.

---

## Fase 3 — Modelo Lógico para Cassandra (Query-Driven)

Para cada query, se diseña una tabla siguiendo este proceso:

```
1. ¿Por qué campo filtra la query con = ?  → Partition Key
2. ¿Por qué campo filtra con rango < > o necesita ordenamiento? → Clustering Column
3. ¿Qué datos debo devolver? → Columnas adicionales (denormalizar si es necesario)
```

---

### Tabla 1: Boletos por usuario  
**Responde a:** Q1 — *"Ver todos los boletos de un usuario"*

```
QUERY: SELECT * FROM boletos WHERE usuario_id = ? ORDER BY fecha_compra DESC
```

**Decisión de diseño:**
- `usuario_id` → **Partition Key** (filtramos con `=`)
- `fecha_compra` → **Clustering Column DESC** (necesitamos orden descendente)
- `boleto_id` → **Clustering Column** (para unicidad del registro)
- Resto de columnas copiadas desde la lógica de negocio (denormalización)

```
boletos_por_usuario
┌─────────────────────────────────────────────────────────────────┐
│ PK: usuario_id     (Partition Key)                               │
│ CC: fecha_compra   (Clustering - DESC)                           │
│ CC: boleto_id      (Clustering - para unicidad)                  │
├──────────────────────────────────────────────────────────────────┤
│     nombre_usuario  |  titulo_pelicula  |  sala  |  asiento  ... │
└──────────────────────────────────────────────────────────────────┘
```

---

### Tabla 2: Funciones por sala y fecha  
**Responde a:** Q2 — *"Ver disponibilidad de una sala en una fecha"*

```
QUERY: SELECT * FROM funciones WHERE sala_id = ? AND fecha = ?
```

**Decisión de diseño:**
- `sala_id` + `fecha` → **Partition Key compuesta** (ambos se filtran con `=`)
- `hora_inicio` → **Clustering Column ASC** (ordenadas por hora)
- `funcion_id` → **Clustering Column** (para unicidad)

```
funciones_por_sala_fecha
┌─────────────────────────────────────────────────────────────────┐
│ PK: sala_id        (Partition Key)                               │
│ PK: fecha          (Partition Key)                               │
│ CC: hora_inicio    (Clustering - ASC)                            │
│ CC: funcion_id     (Clustering - para unicidad)                  │
├──────────────────────────────────────────────────────────────────┤
│     titulo_pelicula  |  hora_fin  |  asientos_disponibles  ...   │
└──────────────────────────────────────────────────────────────────┘
```

> **¿Por qué sala_id y fecha son ambas Partition Key?** Porque siempre filtramos por los dos juntos. Si solo fuera sala_id, una sala con muchas funciones acumularía demasiados datos en una sola partición (hot partition).

---

### Tabla 3: Boleto por ID  
**Responde a:** Q4 — *"Buscar boleto por ID"*

```
QUERY: SELECT * FROM boletos WHERE boleto_id = ?
```

**Decisión de diseño:**
- `boleto_id` → **Partition Key** (lookup directo por ID único)

```
boletos_por_id
┌─────────────────────────────────────────────────────────────────┐
│ PK: boleto_id      (Partition Key)                               │
├──────────────────────────────────────────────────────────────────┤
│  usuario_id  |  funcion_id  |  asiento  |  estado  |  precio  │
└──────────────────────────────────────────────────────────────────┘
```

---

### Resumen del Modelo Lógico

| Tabla Cassandra | Query que resuelve | Partition Key | Clustering Columns |
|---|---|---|---|
| `boletos_por_usuario` | Q1 | `usuario_id` | `fecha_compra DESC, boleto_id` |
| `funciones_por_sala_fecha` | Q2 | `(sala_id, fecha)` | `hora_inicio ASC, funcion_id` |
| `funciones_por_pelicula` | Q3 | `pelicula_id` | `fecha ASC, funcion_id` |
| `boletos_por_id` | Q4 | `boleto_id` | — |
| `funciones_por_fecha` | Q5 | `fecha` | `sala_id ASC, hora_inicio ASC` |

> **Noten** que `titulo_pelicula`, `nombre_sala`, `nombre_usuario`, etc. se repiten en múltiples tablas. Esto es **intencional y correcto** en Cassandra — es denormalización controlada.

---

## Fase 4 — Modelo Físico (CQL)

### Crear el Keyspace

```cql
-- SimpleStrategy: para ambiente de desarrollo con un solo datacenter
-- Replication Factor 3: cada dato se replica en 3 nodos del clúster

CREATE KEYSPACE IF NOT EXISTS cine_reservas
WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 3
}
AND durable_writes = true;

USE cine_reservas;
```

> **Para producción con múltiples datacenters** se usaría `NetworkTopologyStrategy`:
> ```cql
> WITH replication = {'class': 'NetworkTopologyStrategy', 'datacenter1': 3}
> ```

---

### Crear las Tablas

```cql
-- =====================================================
-- TABLA: boletos_por_usuario
-- Query: SELECT * FROM boletos_por_usuario
--        WHERE usuario_id = ? ORDER BY fecha_compra DESC
-- =====================================================
CREATE TABLE IF NOT EXISTS boletos_por_usuario (
    usuario_id    UUID,
    fecha_compra  TIMESTAMP,
    boleto_id     UUID,
    -- columnas denormalizadas (duplicadas desde otras entidades)
    nombre_usuario       TEXT,
    titulo_pelicula      TEXT,
    nombre_sala          TEXT,
    fecha_funcion        DATE,
    hora_inicio          TIME,
    asiento              TEXT,
    precio               DECIMAL,
    estado               TEXT,
    PRIMARY KEY (usuario_id, fecha_compra, boleto_id)
) WITH CLUSTERING ORDER BY (fecha_compra DESC, boleto_id ASC);


-- =====================================================
-- TABLA: funciones_por_sala_fecha
-- Query: SELECT * FROM funciones_por_sala_fecha
--        WHERE sala_id = ? AND fecha = ?
-- =====================================================
CREATE TABLE IF NOT EXISTS funciones_por_sala_fecha (
    sala_id       UUID,
    fecha         DATE,
    hora_inicio   TIME,
    funcion_id    UUID,
    -- columnas denormalizadas
    titulo_pelicula      TEXT,
    hora_fin             TIME,
    clasificacion        TEXT,
    asientos_disponibles INT,
    PRIMARY KEY ((sala_id, fecha), hora_inicio, funcion_id)
) WITH CLUSTERING ORDER BY (hora_inicio ASC, funcion_id ASC);


-- =====================================================
-- TABLA: boletos_por_id
-- Query: SELECT * FROM boletos_por_id WHERE boleto_id = ?
-- =====================================================
CREATE TABLE IF NOT EXISTS boletos_por_id (
    boleto_id     UUID PRIMARY KEY,
    usuario_id    UUID,
    funcion_id    UUID,
    asiento       TEXT,
    estado        TEXT,
    precio        DECIMAL,
    fecha_compra  TIMESTAMP
);
```

---

### Insertar datos (con Batch Writes)

```cql
-- Un BATCH en Cassandra garantiza que todas las inserciones
-- a la MISMA partición se apliquen atómicamente.
-- IMPORTANTE: no usar BATCH con particiones diferentes (reduce rendimiento).

BEGIN BATCH
    INSERT INTO boletos_por_usuario (
        usuario_id, fecha_compra, boleto_id,
        nombre_usuario, titulo_pelicula, nombre_sala,
        fecha_funcion, hora_inicio, asiento, precio, estado
    ) VALUES (
        550e8400-e29b-41d4-a716-446655440000,
        '2026-03-01 14:30:00',
        6ba7b810-9dad-11d1-80b4-00c04fd430c8,
        'Ana García', 'Dune: Parte Dos', 'Sala VIP 1',
        '2026-03-05', '20:00:00', 'F-12', 85.00, 'ACTIVO'
    );

    INSERT INTO boletos_por_id (
        boleto_id, usuario_id, funcion_id,
        asiento, estado, precio, fecha_compra
    ) VALUES (
        6ba7b810-9dad-11d1-80b4-00c04fd430c8,
        550e8400-e29b-41d4-a716-446655440000,
        7c9e6679-7425-40de-944b-e07fc1f90ae7,
        'F-12', 'ACTIVO', 85.00, '2026-03-01 14:30:00'
    );
APPLY BATCH;
```

> **Nota:** Al insertar un boleto, se debe escribir en **todas las tablas relevantes** para mantener la consistencia. Esto se hace desde la capa de aplicación (Python) o con múltiples BATCHes.

---




## Fase 5 — Configuración del Clúster (Docker)

El `docker-compose.yml` del proyecto aca defines los nodos que vas a necesitar.

```yaml

version: '3.8'

services:

  cassandra-node1:
    image: cassandra:4.1
    container_name: cassandra-node1
    ports:
      - "9042:9042"       # Puerto principal para conectar scripts Python
    environment:
      - CASSANDRA_CLUSTER_NAME=CoworkingCluster
      - CASSANDRA_DC=datacenter1
      - CASSANDRA_RACK=rack1
      - CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch
      - CASSANDRA_SEEDS=cassandra-node1
      - MAX_HEAP_SIZE=512M
      - HEAP_NEWSIZE=100M
    healthcheck:
      test: ["CMD", "cqlsh", "-e", "describe keyspaces"]
      interval: 30s
      timeout: 15s
      retries: 10
      start_period: 60s
    volumes:
      - cassandra-data1:/var/lib/cassandra
    networks:
      - cassandra-net

  cassandra-node2:
    image: cassandra:4.1
    container_name: cassandra-node2
    ports:
      - "9043:9042"       # Puerto alternativo para conectar desde el host
    environment:
      - CASSANDRA_CLUSTER_NAME=CoworkingCluster
      - CASSANDRA_DC=datacenter1
      - CASSANDRA_RACK=rack1
      - CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch
      - CASSANDRA_SEEDS=cassandra-node1
      - MAX_HEAP_SIZE=512M
      - HEAP_NEWSIZE=100M
    depends_on:
      cassandra-node1:
        condition: service_healthy   # Espera que node1 esté completamente listo
    healthcheck:
      test: ["CMD", "cqlsh", "-e", "describe keyspaces"]
      interval: 30s
      timeout: 15s
      retries: 10
      start_period: 60s
    volumes:
      - cassandra-data2:/var/lib/cassandra
    networks:
      - cassandra-net

  cassandra-node3:
    image: cassandra:4.1
    container_name: cassandra-node3
    ports:
      - "9044:9042"       # Puerto alternativo para conectar desde el host
    environment:
      - CASSANDRA_CLUSTER_NAME=CoworkingCluster
      - CASSANDRA_DC=datacenter1
      - CASSANDRA_RACK=rack1
      - CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch
      - CASSANDRA_SEEDS=cassandra-node1
      - MAX_HEAP_SIZE=512M
      - HEAP_NEWSIZE=100M
    depends_on:
      cassandra-node2:
        condition: service_healthy   # Espera que node2 esté listo
    healthcheck:
      test: ["CMD", "cqlsh", "-e", "describe keyspaces"]
      interval: 30s
      timeout: 15s
      retries: 10
      start_period: 60s
    volumes:
      - cassandra-data3:/var/lib/cassandra
    networks:
      - cassandra-net
# Volúmenes persistentes
volumes:
  cassandra-data1:
  cassandra-data2:
  cassandra-data3:

# Red interna dedicada para que los nodos se comuniquen entre sí
networks:
  cassandra-net:
    driver: bridge
```

### Verificar el estado del clúster

```bash
# Desde dentro del contenedor
docker exec -it cassandra-node1 nodetool status
```

Salida esperada (todos los nodos en estado `UN` = Up/Normal):
```
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens  Owns    Host ID   Rack
UN  172.18.0.2  95.7 KiB   16      33.3%   abc...    rack1
UN  172.18.0.3  87.3 KiB   16      33.3%   def...    rack1
UN  172.18.0.4  91.2 KiB   16      33.3%   ghi...    rack1
```

---

## Fase 6 — Consistency Levels: Impacto en rendimiento

Con **Replication Factor = 3**, Cassandra tiene estas opciones:

| Consistency Level | Nodos que deben responder | Tolerancia a fallos | Latencia |
|---|---|---|---|
| `ONE` | 1 de 3 | Alta (hasta 2 nodos caídos) | Baja |
| `QUORUM` | 2 de 3 | Media (hasta 1 nodo caído) | Media |
| `ALL` | 3 de 3 | Ninguna (1 nodo caído = fallo) | Alta |

```cql
-- Cambiar el consistency level en cqlsh para pruebas
CONSISTENCY ONE;
SELECT * FROM boletos_por_usuario WHERE usuario_id = ?;

CONSISTENCY QUORUM;
SELECT * FROM boletos_por_usuario WHERE usuario_id = ?;

CONSISTENCY ALL;
SELECT * FROM boletos_por_usuario WHERE usuario_id = ?;
```

### Simular caída de un nodo

```bash
# Detener el nodo 3
docker stop cassandra-node3

# Verificar que el clúster lo detecta como Down
docker exec -it cassandra-node1 nodetool status
# El nodo3 aparecerá como DN (Down/Normal)

# Probar consultas con diferentes consistency levels
# ONE y QUORUM deben seguir funcionando
# ALL debe fallar

# Recuperar el nodo
docker start cassandra-node3
# Cassandra detecta el nodo y sincroniza datos automáticamente (hinted handoff)
```

---

## Errores comunes a evitar

###  ALLOW FILTERING
```cql
-- MAL: esto hace un full scan de la tabla
SELECT * FROM boletos WHERE estado = 'CANCELADO' ALLOW FILTERING;

-- BIEN: crear una tabla diseñada para esta query
-- boletos_por_estado: Partition Key = estado, CC = fecha_compra DESC
SELECT * FROM boletos_por_estado WHERE estado = 'CANCELADO';
```

###  Partition Key sin discriminación
```cql
-- MAL: si hay millones de funciones en una fecha popular, 
--      se crea una "hot partition" muy grande
CREATE TABLE funciones (
    fecha DATE,        -- ← sola como partition key es riesgoso
    funcion_id UUID,
    ...
    PRIMARY KEY (fecha, funcion_id)
);

-- MEJOR: agregar sala_id a la partition key para distribuir la carga
PRIMARY KEY ((sala_id, fecha), funcion_id)
```

###  JOINs implícitos con múltiples queries
```python
# MAL: hacer dos queries y unir en código (equivalente a un JOIN)
funcion = session.execute("SELECT * FROM funciones WHERE funcion_id = ?", [id])
sala    = session.execute("SELECT * FROM salas WHERE sala_id = ?", [funcion.sala_id])

# BIEN: la tabla ya tiene los datos denormalizados
resultado = session.execute("SELECT * FROM funciones_por_sala_fecha WHERE sala_id = ? AND fecha = ?", [sala_id, fecha])
# resultado ya incluye titulo_pelicula, nombre_sala, etc.
```

---


