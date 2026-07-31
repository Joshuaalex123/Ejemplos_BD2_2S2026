-- Procedimientos almacenados en PostgreSQL



--SINTAXIS BÁSICA  CON RETORNO
-- ============================================================
-- 1. Función para obtener clientes mayores de 30 años
-- ============================================================
-- Crea o reemplaza una función llamada obtener_clientes_mayores_30
CREATE OR REPLACE FUNCTION obtener_clientes_mayores_30()
-- Define que la función retorna una tabla con tres columnas: id_cliente, nombre y edad
RETURNS TABLE(id_cliente INT, nombre VARCHAR, edad INT) AS $$
BEGIN
    -- Retorna el resultado de la siguiente consulta
    RETURN QUERY
    -- Selecciona id_cliente, nombre y edad de la tabla clientes
    SELECT clientes.id_cliente, clientes.nombre, clientes.edad
    FROM clientes
    -- Filtra solo los clientes cuya edad sea mayor a 30
    WHERE clientes.edad > 30;
END;

$$ LANGUAGE plpgsql;



--SINTAXIS BÁSICA  CON PARÁMETROS DE ENTRADA
-- ============================================================
-- 2. Función para obtener clientes por ciudad
-- ============================================================
-- Crea o reemplaza una función que recibe un parámetro de entrada: ciudad_param
CREATE OR REPLACE FUNCTION obtener_clientes_por_ciudad(ciudad_param VARCHAR)
-- Define que retorna una tabla con tres columnas: id_cliente, nombre y ciudad
RETURNS TABLE(id_cliente INT, nombre VARCHAR, ciudad VARCHAR) AS $$
BEGIN
    -- Retorna el resultado de la consulta
    RETURN QUERY
    -- Selecciona id_cliente, nombre y ciudad de la tabla clientes
    SELECT clientes.id_cliente, clientes.nombre, clientes.ciudad
    FROM clientes
    -- Filtra los clientes donde la ciudad coincida con el parámetro recibido
    WHERE clientes.ciudad = ciudad_param;
END;

$$ LANGUAGE plpgsql;



--SINTAXIS BÁSICA  CON PARÁMETROS DE SALIDA
-- ============================================================
-- 3. Función para calcular total de ventas de un cliente
-- ============================================================
-- Crea una función con un parámetro de entrada (p_id_cliente) y dos parámetros de salida (OUT)
CREATE OR REPLACE FUNCTION calcular_total_ventas(p_id_cliente INT, OUT total_ventas DECIMAL, OUT mensaje VARCHAR) AS $$
BEGIN
    -- Calcula la suma de todos los montos de las órdenes del cliente
    SELECT SUM(monto) INTO total_ventas
    FROM ordenes
    -- Filtra solo las órdenes del cliente específico
    WHERE id_cliente = p_id_cliente;
    
    -- Evalúa si el total de ventas supera los 1000
    IF total_ventas > 1000 THEN
        -- Si es mayor, asigna el mensaje de éxito
        mensaje := 'Meta de ventas superada';
    ELSE
        -- Si no es mayor, asigna el mensaje de no cumplimiento
        mensaje := 'Meta de ventas no superada';
    END IF;
END;

$$ LANGUAGE plpgsql;




--SINTAXIS BÁSICA  CON TRANSACCIONES
-- ============================================================
-- 4. Función para realizar una compra 
-- ============================================================
-- Crea una función que recibe id del cliente y monto de la compra
CREATE OR REPLACE FUNCTION realizar_compra(p_id_cliente INT, p_monto DECIMAL)
-- No retorna ningún valor (VOID)
RETURNS VOID AS $$
BEGIN
    -- Inicia un bloque de transacción con manejo de excepciones
    BEGIN
        -- Actualiza el saldo del cliente, restando el monto de la compra
        UPDATE clientes SET saldo = saldo - p_monto WHERE id_cliente = p_id_cliente;
        
        -- Registra la orden de compra en la tabla ordenes
        INSERT INTO ordenes(id_cliente, monto) VALUES (p_id_cliente, p_monto);
    -- Captura cualquier excepción que ocurra durante la transacción
    EXCEPTION
        WHEN OTHERS THEN
            -- Muestra un mensaje de notificación sobre el error
            RAISE NOTICE 'Error en la transacción. Rollback realizado.';
            -- Revierte todos los cambios realizados en la transacción
            ROLLBACK;
            -- Sale de la función sin realizar cambios
            RETURN;
    END;
END;

$$ LANGUAGE plpgsql;


-- ============================================================
-- CONSULTAS DE EJEMPLO
-- ============================================================

-- Consulta 1: Obtener nombre y edad de todos los clientes
SELECT
    nombre,
    edad
FROM clientes;

-- Consulta 2: Obtener todos los datos de clientes mayores de 30
SELECT *
FROM clientes
WHERE edad > 30;

-- Consulta 3: Obtener nombre de clientes con fecha de sus órdenes
SELECT
    clientes.nombre,
    ordenes.fecha
FROM clientes
JOIN ordenes ON (
    clientes.id_cliente = ordenes.id_cliente
);


-- ============================================================
-- USO DE LOS PROCEDIMIENTOS
-- ============================================================

-- Ejemplo 1: Obtener clientes mayores de 30 años
SELECT * FROM obtener_clientes_mayores_30();

-- Ejemplo 2: Obtener clientes de La Paz
SELECT * FROM obtener_clientes_por_ciudad('La Paz');

-- Ejemplo 3: Calcular total de ventas del cliente con id 3
SELECT * FROM calcular_total_ventas(3);

-- Ejemplo 4: Realizar una compra 
SELECT realizar_compra(1, 100.00);

-- Verificar el nuevo saldo del cliente 1
SELECT id_cliente, nombre, saldo FROM clientes WHERE id_cliente = 1;
