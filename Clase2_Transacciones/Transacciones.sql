-- ============================================
-- EJEMPLO 1: INTRODUCCIÓN A TRANSACCIONES
-- Explicación: Configura la base de datos inicial con tablas de cuentas bancarias
-- para demostrar conceptos básicos de transacciones ACID
-- ============================================

-- Crear una base de datos de ejemplo
DROP DATABASE IF EXISTS banco_ejemplo;
CREATE DATABASE banco_ejemplo;
USE banco_ejemplo;

-- Tabla de cuentas bancarias
CREATE TABLE cuentas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    titular VARCHAR(100),
    saldo DECIMAL(10, 2)
);

-- Insertar datos iniciales
INSERT INTO cuentas (titular, saldo) VALUES 
('Juan Pérez', 1000.00),
('María García', 1500.00),
('Carlos López', 500.00);



-- ============================================
-- EJEMPLO 1.1: Transacción exitosa (COMMIT)
-- Explicación: Demuestra una transferencia bancaria exitosa entre dos cuentas
-- confirmando los cambios permanentemente con COMMIT
-- ============================================

-- Inicia una nueva transacción - todas las operaciones siguientes serán parte de ella
START TRANSACTION;

-- Resta 200 del saldo de Juan (operación 1 de la transferencia)
UPDATE cuentas SET saldo = saldo - 200 WHERE titular = 'Juan Pérez';
-- Suma 200 al saldo de María (operación 2 de la transferencia)
UPDATE cuentas SET saldo = saldo + 200 WHERE titular = 'María García';

-- Ver cambios temporales 
SELECT * FROM cuentas;

-- COMMIT: Confirma y guarda permanentemente todos los cambios realizados en la transacción
COMMIT;

-- Ver resultado final
SELECT * FROM cuentas;


-- ============================================
-- EJEMPLO 1.2: Transacción cancelada (ROLLBACK)
-- Explicación: Muestra cómo cancelar una transacción con ROLLBACK
-- para revertir todos los cambios realizados
-- ============================================
START TRANSACTION;

UPDATE cuentas SET saldo = saldo - 300 WHERE titular = 'María García';
UPDATE cuentas SET saldo = saldo + 300 WHERE titular = 'Carlos López';

-- Ver cambios temporales
SELECT * FROM cuentas;

-- ROLLBACK: Cancela la transacción y revierte TODOS los cambios - ningún cambio se aplica
ROLLBACK;

-- Ver que no hubo cambios
SELECT * FROM cuentas;


-- ============================================
-- EJEMPLO 1.3: Error en transacción
-- Explicación: Simula un error durante una transferencia intentando enviar dinero
-- a una cuenta inexistente, aplicando ROLLBACK para mantener la integridad
-- ============================================

START TRANSACTION;

UPDATE cuentas SET saldo = saldo - 500 WHERE titular = 'Carlos López';
-- Esta operación causaría saldo negativo, pero simularemos un error
UPDATE cuentas SET saldo = saldo + 500 WHERE titular = 'Cuenta Inexistente';

-- Si hay error, hacer rollback
ROLLBACK;

SELECT * FROM cuentas;

-- ============================================
-- EJEMPLO 1.4: Transaccion en procedimientos almacenados
-- Explicación: Crea un procedimiento almacenado que encapsula una transferencia
-- bancaria simple con transacción automática (sin validaciones)
-- ============================================

-- Crear un procedimiento que realice una transferencia
DROP PROCEDURE IF EXISTS transferir;

CREATE PROCEDURE transferir(
    IN origen VARCHAR(100),
    IN destino VARCHAR(100),
    IN cantidad DECIMAL(10, 2)
)
BEGIN
    -- Iniciar transacción dentro del procedimiento
    START TRANSACTION;
    
    -- Restar del origen
    UPDATE cuentas SET saldo = saldo - cantidad WHERE titular = origen;
    
    -- Sumar al destino
    UPDATE cuentas SET saldo = saldo + cantidad WHERE titular = destino;
    
    -- Confirmar la transacción
    COMMIT;
END;

-- Ver saldos antes de la transferencia
SELECT * FROM cuentas;

-- Llamar al procedimiento para transferir 250 de Juan a Carlos
CALL transferir('Juan Pérez', 'Carlos López', 250.00);

-- Ver resultado después de la transferencia
SELECT * FROM cuentas;


-- ============================================
-- EJEMPLO 1.5: Procedimiento con validación de saldo
-- Explicación: Implementa una transferencia segura que valida el saldo disponible
-- antes de ejecutar, aplicando COMMIT solo si hay fondos suficientes
-- ============================================

-- Procedimiento que valida saldo antes de transferir
DROP PROCEDURE IF EXISTS transferir_segura;

CREATE PROCEDURE transferir_segura(
    IN origen VARCHAR(100),
    IN destino VARCHAR(100),
    IN cantidad DECIMAL(10, 2)
)
BEGIN
    -- DECLARE: Declara una variable local para almacenar el saldo temporalmente
    DECLARE saldo_actual DECIMAL(10, 2);
    
    START TRANSACTION;
    
    -- SELECT INTO: Obtiene el saldo de la cuenta origen y lo guarda en la variable
    SELECT saldo INTO saldo_actual FROM cuentas WHERE titular = origen;
    
    -- VALIDACIÓN CRÍTICA: Verifica si hay saldo suficiente antes de hacer la transferencia
    IF saldo_actual >= cantidad THEN
        -- CASO EXITOSO: Hay saldo suficiente, realizar transferencia
        UPDATE cuentas SET saldo = saldo - cantidad WHERE titular = origen;
        UPDATE cuentas SET saldo = saldo + cantidad WHERE titular = destino;
        -- COMMIT: Confirma la transacción porque todo salió bien
        COMMIT;
        SELECT 'Transferencia exitosa' AS resultado;
    ELSE
        -- CASO FALLIDO: No hay saldo suficiente
        -- ROLLBACK: Cancela la transacción para evitar datos inconsistentes
        ROLLBACK;
        SELECT 'Saldo insuficiente' AS resultado;
    END IF;
END;

-- Probar con saldo suficiente
CALL transferir_segura('María García', 'Juan Pérez', 100.00);
SELECT * FROM cuentas;

-- Probar con saldo insuficiente
CALL transferir_segura('Carlos López', 'María García', 10000.00);
SELECT * FROM cuentas;


-- ============================================
-- EJEMPLO 1.6: Procedimiento para depósitos
-- Explicación: Permite agregar dinero a una cuenta validando que el monto
-- sea positivo antes de confirmar el depósito
-- ============================================

DROP PROCEDURE IF EXISTS depositar;

CREATE PROCEDURE depositar(
    IN cuenta VARCHAR(100),
    IN monto DECIMAL(10, 2)
)
BEGIN
    START TRANSACTION;
    
    -- Validar que el monto sea positivo
    IF monto > 0 THEN
        UPDATE cuentas SET saldo = saldo + monto WHERE titular = cuenta;
        COMMIT;
        SELECT CONCAT('Depósito de $', monto, ' exitoso') AS resultado;
    ELSE
        ROLLBACK;
        SELECT 'El monto debe ser positivo' AS resultado;
    END IF;
END;

-- Probar depósito
CALL depositar('Juan Pérez', 500.00);
SELECT * FROM cuentas;

CALL depositar('María García', -100.00);


-- ============================================
-- EJEMPLO 1.7: Procedimiento para retiros
-- Explicación: Realiza retiros de dinero validando que el monto sea positivo
-- y que la cuenta tenga saldo suficiente
-- ============================================

DROP PROCEDURE IF EXISTS retirar;

CREATE PROCEDURE retirar(
    IN cuenta VARCHAR(100),
    IN monto DECIMAL(10, 2)
)
BEGIN
    DECLARE saldo_actual DECIMAL(10, 2);
    
    START TRANSACTION;
    
    SELECT saldo INTO saldo_actual FROM cuentas WHERE titular = cuenta;
    
    IF monto <= 0 THEN
        ROLLBACK;
        SELECT 'El monto debe ser positivo' AS resultado;
    ELSEIF saldo_actual >= monto THEN
        UPDATE cuentas SET saldo = saldo - monto WHERE titular = cuenta;
        COMMIT;
        SELECT CONCAT('Retiro de $', monto, ' exitoso') AS resultado;
    ELSE
        ROLLBACK;
        SELECT CONCAT('Saldo insuficiente. Saldo actual: $', saldo_actual) AS resultado;
    END IF;
END;

-- Probar retiros
CALL retirar('Carlos López', 200.00);
SELECT * FROM cuentas;

CALL retirar('Juan Pérez', 50000.00);


-- ============================================
-- EJEMPLO 1.8: Procedimiento con registro de movimientos
-- Explicación: Transferencia bancaria con auditoría completa, registrando cada
-- operación en una tabla de movimientos para seguimiento histórico
-- ============================================

-- Crear tabla de movimientos
CREATE TABLE movimientos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    cuenta VARCHAR(100),
    tipo ENUM('DEPOSITO', 'RETIRO', 'TRANSFERENCIA_OUT', 'TRANSFERENCIA_IN'),
    monto DECIMAL(10, 2),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP PROCEDURE IF EXISTS transferir_con_historial;

CREATE PROCEDURE transferir_con_historial(
    IN origen VARCHAR(100),
    IN destino VARCHAR(100),
    IN cantidad DECIMAL(10, 2)
)
BEGIN
    DECLARE saldo_origen DECIMAL(10, 2);
    
    START TRANSACTION;
    
    SELECT saldo INTO saldo_origen FROM cuentas WHERE titular = origen;
    
    IF saldo_origen >= cantidad THEN
        -- Realizar transferencia
        UPDATE cuentas SET saldo = saldo - cantidad WHERE titular = origen;
        UPDATE cuentas SET saldo = saldo + cantidad WHERE titular = destino;
        
        -- AUDITORÍA: Registra la salida de dinero en la tabla de movimientos
        INSERT INTO movimientos (cuenta, tipo, monto) 
        VALUES (origen, 'TRANSFERENCIA_OUT', cantidad);
        
        -- AUDITORÍA: Registra la entrada de dinero en la tabla de movimientos
        INSERT INTO movimientos (cuenta, tipo, monto) 
        VALUES (destino, 'TRANSFERENCIA_IN', cantidad);
        
        COMMIT;
        SELECT 'Transferencia registrada exitosamente' AS resultado;
    ELSE
        ROLLBACK;
        SELECT 'Saldo insuficiente' AS resultado;
    END IF;
END;

-- Probar transferencia con historial
CALL transferir_con_historial('Juan Pérez', 'María García', 150.00);

-- Ver movimientos
SELECT * FROM movimientos;
SELECT * FROM cuentas;


-- ============================================
-- EJEMPLO 1.9: Procedimiento para múltiples operaciones
-- Explicación: Sistema de compra que coordina múltiples tablas (cuentas, productos, movimientos)
-- validando stock y saldo antes de completar la transacción
-- ============================================

-- Crear tabla de productos
CREATE TABLE productos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100),
    stock INT,
    precio DECIMAL(10, 2)
);

INSERT INTO productos (nombre, stock, precio) VALUES
('Laptop', 10, 1200.00),
('Mouse', 50, 25.00),
('Teclado', 30, 45.00);

DROP PROCEDURE IF EXISTS comprar_producto;

CREATE PROCEDURE comprar_producto(
    IN cliente VARCHAR(100),
    IN producto_id INT,
    IN cantidad INT
)
BEGIN
    DECLARE stock_actual INT;
    DECLARE precio_unitario DECIMAL(10, 2);
    DECLARE total DECIMAL(10, 2);
    DECLARE saldo_cliente DECIMAL(10, 2);
    
    START TRANSACTION;
    
    -- Obtener información del producto
    SELECT stock, precio INTO stock_actual, precio_unitario 
    FROM productos WHERE id = producto_id;
    
    -- Calcular total
    SET total = precio_unitario * cantidad;
    
    -- Obtener saldo del cliente
    SELECT saldo INTO saldo_cliente FROM cuentas WHERE titular = cliente;
    
    -- Validar stock y saldo
    IF stock_actual < cantidad THEN
        ROLLBACK;
        SELECT 'Stock insuficiente' AS resultado;
    ELSEIF saldo_cliente < total THEN
        ROLLBACK;
        SELECT 'Saldo insuficiente para la compra' AS resultado;
    ELSE
        -- Realizar compra
        UPDATE productos SET stock = stock - cantidad WHERE id = producto_id;
        UPDATE cuentas SET saldo = saldo - total WHERE titular = cliente;
        
        -- Registrar movimiento
        INSERT INTO movimientos (cuenta, tipo, monto) 
        VALUES (cliente, 'RETIRO', total);
        
        COMMIT;
        SELECT CONCAT('Compra exitosa. Total pagado: $', total) AS resultado;
    END IF;
END;

-- Probar compra de producto
CALL comprar_producto('Juan Pérez', 2, 3);
SELECT * FROM cuentas;
SELECT * FROM productos;
SELECT * FROM movimientos;


-- ============================================
-- EJERCICIO PRÁCTICO 1
-- Explicación: Ejercicio para practicar transacciones básicas realizando
-- una transferencia manual con validación y confirmación
-- ============================================
-- Realiza una transferencia de 150 de Juan a Carlos
-- 1. Inicia la transacción
-- 2. Resta 150 de Juan
-- 3. Suma 150 a Carlos
-- 4. Verifica los saldos
-- 5. Confirma o cancela según corresponda



-- ============================================
-- EJEMPLO 2: SAVEPOINTS 
-- Recuperación parcial de transacciones
-- Explicación: Introduce el concepto de puntos de guardado (savepoints) que permiten
-- deshacer solo parte de una transacción sin cancelarla completamente
-- ============================================

USE banco_ejemplo;

-- Verificar estado actual
SELECT * FROM cuentas;

-- ============================================
-- EJEMPLO 2.1: Savepoints básicos
-- Explicación: Demuestra cómo crear múltiples savepoints y revertir a puntos
-- específicos sin perder todos los cambios de la transacción
-- ============================================
START TRANSACTION;

-- Primer cambio
UPDATE cuentas SET saldo = saldo - 100 WHERE titular = 'Juan Pérez';
-- SAVEPOINT: Crea un punto de guardado llamado 'punto1' para poder volver aquí después
SAVEPOINT punto1;

-- Segundo cambio
UPDATE cuentas SET saldo = saldo - 100 WHERE titular = 'María García';
-- SAVEPOINT: Crea otro punto de guardado después del segundo cambio
SAVEPOINT punto2;

-- Tercer cambio
UPDATE cuentas SET saldo = saldo - 100 WHERE titular = 'Carlos López';
-- SAVEPOINT: Tercer punto de guardado con los tres cambios aplicados
SAVEPOINT punto3;

-- Ver cambios
SELECT * FROM cuentas;

-- ROLLBACK TO: Revierte la transacción hasta el savepoint 'punto2'
-- Esto DESHACE solo el tercer cambio (Carlos), pero mantiene los dos primeros
ROLLBACK TO punto2;

SELECT * FROM cuentas;

-- ROLLBACK TO: Ahora revierte hasta 'punto1'
-- Esto DESHACE el segundo y tercer cambio, manteniendo solo el primero (Juan)
ROLLBACK TO punto1;

SELECT * FROM cuentas;

-- Confirmar solo el primer cambio
COMMIT;

SELECT * FROM cuentas;


-- ============================================
-- EJEMPLO 2.2: Savepoints en procedimiento almacenado
-- Procesamiento por lotes con recuperación parcial
-- Explicación: Procesa múltiples pagos simultáneos usando savepoints para mantener
-- los pagos exitosos aunque alguno falle por saldo insuficiente
-- ============================================
-- Este ejemplo demuestra cómo procesar múltiples operaciones
-- donde algunas pueden fallar sin cancelar las exitosas

DROP PROCEDURE IF EXISTS procesar_pagos_multiples;

CREATE PROCEDURE procesar_pagos_multiples(
    IN cuenta1 VARCHAR(100),  -- Primera cuenta a procesar
    IN monto1 DECIMAL(10, 2), -- Monto a descontar de cuenta1
    IN cuenta2 VARCHAR(100),  -- Segunda cuenta a procesar
    IN monto2 DECIMAL(10, 2), -- Monto a descontar de cuenta2
    IN cuenta3 VARCHAR(100),  -- Tercera cuenta a procesar
    IN monto3 DECIMAL(10, 2)  -- Monto a descontar de cuenta3
)
BEGIN
    -- Variable temporal para verificar saldos
    DECLARE saldo_temp DECIMAL(10, 2);
    -- CONTADOR: Lleva el registro de cuántos pagos fueron exitosos
    DECLARE pagos_exitosos INT DEFAULT 0;
    
    -- Iniciar la transacción principal
    START TRANSACTION;
    
    -- ===== PRIMER PAGO =====
    -- Obtener saldo actual de la primera cuenta
    SELECT saldo INTO saldo_temp FROM cuentas WHERE titular = cuenta1;
    
    -- VALIDACIÓN: Verificar si tiene saldo suficiente para procesar este pago
    IF saldo_temp >= monto1 THEN
        -- Descontar el monto
        UPDATE cuentas SET saldo = saldo - monto1 WHERE titular = cuenta1;
        -- Incrementar contador de operaciones exitosas
        SET pagos_exitosos = pagos_exitosos + 1;
        -- SAVEPOINT ESTRATÉGICO: Guarda el estado después del primer pago exitoso
        -- Si los pagos siguientes fallan, podemos volver aquí sin perder este pago
        SAVEPOINT pago1;
    END IF;
    -- Si no tiene saldo suficiente, simplemente no lo procesa 
    
    -- ===== SEGUNDO PAGO =====
    SELECT saldo INTO saldo_temp FROM cuentas WHERE titular = cuenta2;
    
    IF saldo_temp >= monto2 THEN
        -- Tiene saldo suficiente, procesar
        UPDATE cuentas SET saldo = saldo - monto2 WHERE titular = cuenta2;
        SET pagos_exitosos = pagos_exitosos + 1;
        -- SAVEPOINT: Ahora tenemos 2 pagos exitosos
        SAVEPOINT pago2;
    ELSE
        -- No tiene saldo: Volver al punto después del primer pago
        -- Esto mantiene el primer pago pero cancela cualquier cambio posterior
        ROLLBACK TO pago1;
    END IF;
    
    -- ===== TERCER PAGO =====
    SELECT saldo INTO saldo_temp FROM cuentas WHERE titular = cuenta3;
    
    IF saldo_temp >= monto3 THEN
        -- Tiene saldo suficiente, procesar
        UPDATE cuentas SET saldo = saldo - monto3 WHERE titular = cuenta3;
        SET pagos_exitosos = pagos_exitosos + 1;
        -- SAVEPOINT: Los 3 pagos fueron exitosos
        SAVEPOINT pago3;
    ELSE
        -- No tiene saldo: Volver al último punto exitoso usando savepoints
        IF pagos_exitosos = 2 THEN
            -- ROLLBACK SELECTIVO: Mantiene 2 pagos exitosos, descarta el tercero
            ROLLBACK TO pago2;
        ELSEIF pagos_exitosos = 1 THEN
            -- ROLLBACK SELECTIVO: Mantiene solo el primer pago, descarta el resto
            ROLLBACK TO pago1;
        END IF;
    END IF;
    
    -- COMMIT FINAL: Confirma todos los pagos que fueron exitosos (parcial o total)
    COMMIT;
    
    -- Mostrar resultado final
    SELECT CONCAT('Pagos procesados exitosamente: ', pagos_exitosos, ' de 3') AS resultado;
END;

-- Probar el procedimiento
CALL procesar_pagos_multiples('Juan Pérez', 50.00, 'María García', 100.00, 'Carlos López', 5000.00);
SELECT * FROM cuentas;


-- ============================================
-- EJEMPLO 2.3: Savepoints con operaciones en múltiples tablas
-- Explicación: Gestiona ventas de múltiples productos coordinando las tablas cuentas,
-- productos y movimientos, confirmando ventas parciales si algún producto falla
-- ============================================
-- Este ejemplo muestra cómo vender múltiples productos
-- Si el segundo falla, aún se confirma la venta del primero

DROP PROCEDURE IF EXISTS registrar_venta_completa;

CREATE PROCEDURE registrar_venta_completa(
    IN cliente VARCHAR(100),   -- Cliente que realiza la compra
    IN prod1_id INT,           -- ID del primer producto
    IN prod1_cant INT,         -- Cantidad del primer producto
    IN prod2_id INT,           -- ID del segundo producto
    IN prod2_cant INT          -- Cantidad del segundo producto
)
BEGIN
    -- Variables para almacenar información del primer producto
    DECLARE stock1 INT;
    DECLARE precio1 DECIMAL(10, 2);
    -- Variables para almacenar información del segundo producto
    DECLARE stock2 INT;
    DECLARE precio2 DECIMAL(10, 2);
    -- Variables de control
    DECLARE saldo_cliente DECIMAL(10, 2);    -- Saldo disponible del cliente
    DECLARE total_parcial DECIMAL(10, 2);    -- Total de cada compra individual
    DECLARE items_procesados INT DEFAULT 0;  -- Contador de productos procesados
    
    -- Iniciar transacción principal
    START TRANSACTION;
    
    -- Obtener saldo actual del cliente
    SELECT saldo INTO saldo_cliente FROM cuentas WHERE titular = cliente;
    
    -- ===== PROCESAR PRIMER PRODUCTO =====
    -- Obtener información del producto (stock disponible y precio)
    SELECT stock, precio INTO stock1, precio1 FROM productos WHERE id = prod1_id;
    
    -- Calcular cuánto cuesta esta compra
    SET total_parcial = precio1 * prod1_cant;
    
    -- Validar que haya stock Y que el cliente tenga saldo suficiente
    IF stock1 >= prod1_cant AND saldo_cliente >= total_parcial THEN
        --  Hay stock y saldo suficiente
        
        -- 1. Descontar del inventario
        UPDATE productos SET stock = stock - prod1_cant WHERE id = prod1_id;
        
        -- 2. Descontar del saldo del cliente
        UPDATE cuentas SET saldo = saldo - total_parcial WHERE titular = cliente;
        
        -- 3. Registrar el movimiento para auditoría
        INSERT INTO movimientos (cuenta, tipo, monto) VALUES (cliente, 'RETIRO', total_parcial);
        
        -- 4. Actualizar saldo local (para validar siguiente producto)
        SET saldo_cliente = saldo_cliente - total_parcial;
        
        -- 5. Marcar que un producto fue procesado
        SET items_procesados = 1;
        
        -- SAVEPOINT: Guardar el estado después de vender el primer producto
        -- Si el segundo producto falla, podemos volver aquí
        SAVEPOINT producto1;
    ELSE
        --  No hay stock o saldo suficiente para el primer producto
        -- Cancelar toda la operación
        ROLLBACK;
        SELECT 'Error en producto 1: Stock o saldo insuficiente' AS resultado;
    END IF;
    
    -- ===== PROCESAR SEGUNDO PRODUCTO =====
    -- Solo intentar si el primero fue exitoso
    IF items_procesados = 1 THEN
        
        -- Obtener información del segundo producto
        SELECT stock, precio INTO stock2, precio2 FROM productos WHERE id = prod2_id;
        
        -- Calcular costo del segundo producto
        SET total_parcial = precio2 * prod2_cant;
        
        -- Validar stock y saldo (usando el saldo actualizado)
        IF stock2 >= prod2_cant AND saldo_cliente >= total_parcial THEN
            --  Hay stock y saldo para el segundo producto
            
            -- Realizar las mismas operaciones que con el primer producto
            UPDATE productos SET stock = stock - prod2_cant WHERE id = prod2_id;
            UPDATE cuentas SET saldo = saldo - total_parcial WHERE titular = cliente;
            INSERT INTO movimientos (cuenta, tipo, monto) VALUES (cliente, 'RETIRO', total_parcial);
            
            SET items_procesados = 2;
            
            -- SAVEPOINT: Ambos productos vendidos exitosamente
            SAVEPOINT producto2;
            
            -- Confirmar TODA la venta (ambos productos)
            COMMIT;
            SELECT 'Venta completa exitosa: 2 productos' AS resultado;
        ELSE
            --  No hay stock/saldo para el segundo producto
            -- CLAVE: Volver al savepoint después del primer producto
            -- Esto mantiene la venta del primer producto
            ROLLBACK TO producto1;
            
            -- Confirmar solo el primer producto
            COMMIT;
            SELECT 'Venta parcial: solo producto 1 procesado' AS resultado;
        END IF;
    END IF;
END;

-- Probar venta completa
CALL registrar_venta_completa('Juan Pérez', 2, 2, 3, 1);
SELECT * FROM cuentas;
SELECT * FROM productos;


-- ============================================
-- EJEMPLO 2.4: Savepoints con manejo de errores
-- Actualización de inventario con rollback selectivo
-- Explicación: Transfiere productos entre almacenes usando savepoint para revertir
-- el descuento del origen si el destino no existe, evitando pérdida de inventario
-- ============================================
-- Este ejemplo muestra transferencias entre almacenes
-- Si el destino no existe, el savepoint permite revertir el descuento del origen
-- sin perder toda la transacción

-- Crear tabla para gestionar inventario en múltiples ubicaciones
CREATE TABLE inventario_almacenes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    producto_id INT,                    -- Producto almacenado
    almacen VARCHAR(50),                -- Ubicación del almacén
    cantidad INT,                       -- Stock en este almacén
    FOREIGN KEY (producto_id) REFERENCES productos(id)
);

-- Datos de ejemplo: 2 productos en 2 almacenes cada uno
INSERT INTO inventario_almacenes (producto_id, almacen, cantidad) VALUES
(1, 'Almacén A', 5),   -- Producto 1: 5 unidades en Almacén A
(1, 'Almacén B', 5),   -- Producto 1: 5 unidades en Almacén B
(2, 'Almacén A', 25),  -- Producto 2: 25 unidades en Almacén A
(2, 'Almacén B', 25);  -- Producto 2: 25 unidades en Almacén B

DROP PROCEDURE IF EXISTS transferir_entre_almacenes;

CREATE PROCEDURE transferir_entre_almacenes(
    IN prod_id INT,                 -- ID del producto a transferir
    IN almacen_origen VARCHAR(50),  -- Almacén de donde se saca
    IN almacen_destino VARCHAR(50), -- Almacén a donde se envía
    IN cantidad INT                 -- Cantidad a transferir
)
BEGIN
    -- Variable para almacenar stock del almacén origen
    DECLARE stock_origen INT;
    -- Variable para mensajes de operación
    DECLARE operacion VARCHAR(100);
    
    -- Iniciar transacción
    START TRANSACTION;
    
    -- ===== VALIDAR ALMACÉN ORIGEN =====
    -- Obtener cuántas unidades hay en el almacén origen
    SELECT cantidad INTO stock_origen 
    FROM inventario_almacenes 
    WHERE producto_id = prod_id AND almacen = almacen_origen;
    
    -- VALIDACIÓN 1: IS NULL verifica si el almacén NO existe en la BD
    IF stock_origen IS NULL THEN
        -- El almacén no existe en la base de datos - cancelar todo
        ROLLBACK;
        SELECT 'Error: Almacén origen no encontrado' AS resultado;
        
    -- VALIDACIÓN 2: ¿Hay suficiente stock?
    ELSEIF stock_origen < cantidad THEN
        -- Hay almacén pero no tiene suficiente stock
        ROLLBACK;
        SELECT CONCAT('Error: Stock insuficiente. Disponible: ', stock_origen) AS resultado;
        
    ELSE
        --  El almacén existe y tiene stock suficiente
        
        -- ===== PASO 1: DESCONTAR DEL ORIGEN =====
        UPDATE inventario_almacenes 
        SET cantidad = cantidad - cantidad  -- Restar la cantidad a transferir
        WHERE producto_id = prod_id AND almacen = almacen_origen;
        
        -- Registrar que el descuento fue exitoso
        SET operacion = 'Descuento de origen exitoso';
        
        -- SAVEPOINT CRÍTICO: Este es el punto clave de recuperación
        -- Guarda el estado DESPUÉS de descontar del origen
        -- Si el destino no existe, usaremos este punto para REVERTIR el descuento
        SAVEPOINT descuento_origen;
        
        -- ===== PASO 2: INCREMENTAR EN DESTINO =====
        -- EXISTS: Verifica si el almacén destino existe sin cargar todos los datos
        IF EXISTS (SELECT 1 FROM inventario_almacenes 
                   WHERE producto_id = prod_id AND almacen = almacen_destino) THEN
            
            -- El almacén destino existe
            -- Agregar la cantidad al almacén destino
            UPDATE inventario_almacenes 
            SET cantidad = cantidad + cantidad  -- Sumar la cantidad transferida
            WHERE producto_id = prod_id AND almacen = almacen_destino;
            
            -- TODO EXITOSO: Confirmar la transferencia completa
            COMMIT;
            SELECT 'Transferencia exitosa entre almacenes' AS resultado;
            
        ELSE
            --  El almacén destino NO existe
            -- PROBLEMA: Ya descontamos del origen pero no podemos agregar al destino
            
            -- SOLUCIÓN CON SAVEPOINT: Primero volvemos al punto guardado
            -- Esto REVIERTE el descuento que hicimos del almacén origen
            ROLLBACK TO descuento_origen;
            
            -- Ahora cancelar toda la transacción limpiamente
            ROLLBACK;
            
            SELECT 'Error: Almacén destino no encontrado. Operación cancelada' AS resultado;
            -- CLAVE: Gracias al savepoint, el stock del origen NO se modificó y queda intacto
        END IF;
    END IF;
END;

-- Probar transferencia entre almacenes
CALL transferir_entre_almacenes(1, 'Almacén A', 'Almacén B', 3);
SELECT * FROM inventario_almacenes;

-- Probar con almacén destino inexistente
CALL transferir_entre_almacenes(2, 'Almacén A', 'Almacén C', 5);
SELECT * FROM inventario_almacenes;


-- ============================================
-- EJERCICIO PRÁCTICO 2
-- Explicación: Ejercicio para practicar savepoints realizando múltiples compras
-- y usando ROLLBACK TO para cancelar selectivamente operaciones fallidas
-- ============================================
-- Simula un sistema de compras con savepoints:
-- 1. Descuenta 100 de Juan (savepoint: compra1)
-- 2. Descuenta 200 de María (savepoint: compra2)
-- 3. Descuenta 400 de Carlos (esto fallará por saldo insuficiente)
-- 4. Usa ROLLBACK TO para cancelar solo la compra de Carlos
-- 5. Confirma las compras de Juan y María

