# MongoDB — Ejemplos Clase 7

> **Escenario de ejemplo:** Tienda Online (`tienda`)  
> Colecciones: `clientes`, `productos`, `pedidos`, `categorias`

---

## 0. Levantar el entorno con Docker

 `docker compose up -d` enciende 
los contenedores sin bloquear la terminal, `ps` muestra si están corriendo 
y `exec` abre la consola de MongoDB dentro del contenedor usando el usuario administrador.

```bash
# Iniciar los contenedores (MongoDB + Mongo Express)
docker compose up -d

# Verificar que están corriendo
docker compose ps

# Acceder al shell de MongoDB
docker exec -it mongodb_clase8 mongosh -u admin -p admin123 --authenticationDatabase admin
```

**Mongo Express (GUI):** http://localhost:8081  
Usuario: `admin` · Contraseña: `admin123`

---

## 1. Introducción a MongoDB y su arquitectura

### Conceptos clave

| Relacional (MySQL)  | MongoDB             |
|---------------------|---------------------|
| Base de datos        | Base de datos        |
| Tabla               | Colección           |
| Fila / Registro     | Documento (BSON)    |
| Columna             | Campo               |
| JOIN                | $lookup / embed     |
| PRIMARY KEY         | `_id` (ObjectId)    |
| Índice              | Índice              |

### Explorar la arquitectura desde mongosh

Estos comandos sirven para explorar qué hay dentro del servidor cuando uno se conecta por primera vez: 
ver las bases de datos disponibles, elegir una, listar sus colecciones 
y revisar información básica del servidor.

```js
// Ver todas las bases de datos del servidor
show dbs

// Crear/seleccionar la base de datos 'tienda'
use tienda

// Ver colecciones existentes
show collections

// Muestra la versión de MongoDB que está corriendo en el servidor
db.serverStatus().version
// Muestra la cantidad de conexiones activas, disponibles y el total del servidor
db.serverStatus().connections
```

---

## 2. Instalación y configuración de MongoDB

### Comandos de administración básica

En lugar de usar siempre el usuario administrador, lo recomendable es crear un usuario propio para cada 
base de datos con solo los permisos que necesita. `createUser` crea ese usuario para `tienda`, 
y `stats()` junto con `getCmdLineOpts` muestran información sobre cómo está configurado 
y funcionando el servidor.

```js
// Selecciona la base de datos 'tienda' (la crea si todavía no existe)
use tienda

// Lista todos los usuarios registrados en la base de datos activa
db.getUsers()

// Crea el usuario 'tienda_user' con acceso de lectura/escritura solo en la db 'tienda'
db.createUser({
  user: "tienda_user",
  pwd:  "tienda123",
  roles: [{ role: "readWrite", db: "tienda" }]
})

// Muestra los parámetros con los que fue iniciado el servidor (modo standalone, replica set, etc.)
db.adminCommand({ getCmdLineOpts: 1 })

// Muestra el tamaño de la db, cantidad de colecciones, documentos e índices
db.stats()
```


## 4. CRUD y Consultas Avanzadas

### 4.1 CREATE — Insertar documentos

`insertOne` agrega un solo documento a la colección. Si no se indica un `_id`, MongoDB lo genera solo. 
`insertMany` permite insertar varios documentos a la vez en lugar de hacerlo uno por uno, 
lo que es más rápido cuando se tienen muchos datos para cargar.
Los `_id` de clientes y pedidos se definen manualmente para que las referencias entre colecciones funcionen.

```js
// Inserta un único producto con sus especificaciones técnicas; MongoDB genera el _id automáticamente
db.productos.insertOne({
  nombre: "Mouse Inalámbrico",
  precio: 45.00,
  stock: 300,
  categoria_id: ObjectId("aaa000000000000000000001"),
  especificaciones: { dpi: 1600, conexion: "USB-A", bateria: "AA" }
})

// Inserta cuatro productos a la vez; más eficiente que llamar insertOne repetidas veces
db.productos.insertMany([
  { nombre: "Teclado Mecánico",      precio: 120.00,  stock: 60,  categoria_id: ObjectId("aaa000000000000000000001") },
  { nombre: "Monitor 27\"",          precio: 380.00,  stock: 20,  categoria_id: ObjectId("aaa000000000000000000001") },
  { nombre: "Laptop Pro 15",         precio: 1099.00, stock: 15,  categoria_id: ObjectId("aaa000000000000000000001"), especificaciones: { ram: "8GB", almacenamiento: "512GB SSD" } },
  { nombre: "Auriculares Bluetooth", precio: 85.00,   stock: 120, categoria_id: ObjectId("aaa000000000000000000001"), especificaciones: { conexion: "Bluetooth 5.0", bateria: "20h" } }
])

// Inserta tres clientes con direccion embebida y etiquetas; los _id fijos permiten referenciarlos desde pedidos
db.clientes.insertMany([
  {
    _id: ObjectId("bbb000000000000000000001"),
    nombre: "Ana García",
    email: "ana@gmail.com",
    etiquetas: ["premium", "nuevo"],
    direccion: { ciudad: "Buenos Aires", calle: "Av. Corrientes 1234" }
  },
  {
    _id: ObjectId("bbb000000000000000000002"),
    nombre: "Carlos López",
    email: "carlos@gmail.com",
    etiquetas: ["premium"],
    direccion: { ciudad: "Córdoba", calle: "San Martín 456" }
  },
  {
    _id: ObjectId("bbb000000000000000000003"),
    nombre: "María Fernández",
    email: "maria@gmail.com",
    etiquetas: ["nuevo"],
    direccion: { ciudad: "Buenos Aires", calle: "Florida 789" }
  }
])

// Inserta cuatro pedidos con items embebidos y referencia al cliente que los realizó
db.pedidos.insertMany([
  {
    cliente_id: ObjectId("bbb000000000000000000001"),
    fecha: new Date("2025-01-15"),
    estado: "enviado",
    total: 1144.00,
    items: [
      { producto: "Laptop Pro 15",    cantidad: 1, precio_unitario: 1099.00 },
      { producto: "Mouse Inalámbrico", cantidad: 1, precio_unitario: 45.00 }
    ]
  },
  {
    cliente_id: ObjectId("bbb000000000000000000002"),
    fecha: new Date("2025-02-10"),
    estado: "pendiente",
    total: 290.00,
    items: [
      { producto: "Auriculares Bluetooth", cantidad: 2, precio_unitario: 85.00 },
      { producto: "Teclado Mecánico",      cantidad: 1, precio_unitario: 120.00 }
    ]
  },
  {
    cliente_id: ObjectId("bbb000000000000000000001"),
    fecha: new Date("2025-03-05"),
    estado: "en_proceso",
    total: 380.00,
    items: [
      { producto: "Monitor 27\"", cantidad: 1, precio_unitario: 380.00 }
    ]
  },
  {
    cliente_id: ObjectId("bbb000000000000000000003"),
    fecha: new Date("2025-03-08"),
    estado: "cancelado",
    total: 45.00,
    items: [
      { producto: "Mouse Inalámbrico", cantidad: 1, precio_unitario: 45.00 }
    ]
  }
])
```

### 4.2 READ — Consultas básicas

`find()` trae todos los documentos de la colección. 
Se puede combinar con opciones para mostrar solo algunos campos, ordenar los resultados, 
limitar cuántos se muestran (útil para páginas) y contar cuántos hay sin tener que traerlos todos.

```js
// Devuelve todos los documentos de la colección productos
db.productos.find()

// Devuelve todos los documentos con formato indentado (más legible en la terminal)
db.productos.find().pretty()

// Devuelve únicamente el producto cuyo nombre sea exactamente "Laptop Pro 15"
db.productos.find({ nombre: "Laptop Pro 15" })

// Devuelve nombre y precio de todos los productos, sin incluir el campo _id
db.productos.find({}, { nombre: 1, precio: 1, _id: 0 })

// Devuelve todos los productos ordenados de mayor a menor precio
db.productos.find().sort({ precio: -1 })

// Devuelve los 3 productos más caros (primera página, sin saltear resultados)
db.productos.find().sort({ precio: -1 }).skip(0).limit(3)

// Cuenta cuántos productos tienen más de 50 unidades en stock
db.productos.countDocuments({ stock: { $gt: 50 } })
```

### 4.3 READ — Operadores de comparación

Sirven para filtrar documentos según el valor de sus campos. `$gte`/`$lte` buscan dentro de un rango de números, 
`$in` comprueba si el valor está dentro de una lista, `$exists` encuentra documentos que tengan (o no) un campo determinado,
y `$type` filtra según el tipo de dato guardado.

```js
// Devuelve productos con precio entre 100 y 500 (ambos extremos inclusive)
db.productos.find({ precio: { $gte: 100, $lte: 500 } })

// Devuelve clientes que tienen la etiqueta "premium" dentro de su array de etiquetas
db.clientes.find({ "etiquetas": { $in: ["premium"] } })

// Devuelve productos que tienen el campo especificaciones definido, sin importar su valor
db.productos.find({ especificaciones: { $exists: true } })

// Devuelve pedidos cuyo campo total está almacenado como número entero
db.pedidos.find({ total: { $type: "int" } })
```

### 4.4 READ — Operadores lógicos

Permiten combinar varias condiciones a la vez. Si se escriben varios campos juntos, 
MongoDB ya asume que deben cumplirse todos (como un `$and` automático). 
`$or` encuentra documentos que cumplan al menos una de las condiciones, `$not` busca los que no cumplen algo 
y `$nor` busca los que no cumplen ninguna.

```js
// Devuelve productos con precio menor a 200 Y stock mayor a 50 (ambas condiciones obligatorias)
db.productos.find({ precio: { $lt: 200 }, stock: { $gt: 50 } })

// Devuelve pedidos que están en estado "pendiente" O en estado "en_proceso"
db.pedidos.find({ $or: [ { estado: "pendiente" }, { estado: "en_proceso" } ] })

// Devuelve clientes que NO tienen la etiqueta "nuevo" en su array
db.clientes.find({ "etiquetas": { $not: { $in: ["nuevo"] } } })

// Devuelve productos que NO son baratos (precio < 50) NI tienen poco stock (stock < 10)
db.productos.find({ $nor: [ { precio: { $lt: 50 } }, { stock: { $lt: 10 } } ] })
```

### 4.5 READ — Consultas sobre subdocumentos y arrays

Para acceder a campos dentro de un subdocumento se usa el punto (`"campo.subcampo"`), como si fuera una ruta. 
Con arrays de objetos, `$elemMatch` es importante porque asegura que todas las condiciones se cumplan en el
mismo elemento del array. Sin él, MongoDB podría devolver resultados incorrectos si cada condición 
la cumple un elemento distinto.

```js
// Devuelve clientes cuyo campo ciudad dentro del subdocumento direccion sea "Buenos Aires"
db.clientes.find({ "direccion.ciudad": "Buenos Aires" })

// Devuelve pedidos que tienen "Laptop Pro 15" en el campo producto de alguno de sus ítems
db.pedidos.find({ "items.producto": "Laptop Pro 15" })

// Devuelve pedidos con al menos un ítem de "Laptop Pro 15" con cantidad >= 2 (ambas condiciones en el mismo elemento del array)
db.pedidos.find({
  items: { $elemMatch: { producto: "Laptop Pro 15", cantidad: { $gte: 2 } } }
})

// Devuelve pedidos que tienen exactamente 1 ítem en su array items
db.pedidos.find({ items: { $size: 1 } })
```

### 4.6 UPDATE — Actualizar documentos

MongoDB tiene varios operadores para actualizar documentos de forma segura:
`$set` cambia o agrega un campo sin tocar los demás, `$inc` suma (o resta) un número a un campo, 
`$push` agrega un elemento a un array, `$unset` borra un campo,
`$mul` multiplica el valor de un campo por un número. 
La opción `upsert: true` es práctica: si el documento existe lo actualiza, y si no existe lo crea.

```js
// Cambia el precio de "Laptop Pro 15" a 1150 y actualiza la RAM a "16GB" sin tocar los demás campos
db.productos.updateOne(
  { nombre: "Laptop Pro 15" },
  { $set: { precio: 1150.00, "especificaciones.ram": "16GB" } }
)

// Suma 50 unidades al stock actual de "Auriculares Bluetooth" (si tenía 120, queda en 170)
db.productos.updateOne(
  { nombre: "Auriculares Bluetooth" },
  { $inc: { stock: 50 } }
)

// Agrega la etiqueta "vip" al final del array etiquetas del cliente con ese email
db.clientes.updateOne(
  { email: "ana@gmail.com" },
  { $push: { etiquetas: "vip" } }
)

// Elimina completamente el campo especificaciones del documento "Mouse Inalámbrico"
db.productos.updateOne(
  { nombre: "Mouse Inalámbrico" },
  { $unset: { especificaciones: "" } }
)

// Sube el precio de todos los productos de esa categoría en un 10% (multiplica cada precio por 1.1)
db.productos.updateMany(
  { categoria_id: ObjectId("aaa000000000000000000001") },
  { $mul: { precio: 1.1 } }
)

// Si "Smartwatch X" existe lo actualiza con esos valores; si no existe, lo crea como documento nuevo
db.productos.updateOne(
  { nombre: "Smartwatch X" },
  { $set: { precio: 250.00, stock: 40 } },
  { upsert: true }
)
```

### 4.7 DELETE — Eliminar documentos

`deleteOne` borra solo el primer documento que coincida con el filtro. 
`deleteMany` borra todos los que coincidan. Si se quiere dejar la colección vacía pero mantenerla, 
se usa `deleteMany({})`. Si se quiere borrar la colección entera (incluyendo todos sus índices), se usa `drop()`.

```js
// Elimina el primer documento cuyo nombre sea "Smartwatch X"
db.productos.deleteOne({ nombre: "Smartwatch X" })

// Elimina todos los productos que tienen stock igual a 0
db.productos.deleteMany({ stock: 0 })

// Vaciar colección (conserva la colección e índices)
// db.productos.deleteMany({})

// Eliminar colección entera (borra también todos sus índices)
// db.productos.drop()
```

---

## 5. Índices y optimización de consultas

### 5.1 Tipos de índices

Sin un índice, MongoDB tiene que revisar todos los documentos uno por uno para encontrar los que coinciden. 
Con un índice, va directo al dato. Existen varios tipos: 
**simple** (sobre un campo), 
**compuesto** (sobre varios campos juntos), 
**único** (evita valores repetidos, útil para emails), 
**de texto** (para búsquedas por palabras), 
**TTL** (borra documentos automáticamente después de un tiempo, útil para sesiones), 
**geoespacial** (para coordenadas y mapas) 
y **parcial** (solo indexa los documentos que cumplan una condición).

```js
// Crea un índice sobre precio (ascendente) para acelerar filtros y ordenamientos por ese campo
db.productos.createIndex({ precio: 1 })          // 1 = ascendente, -1 = descendente

// Crea un índice compuesto: agrupa por categoría y dentro de ella ordena por precio descendente
db.productos.createIndex({ categoria_id: 1, precio: -1 })

// Crea un índice único sobre email: impide insertar dos clientes con el mismo correo electrónico
db.clientes.createIndex({ email: 1 }, { unique: true })

// Crea un índice de texto sobre nombre para habilitar búsquedas por palabras clave
db.productos.createIndex({ nombre: "text" })

// Devuelve productos cuyo nombre contiene "laptop" o "auriculares" (busca cualquiera de las palabras)
db.productos.find({ $text: { $search: "laptop auriculares" } })
// Devuelve productos con "laptop" en el nombre, ordenados de mayor a menor relevancia
db.productos.find(
  { $text: { $search: "laptop" } },
  { score: { $meta: "textScore" } }
).sort({ score: { $meta: "textScore" } })

// Crea un índice TTL: elimina automáticamente las sesiones 1 hora (3600 s) después de su campo creado_en
db.sesiones.createIndex({ creado_en: 1 }, { expireAfterSeconds: 3600 })

// Crea un índice geoespacial 2dsphere para consultas de proximidad sobre el campo ubicacion
db.sucursales.createIndex({ ubicacion: "2dsphere" })

// Crea un índice parcial: solo indexa pedidos en estado "pendiente", reduciendo el tamaño del índice
db.pedidos.createIndex(
  { fecha: -1 },
  { partialFilterExpression: { estado: "pendiente" } }
)
```

### 5.2 Ver y eliminar índices

`getIndexes()` muestra todos los índices que tiene una colección. 
`$indexStats` indica cuántas veces se usó cada índice, lo que ayuda a identificar los que nadie usa y que solo ocupan espacio.
Con `dropIndex` se borra uno en particular y con `dropIndexes` se borran todos (excepto el de `_id`, que no se puede eliminar).


```js
// Lista todos los índices de la colección productos con su nombre, campos y opciones
db.productos.getIndexes()

// Muestra cuántas veces fue usado cada índice desde el último reinicio del servidor
db.productos.aggregate([{ $indexStats: {} }])

// Elimina el índice llamado "precio_1" (el nombre exacto se obtiene con getIndexes())
db.productos.dropIndex("precio_1")

// Elimina todos los índices de la colección excepto el de _id (que es obligatorio y no se puede borrar)
db.productos.dropIndexes()
```

### 5.3 Analizar consultas con explain()

`explain("executionStats")` muestra cómo MongoDB ejecutó una consulta por dentro. 
El campo `stage` dice si usó un índice (`IXSCAN`, rápido) o si tuvo que revisar todos los documentos (`COLLSCAN`, lento). 
Un buen indicador es comparar `totalDocsExamined` (cuántos revisó) 
con `nReturned` (cuántos devolvió): si el primero es mucho mayor que el segundo, la consulta no está usando un índice adecuado.

```js
// Ejecuta la consulta y muestra estadísticas; sin índice usa COLLSCAN (recorre toda la colección)
db.productos.find({ precio: { $gt: 100 } }).explain("executionStats")

// Crea el índice sobre precio para que la siguiente consulta pueda usar IXSCAN
db.productos.createIndex({ precio: 1 })
// Misma consulta pero ahora usa IXSCAN (índice directo); comparar totalDocsExamined con la anterior
db.productos.find({ precio: { $gt: 100 } }).explain("executionStats")

// Campos clave a observar en explain():
//   stage: "COLLSCAN" vs "IXSCAN"
//   nReturned: documentos devueltos
//   totalDocsExamined: documentos revisados (menor = mejor)
//   executionTimeMillis: tiempo de ejecución
```

---

## 6. Aggregation Framework y MapReduce

### 6.1 Pipeline de agregación

El Aggregation Framework procesa documentos en **etapas** (`$match`, `$group`, `$sort`, `$project`, etc.).

**Ejemplo 1 — Total de ventas por estado de pedido:** Junta todos los pedidos según su estado (pendiente, enviado, etc.) 
y calcula cuánto dinero suma cada grupo y cuántos pedidos tiene. Al final los ordena de mayor a menor.

```js
// --- Ejemplo 1: Total de ventas por estado de pedido ---
db.pedidos.aggregate([
  {
    $group: {
      _id: "$estado",
      total_ventas: { $sum: "$total" },
      cantidad_pedidos: { $count: {} }
    }
  },
  { $sort: { total_ventas: -1 } }
])
```

**Ejemplo 2 — Top 3 productos más vendidos:** Como cada pedido tiene varios productos en un array, 
primero se separa ese array en filas individuales con `$unwind`. 
Luego se agrupan por producto para sumar cuántas unidades se vendieron y cuánto dinero generaron,
se ordenan y se toman solo los 3 primeros.

```js
// --- Ejemplo 2: Top 3 productos más vendidos ---
db.pedidos.aggregate([
  { $unwind: "$items" },                    // descomponer array
  {
    $group: {
      _id: "$items.producto",
      unidades_vendidas: { $sum: "$items.cantidad" },
      ingresos: { $sum: { $multiply: ["$items.precio_unitario", "$items.cantidad"] } }
    }
  },
  { $sort: { unidades_vendidas: -1 } },
  { $limit: 3 },
  {
    $project: {
      _id: 0,
      producto: "$_id",
      unidades_vendidas: 1,
      ingresos: { $round: ["$ingresos", 2] }
    }
  }
])
```

**Ejemplo 3 — `$lookup`: combinar pedidos con clientes:** `$lookup` une cada pedido con los datos del cliente que lo hizo 
(igual que un `JOIN` en SQL). El resultado de `$lookup` es un array, así que `$unwind` lo convierte en un campo normal. 
Después, `$project` elige qué campos mostrar en el resultado final.

```js
// --- Ejemplo 3: $lookup — JOIN entre pedidos y clientes ---
db.pedidos.aggregate([
  {
    $lookup: {
      from: "clientes",         // colección destino
      localField: "cliente_id", // campo en pedidos
      foreignField: "_id",      // campo en clientes
      as: "cliente"             // nombre del array resultante
    }
  },
  { $unwind: "$cliente" },
  {
    $project: {
      _id: 0,
      "cliente.nombre": 1,
      "cliente.email": 1,
      fecha: 1,
      estado: 1,
      total: 1
    }
  },
  { $sort: { fecha: -1 } }
])
```

**Ejemplo 4 — Facturación mensual:** Primero descarta los pedidos cancelados.
Luego agrupa los demás por mes y año (extrayendo esos valores de la fecha) para ver cuánto dinero entró 
y cuántos pedidos hubo en cada mes. Genera un campo `periodo` con el formato `"2025-3"` para que sea fácil de leer.

```js
// --- Ejemplo 4: Facturación mensual ---
db.pedidos.aggregate([
  { $match: { estado: { $ne: "cancelado" } } },
  {
    $group: {
      _id: {
        anio: { $year: "$fecha" },
        mes:  { $month: "$fecha" }
      },
      ingresos_mes: { $sum: "$total" },
      pedidos_mes:  { $count: {} }
    }
  },
  { $sort: { "_id.anio": 1, "_id.mes": 1 } },
  {
    $project: {
      _id: 0,
      periodo: {
        $concat: [
          { $toString: "$_id.anio" }, "-",
          { $toString: "$_id.mes" }
        ]
      },
      ingresos_mes: { $round: ["$ingresos_mes", 2] },
      pedidos_mes: 1
    }
  }
])
```

**Ejemplo 5 — `$bucket` por rango de precio:** Clasifica los productos en grupos según su precio: económicos (0–50),
intermedios (50–150), etc. Si algún producto tiene un precio fuera de los rangos definidos va al grupo `"Otros"`.
El resultado muestra cuántos productos hay en cada rango y sus nombres.

```js
// --- Ejemplo 5: $bucket — agrupar productos por rango de precio ---
db.productos.aggregate([
  {
    $bucket: {
      groupBy: "$precio",
      boundaries: [0, 50, 150, 500, 2000],
      default: "Otros",
      output: {
        cantidad: { $count: {} },
        productos: { $push: "$nombre" }
      }
    }
  }
])
```

**Ejemplo 6 — Gasto total de clientes premium:** Une los pedidos con los datos de cada cliente,
luego filtra solo los clientes que tienen la etiqueta `"premium"`. Por cada uno de ellos calcula cuánto dinero gastó en total 
y cuántos pedidos hizo. Muestra el resultado ordenado del cliente que más gastó al que menos.

```js
// --- Ejemplo 6: Clientes con etiqueta premium y su gasto total ---
db.pedidos.aggregate([
  {
    $lookup: {
      from: "clientes",
      localField: "cliente_id",
      foreignField: "_id",
      as: "cliente"
    }
  },
  { $unwind: "$cliente" },
  { $match: { "cliente.etiquetas": "premium" } },
  {
    $group: {
      _id: "$cliente.email",
      nombre: { $first: "$cliente.nombre" },
      gasto_total: { $sum: "$total" },
      cantidad_pedidos: { $count: {} }
    }
  },
  { $sort: { gasto_total: -1 } }
])
```


---

## 7. MySQL vs MongoDB — Comparación práctica

### 7.1 DDL vs Schema flexible

En MySQL hay que crear la tabla y definir todas sus columnas antes de poder guardar datos. En MongoDB no: la colección se crea sola cuando se inserta el primer documento. Además, cada documento puede tener campos diferentes sin necesidad de modificar ninguna estructura previa.

```sql
-- MySQL: esquema rígido, definido antes de insertar
CREATE TABLE productos (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(200) NOT NULL,
  precio      DECIMAL(10,2) NOT NULL,
  stock       INT DEFAULT 0,
  categoria_id INT,
  FOREIGN KEY (categoria_id) REFERENCES categorias(id)
);
```

```js
// MongoDB: sin DDL — la colección se crea al primer insert
// Se pueden insertar documentos con distinta estructura en la misma colección
db.productos.insertOne({ nombre: "Tablet", precio: 300 })          // válido
db.productos.insertOne({ nombre: "Funda", precio: 15, color: "negro", talla: "M" }) // también válido
```

### 7.2 JOIN vs $lookup

En MySQL los datos relacionados se guardan en tablas separadas y se combinan con `JOIN` al consultar. En MongoDB lo más común es guardar los datos juntos dentro del mismo documento. Cuando igual se necesita relacionar dos colecciones separadas, se usa `$lookup`, que funciona de forma similar al `JOIN` de SQL.

```sql
-- MySQL: JOIN
SELECT c.nombre, p.fecha, p.total
FROM pedidos p
JOIN clientes c ON p.cliente_id = c.id
ORDER BY p.fecha DESC;
```

```js
// MongoDB: $lookup
db.pedidos.aggregate([
  { $lookup: { from: "clientes", localField: "cliente_id", foreignField: "_id", as: "cliente" } },
  { $unwind: "$cliente" },
  { $project: { "cliente.nombre": 1, fecha: 1, total: 1 } },
  { $sort: { fecha: -1 } }
])
```

### 7.3 Consulta anidada (subdocumentos)

En MySQL las direcciones se guardan en una tabla aparte y hay que hacer un `JOIN` para traerlas junto con el cliente. En MongoDB la dirección es parte del mismo documento del cliente, así que se accede a ella directamente usando el punto, sin necesidad de combinar tablas.

```sql
-- MySQL: tabla extra para direcciones
SELECT cl.nombre, d.ciudad
FROM clientes cl
JOIN direcciones d ON d.cliente_id = cl.id
WHERE d.ciudad = 'Buenos Aires';
```

```js
// MongoDB: acceso directo con dot notation
db.clientes.find(
  { "direccion.ciudad": "Buenos Aires" },
  { nombre: 1, "direccion.ciudad": 1, _id: 0 }
)
```

### 7.4 Agregación

La misma consulta que en MySQL se escribe en una sola línea con `GROUP BY`, en MongoDB se escribe como una lista de pasos con `$group`. El resultado es idéntico, pero MongoDB es más extenso para escribir. La ventaja es que permite agregar más pasos antes o después con facilidad.

```sql
-- MySQL: ventas por estado
SELECT estado, SUM(total) AS total_ventas, COUNT(*) AS cantidad
FROM pedidos
GROUP BY estado
ORDER BY total_ventas DESC;
```

```js
// MongoDB: pipeline equivalente
db.pedidos.aggregate([
  { $group: { _id: "$estado", total_ventas: { $sum: "$total" }, cantidad: { $count: {} } } },
  { $sort: { total_ventas: -1 } }
])
```

### 7.5 Tabla comparativa resumen

| Característica         | MySQL                        | MongoDB                          |
|------------------------|------------------------------|----------------------------------|
| Modelo de datos        | Tablas/columnas (relacional) | Documentos BSON (NoSQL)          |
| Esquema                | Rígido (DDL)                 | Flexible (schema-less)           |
| Escalabilidad          | Vertical (scale-up)          | Horizontal (sharding)            |
| Transacciones ACID     | Sí, nativas                  | Sí (desde v4.0, multi-doc)       |
| Joins / relaciones     | JOIN nativo                  | $lookup + embedding              |
| Consultas complejas    | SQL estándar                 | Aggregation Pipeline             |
| Datos jerárquicos      | Requiere múltiples tablas    | Documento embebido nativo        |
| Full-text search       | Índice FULLTEXT              | Índice $text / Atlas Search      |
| Ideal para             | Datos estructurados, ERP     | JSON, logs, catálogos, real-time |

---


