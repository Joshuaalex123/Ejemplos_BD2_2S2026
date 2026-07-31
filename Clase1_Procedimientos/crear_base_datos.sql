

--tabla de clientes
CREATE TABLE IF NOT EXISTS clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    edad INT NOT NULL CHECK (edad >= 0),
    ciudad VARCHAR(100),
    saldo DECIMAL(10, 2) DEFAULT 0.00
);

--tabla de ordenes
CREATE TABLE IF NOT EXISTS ordenes (
    id_orden SERIAL PRIMARY KEY,
    id_cliente INT NOT NULL,
    monto DECIMAL(10, 2) NOT NULL CHECK (monto >= 0),
    fecha DATE DEFAULT CURRENT_DATE,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE
);

-- datos de prueba en clientes
INSERT INTO clientes (nombre, edad, ciudad, saldo) VALUES
    ('Juan Pérez', 25, 'La Paz', 5000.00),
    ('María González', 35, 'Santa Cruz', 8000.00),
    ('Carlos Rodríguez', 42, 'Cochabamba', 12000.00),
    ('Ana López', 28, 'La Paz', 3000.00),
    ('Pedro Martínez', 38, 'Santa Cruz', 6500.00),
    ('Laura Fernández', 45, 'La Paz', 15000.00),
    ('Diego Silva', 31, 'Cochabamba', 4000.00),
    ('Sofia Torres', 22, 'Tarija', 2000.00),
    ('Miguel Quispe', 50, 'El Alto', 20000.00),
    ('Elena Morales', 33, 'Santa Cruz', 7500.00);

-- datos de prueba en ordenes
INSERT INTO ordenes (id_cliente, monto, fecha) VALUES
    (1, 150.50, '2025-01-10'),
    (2, 200.00, '2025-01-12'),
    (3, 1500.00, '2025-01-15'),
    (2, 300.75, '2025-01-16'),
    (4, 80.00, '2025-01-18'),
    (5, 450.25, '2025-01-20'),
    (3, 600.00, '2025-01-21'),
    (6, 900.50, '2025-01-22'),
    (7, 250.00, '2025-01-23'),
    (9, 1200.00, '2025-01-24');


-- Mostrar algunos datos
SELECT * FROM clientes ORDER BY id_cliente LIMIT 5;
SELECT * FROM ordenes ORDER BY id_orden LIMIT 5;
