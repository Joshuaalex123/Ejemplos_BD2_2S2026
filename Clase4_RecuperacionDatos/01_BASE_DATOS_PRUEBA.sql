
-- Crear base de datos
DROP DATABASE IF EXISTS tienda_online;
CREATE DATABASE tienda_online CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tienda_online;

-- =====================================================
-- TABLA: Clientes
-- =====================================================
CREATE TABLE clientes (
    id_cliente INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    telefono VARCHAR(20),
    direccion VARCHAR(255),
    ciudad VARCHAR(50),
    pais VARCHAR(50),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE
);

-- =====================================================
-- TABLA: Categorías
-- =====================================================
CREATE TABLE categorias (
    id_categoria INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(50) NOT NULL,
    descripcion TEXT
);

-- =====================================================
-- TABLA: Productos
-- =====================================================
CREATE TABLE productos (
    id_producto INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL,
    stock INT DEFAULT 0,
    id_categoria INT,
    fecha_agregado DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
);

-- =====================================================
-- TABLA: Pedidos
-- =====================================================
CREATE TABLE pedidos (
    id_pedido INT PRIMARY KEY AUTO_INCREMENT,
    id_cliente INT NOT NULL,
    fecha_pedido DATETIME DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10, 2) NOT NULL,
    estado ENUM('pendiente', 'procesando', 'enviado', 'entregado', 'cancelado') DEFAULT 'pendiente',
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

-- =====================================================
-- TABLA: Detalle de Pedidos
-- =====================================================
CREATE TABLE detalle_pedidos (
    id_detalle INT PRIMARY KEY AUTO_INCREMENT,
    id_pedido INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

-- =====================================================
-- INSERTAR DATOS DE PRUEBA
-- =====================================================

-- Clientes
INSERT INTO clientes (nombre, email, telefono, direccion, ciudad, pais) VALUES
('Juan Pérez', 'juan.perez@email.com', '555-0101', 'Calle 10 #123', 'La Paz', 'Bolivia'),
('María García', 'maria.garcia@email.com', '555-0102', 'Av. Ballivián 456', 'La Paz', 'Bolivia'),
('Carlos López', 'carlos.lopez@email.com', '555-0103', 'Calle Potosí 789', 'Cochabamba', 'Bolivia'),
('Ana Martínez', 'ana.martinez@email.com', '555-0104', 'Av. América 321', 'Santa Cruz', 'Bolivia'),
('Pedro Rodríguez', 'pedro.rodriguez@email.com', '555-0105', 'Calle Sucre 654', 'La Paz', 'Bolivia'),
('Laura Fernández', 'laura.fernandez@email.com', '555-0106', 'Av. 6 de Agosto 987', 'La Paz', 'Bolivia'),
('Diego Sánchez', 'diego.sanchez@email.com', '555-0107', 'Calle Comercio 147', 'Cochabamba', 'Bolivia'),
('Sofia Torres', 'sofia.torres@email.com', '555-0108', 'Av. Cristo 258', 'Santa Cruz', 'Bolivia'),
('Miguel Ramírez', 'miguel.ramirez@email.com', '555-0109', 'Calle Ayacucho 369', 'La Paz', 'Bolivia'),
('Carmen Flores', 'carmen.flores@email.com', '555-0110', 'Av. Arce 741', 'La Paz', 'Bolivia');

-- Categorías
INSERT INTO categorias (nombre, descripcion) VALUES
('Electrónica', 'Productos electrónicos y gadgets'),
('Ropa', 'Prendas de vestir para toda ocasión'),
('Hogar', 'Artículos para el hogar'),
('Deportes', 'Equipamiento deportivo'),
('Libros', 'Libros físicos y digitales'),
('Juguetes', 'Juguetes para niños y adultos');

-- Productos
INSERT INTO productos (nombre, descripcion, precio, stock, id_categoria) VALUES
('Laptop HP 15', 'Laptop con Intel i5, 8GB RAM, 256GB SSD', 4500.00, 15, 1),
('Mouse Inalámbrico Logitech', 'Mouse inalámbrico ergonómico', 150.00, 50, 1),
('Teclado Mecánico', 'Teclado mecánico RGB', 350.00, 30, 1),
('Monitor LG 24"', 'Monitor Full HD 24 pulgadas', 1200.00, 20, 1),
('Auriculares Bluetooth', 'Auriculares con cancelación de ruido', 450.00, 40, 1),
('Camisa Formal', 'Camisa de vestir para hombre', 250.00, 60, 2),
('Pantalón Jeans', 'Pantalón denim azul', 300.00, 45, 2),
('Zapatillas Deportivas', 'Zapatillas para running', 550.00, 35, 2),
('Vestido Casual', 'Vestido de verano', 280.00, 25, 2),
('Chaqueta de Invierno', 'Chaqueta térmica', 650.00, 20, 2),
('Lámpara LED', 'Lámpara de escritorio con USB', 180.00, 55, 3),
('Almohada Memory Foam', 'Almohada ergonómica', 220.00, 40, 3),
('Juego de Sábanas', 'Sábanas 100% algodón', 320.00, 30, 3),
('Cafetera', 'Cafetera automática 12 tazas', 480.00, 25, 3),
('Licuadora', 'Licuadora 5 velocidades', 280.00, 35, 3),
('Balón de Fútbol', 'Balón profesional', 180.00, 50, 4),
('Raqueta de Tenis', 'Raqueta profesional', 850.00, 15, 4),
('Pesas 10kg', 'Set de mancuernas', 320.00, 25, 4),
('Bicicleta de Montaña', 'Bicicleta 21 velocidades', 2800.00, 10, 4),
('Colchoneta de Yoga', 'Colchoneta antideslizante', 150.00, 45, 4),
('El Principito', 'Libro clásico en español', 85.00, 100, 5),
('Cien Años de Soledad', 'Gabriel García Márquez', 95.00, 80, 5),
('Harry Potter Set', 'Colección completa', 850.00, 20, 5),
('Diccionario Español', 'Diccionario completo', 180.00, 30, 5),
('LEGO Star Wars', 'Set de construcción', 650.00, 25, 6),
('Muñeca Barbie', 'Muñeca con accesorios', 180.00, 40, 6),
('Puzzle 1000 piezas', 'Puzzle de paisaje', 120.00, 35, 6),
('Consola de Juegos', 'Consola portátil', 1200.00, 15, 6);

-- Pedidos
INSERT INTO pedidos (id_cliente, fecha_pedido, total, estado) VALUES
(1, '2026-01-15 10:30:00', 4650.00, 'entregado'),
(2, '2026-01-16 14:20:00', 530.00, 'entregado'),
(3, '2026-01-17 09:15:00', 850.00, 'entregado'),
(4, '2026-01-18 16:45:00', 1500.00, 'enviado'),
(5, '2026-01-19 11:00:00', 280.00, 'procesando'),
(1, '2026-01-20 13:30:00', 870.00, 'procesando'),
(6, '2026-01-21 10:00:00', 950.00, 'pendiente'),
(7, '2026-01-22 15:20:00', 2800.00, 'pendiente'),
(8, '2026-01-23 12:10:00', 365.00, 'cancelado'),
(9, '2026-01-24 14:50:00', 1200.00, 'entregado'),
(10, '2026-01-25 09:30:00', 650.00, 'enviado'),
(2, '2026-01-26 16:00:00', 320.00, 'entregado'),
(3, '2026-01-27 11:45:00', 180.00, 'procesando'),
(4, '2026-01-28 13:20:00', 550.00, 'pendiente'),
(5, '2026-01-29 10:15:00', 1050.00, 'entregado');

-- Detalle de Pedidos
INSERT INTO detalle_pedidos (id_pedido, id_producto, cantidad, precio_unitario) VALUES
-- Pedido 1
(1, 1, 1, 4500.00),
(1, 2, 1, 150.00),
-- Pedido 2
(2, 6, 2, 250.00),
(2, 11, 1, 180.00),
-- Pedido 3
(3, 23, 1, 850.00),
-- Pedido 4
(4, 4, 1, 1200.00),
(4, 5, 1, 450.00),
-- Pedido 5
(5, 15, 1, 280.00),
-- Pedido 6
(6, 17, 1, 850.00),
-- Pedido 7
(7, 24, 5, 180.00),
(7, 12, 1, 220.00),
-- Pedido 8
(8, 19, 1, 2800.00),
-- Pedido 9
(9, 21, 3, 85.00),
(9, 27, 1, 120.00),
-- Pedido 10
(10, 28, 1, 1200.00),
-- Pedido 11
(11, 25, 1, 650.00),
-- Pedido 12
(12, 13, 1, 320.00),
-- Pedido 13
(13, 16, 1, 180.00),
-- Pedido 14
(14, 8, 1, 550.00),
-- Pedido 15
(15, 1, 1, 4500.00),
(15, 3, 1, 350.00),
(15, 4, 1, 1200.00);

-- =====================================================
-- VISTAS ÚTILES
-- =====================================================

CREATE VIEW vista_resumen_ventas AS
SELECT 
    c.nombre AS cliente,
    COUNT(p.id_pedido) AS total_pedidos,
    SUM(p.total) AS total_gastado
FROM clientes c
LEFT JOIN pedidos p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nombre;

CREATE VIEW vista_productos_mas_vendidos AS
SELECT 
    pr.nombre AS producto,
    cat.nombre AS categoria,
    SUM(dp.cantidad) AS unidades_vendidas,
    SUM(dp.cantidad * dp.precio_unitario) AS ingresos_totales
FROM productos pr
JOIN detalle_pedidos dp ON pr.id_producto = dp.id_producto
JOIN categorias cat ON pr.id_categoria = cat.id_categoria
GROUP BY pr.id_producto, pr.nombre, cat.nombre
ORDER BY unidades_vendidas DESC;


