-- ============================================================================
-- SCRIPT DE DATOS REALES (SEEDS) PARA SUPABASE POSTGRESQL
-- Asesor Financiero IA para MYPES Peruanas (100% por voz en WhatsApp)
-- Ejecutar en Supabase: SQL Editor > New Query > Run
-- ============================================================================

-- Limpiar datos previos si existen (conservando la estructura)
TRUNCATE TABLE ventas, gastos, productos_insumos, metas_ahorro, config_negocio RESTART IDENTITY CASCADE;

-- ----------------------------------------------------------------------------
-- 1. CONFIGURACIÓN DE LOS 3 NEGOCIOS PERUANOS (Restaurante, Retail, Servicios)
-- ----------------------------------------------------------------------------
INSERT INTO config_negocio (id, nombre_negocio, tipo_negocio, telefono_whatsapp, moneda, fecha_registro) VALUES
(1, 'Cevichería El Huarique del Puerto', 'restaurante', '+51987654321', 'PEN', NOW() - INTERVAL '180 days'),
(2, 'Bodega & Minimarket San Martín', 'retail', '+51912345678', 'PEN', NOW() - INTERVAL '240 days'),
(3, 'Lavandería & Costura Express', 'servicios', '+51976543210', 'PEN', NOW() - INTERVAL '150 days');

-- ----------------------------------------------------------------------------
-- 2. PRODUCTOS E INSUMOS CON MÁRGENES, ROTACIÓN Y MERMAS
-- ----------------------------------------------------------------------------

-- Negocio 1: Cevichería (Restaurante - foco en insumos perecederos y margen por plato)
INSERT INTO productos_insumos (negocio_id, nombre, precio_compra, precio_venta, stock_actual, unidad_medida, dias_sin_rotacion, es_perecible) VALUES
(1, 'Pescado Corvina Fresca (del día)', 18.00, 38.00, 16.50, 'kg', 1, TRUE),
(1, 'Mixtura de Mariscos (Calamar, Langostinos)', 14.50, 32.00, 24.00, 'kg', 3, TRUE),
(1, 'Limón Sutil Piurano (Malla de 10kg)', 38.00, 75.00, 5.00, 'paquete', 6, TRUE),
(1, 'Cebolla Roja de Arequipa', 2.80, 6.00, 45.00, 'kg', 2, TRUE),
(1, 'Choclo Desgranado y Camote Glaseado', 3.50, 8.00, 30.00, 'kg', 2, TRUE),
(1, 'Pulpo Entero Congelado (Insumo Caro)', 42.00, 85.00, 9.50, 'kg', 38, TRUE), -- ¡ESTANCADO 38 DÍAS - CAPITAL PARADO S/ 399!
(1, 'Lomo Fino Nacional (para Lomo Saltado)', 28.00, 52.00, 12.00, 'kg', 4, TRUE),
(1, 'Cerveza Cusqueña Trigo 330ml', 4.20, 10.00, 48.00, 'unidad', 2, FALSE),
(1, 'Chicha Morada de Maíz Morado (Jarra 1L)', 3.20, 14.00, 35.00, 'litro', 1, FALSE),
(1, 'Ají Limo y Culantro Fresco', 1.50, 4.00, 18.00, 'kg', 1, TRUE);

-- Negocio 2: Bodega & Minimarket (Retail - foco en rotación, licores y campañas)
INSERT INTO productos_insumos (negocio_id, nombre, precio_compra, precio_venta, stock_actual, unidad_medida, dias_sin_rotacion, es_perecible) VALUES
(2, 'Arroz Costeño Saco 50kg Extra', 145.00, 175.00, 12.00, 'saco', 2, FALSE),
(2, 'Aceite Primor Clásico 1L (Caja x 12)', 98.00, 120.00, 10.00, 'caja', 3, FALSE),
(2, 'Azúcar Rubia Cartavio 50kg', 130.00, 158.00, 8.00, 'saco', 4, FALSE),
(2, 'Leche Gloria Azul (Six Pack)', 21.00, 25.50, 28.00, 'paquete', 2, FALSE),
(2, 'Six Pack Cerveza Pilsen Callao 355ml', 26.00, 34.00, 42.00, 'paquete', 1, FALSE),
(2, 'Whisky Johnnie Walker Black Label 750ml', 110.00, 155.00, 6.00, 'unidad', 54, FALSE), -- ¡ESTANCADO 54 DÍAS - CAPITAL PARADO S/ 660!
(2, 'Conservas de Durazno A1 en Almíbar (Caja)', 52.00, 72.00, 8.00, 'caja', 43, FALSE), -- ¡ESTANCADO 43 DÍAS - CAPITAL PARADO S/ 416!
(2, 'Huevos de Granja Rosados (Jaba 30 und)', 16.50, 21.00, 20.00, 'paquete', 3, TRUE),
(2, 'Fideos Don Vittorio Spaguetti (Caja)', 44.00, 56.00, 15.00, 'caja', 4, FALSE),
(2, 'Gaseosa Inca Kola 3L (Fardo x 4)', 38.00, 48.00, 25.00, 'paquete', 2, FALSE);

-- Negocio 3: Lavandería (Servicios - insumos industriales y margen de servicio)
INSERT INTO productos_insumos (negocio_id, nombre, precio_compra, precio_venta, stock_actual, unidad_medida, dias_sin_rotacion, es_perecible) VALUES
(3, 'Detergente Industrial Líquido 20L', 85.00, 140.00, 6.00, 'unidad', 5, FALSE),
(3, 'Suavizante Textil Aroma Lavanda 20L', 65.00, 110.00, 4.00, 'unidad', 6, FALSE),
(3, 'Desmanchador de Cuellos y Puños Pro', 45.00, 75.00, 3.00, 'unidad', 12, FALSE),
(3, 'Detergente Hipoalergénico Bebé (Galón)', 48.00, 80.00, 5.00, 'unidad', 42, FALSE), -- ¡ESTANCADO 42 DÍAS - CAPITAL PARADO S/ 240!
(3, 'Ganchos y Bolsas Plásticas Cubreterno (Millar)', 70.00, 120.00, 4.00, 'paquete', 8, FALSE),
(3, 'Servicio Lavado por Kilo (Ropa diaria)', 2.50, 7.50, 200.00, 'kg', 1, FALSE),
(3, 'Servicio Lavado Edredón / Plumón 2 Plazas', 6.00, 28.00, 40.00, 'unidad', 2, FALSE);

-- ----------------------------------------------------------------------------
-- 3. VENTAS HISTÓRICAS REALES (Mes actual, mes pasado y acumulados)
-- ----------------------------------------------------------------------------

-- Ventas Cevichería (Mes Actual: ~S/ 6,850 | Mes Pasado: ~S/ 7,420)
INSERT INTO ventas (negocio_id, producto_id, cantidad, total_venta, fecha_venta) VALUES
-- Ventas hace pocos días (Mes actual)
(1, 1, 42.0, 1596.00, NOW() - INTERVAL '1 day'),
(1, 2, 30.0, 960.00, NOW() - INTERVAL '3 days'),
(1, 7, 25.0, 1300.00, NOW() - INTERVAL '5 days'),
(1, 8, 80.0, 800.00, NOW() - INTERVAL '6 days'),
(1, 9, 65.0, 910.00, NOW() - INTERVAL '9 days'),
(1, 1, 35.0, 1330.00, NOW() - INTERVAL '12 days'),
-- Ventas Mes Pasado (hace 32 a 58 días)
(1, 1, 55.0, 2090.00, NOW() - INTERVAL '34 days'),
(1, 2, 45.0, 1440.00, NOW() - INTERVAL '38 days'),
(1, 7, 32.0, 1664.00, NOW() - INTERVAL '44 days'),
(1, 8, 120.0, 1200.00, NOW() - INTERVAL '48 days'),
(1, 9, 74.0, 1036.00, NOW() - INTERVAL '55 days'),
-- Ventas a 3 meses (hace 70 a 85 días)
(1, 1, 90.0, 3420.00, NOW() - INTERVAL '72 days'),
(1, 7, 60.0, 3120.00, NOW() - INTERVAL '80 days'),
-- Ventas a 6 meses (hace 110 a 160 días)
(1, 1, 150.0, 5700.00, NOW() - INTERVAL '120 days'),
(1, 2, 110.0, 3520.00, NOW() - INTERVAL '145 days');

-- Ventas Bodega (Mes Actual: ~S/ 5,820 | Mes Pasado: ~S/ 5,150 -> Creció +13%)
INSERT INTO ventas (negocio_id, producto_id, cantidad, total_venta, fecha_venta) VALUES
(2, 1, 10.0, 1750.00, NOW() - INTERVAL '2 days'),
(2, 2, 12.0, 1440.00, NOW() - INTERVAL '4 days'),
(2, 5, 30.0, 1020.00, NOW() - INTERVAL '7 days'),
(2, 4, 40.0, 1020.00, NOW() - INTERVAL '10 days'),
(2, 10, 12.0, 576.00, NOW() - INTERVAL '14 days'),
-- Mes Pasado
(2, 1, 12.0, 2100.00, NOW() - INTERVAL '35 days'),
(2, 2, 10.0, 1200.00, NOW() - INTERVAL '41 days'),
(2, 5, 35.0, 1190.00, NOW() - INTERVAL '47 days'),
(2, 4, 26.0, 663.00, NOW() - INTERVAL '52 days'),
-- 3 y 6 meses
(2, 1, 35.0, 6125.00, NOW() - INTERVAL '75 days'),
(2, 2, 40.0, 4800.00, NOW() - INTERVAL '135 days');

-- Ventas Lavandería (Mes Actual: ~S/ 4,120 | Mes Pasado: ~S/ 3,890)
INSERT INTO ventas (negocio_id, producto_id, cantidad, total_venta, fecha_venta) VALUES
(3, 6, 320.0, 2400.00, NOW() - INTERVAL '3 days'),
(3, 7, 42.0, 1176.00, NOW() - INTERVAL '6 days'),
(3, 6, 72.0, 544.00, NOW() - INTERVAL '11 days'),
(3, 6, 380.0, 2850.00, NOW() - INTERVAL '36 days'),
(3, 7, 37.0, 1036.00, NOW() - INTERVAL '48 days');

-- ----------------------------------------------------------------------------
-- 4. GASTOS FIJOS Y VARIABLES DETALLADOS
-- ----------------------------------------------------------------------------

-- Gastos Cevichería
INSERT INTO gastos (negocio_id, categoria, monto, descripcion, fecha_gasto) VALUES
(1, 'fijo', 1300.00, 'Alquiler local comercial Surquillo (Av. Angamos)', CURRENT_DATE - 3),
(1, 'fijo', 420.00, 'Servicio de Luz (Luz del Sur) y Gas Calidda', CURRENT_DATE - 5),
(1, 'fijo', 220.00, 'Servicio de Agua Potable y Alcantarillado (Sedapal)', CURRENT_DATE - 6),
(1, 'fijo', 1200.00, 'Sueldo primer cocinero / cevichero (Quincena)', CURRENT_DATE - 8),
(1, 'fijo', 850.00, 'Sueldo ayudante y mozo (Quincena)', CURRENT_DATE - 8),
(1, 'variable', 380.00, 'Hielo en cubos industrial y bolsas térmicas', CURRENT_DATE - 2),
(1, 'variable', 180.00, 'Envases descartables biodegradables para delivery', CURRENT_DATE - 4);

-- Gastos Bodega
INSERT INTO gastos (negocio_id, categoria, monto, descripcion, fecha_gasto) VALUES
(2, 'fijo', 850.00, 'Alquiler puerta a calle Urb. San Martín', CURRENT_DATE - 4),
(2, 'fijo', 310.00, 'Electricidad comercial (visicoolers y congeladoras 24/7)', CURRENT_DATE - 7),
(2, 'fijo', 60.00, 'Internet fibra óptica para POS y Yape', CURRENT_DATE - 10),
(2, 'variable', 120.00, 'Rollos térmicos para ticketera y bolsas plásticas', CURRENT_DATE - 2);

-- Gastos Lavandería
INSERT INTO gastos (negocio_id, categoria, monto, descripcion, fecha_gasto) VALUES
(3, 'fijo', 900.00, 'Alquiler local taller de lavado', CURRENT_DATE - 5),
(3, 'fijo', 520.00, 'Agua comercial Sedapal (alto consumo lavado)', CURRENT_DATE - 6),
(3, 'fijo', 280.00, 'Energía eléctrica trifásica (secadoras)', CURRENT_DATE - 7),
(3, 'variable', 210.00, 'Mantenimiento preventivo de válvulas y filtros', CURRENT_DATE - 3);

-- ----------------------------------------------------------------------------
-- 5. METAS DE AHORRO "GUARDADITOS BCP"
-- ----------------------------------------------------------------------------

-- Cevichería: Meta activa al 70% (Congeladora vertical para no tener mermas de mariscos)
INSERT INTO metas_ahorro (negocio_id, titulo_meta, monto_objetivo, monto_actual, plazo_dias, cuota_sugerida_bcp, frecuencia_cuota, estado, fecha_creacion) VALUES
(1, 'Congeladora Vertical Inox para Mariscos', 1800.00, 1260.00, 45, 40.00, 'diaria', 'activa', NOW() - INTERVAL '31 days');

-- Bodega: Meta al 100% CUMPLIDA (Detona regla #2 SMART: debe sugerir nueva meta inmediata)
INSERT INTO metas_ahorro (negocio_id, titulo_meta, monto_objetivo, monto_actual, plazo_dias, cuota_sugerida_bcp, frecuencia_cuota, estado, fecha_creacion, fecha_cumplimiento) VALUES
(2, 'Capital Preventivo Campaña Navideña', 2500.00, 2500.00, 60, 42.00, 'diaria', 'cumplida', NOW() - INTERVAL '60 days', NOW());

-- Lavandería: Meta activa al 50%
INSERT INTO metas_ahorro (negocio_id, titulo_meta, monto_objetivo, monto_actual, plazo_dias, cuota_sugerida_bcp, frecuencia_cuota, estado, fecha_creacion) VALUES
(3, 'Hidrolavadora a Vapor de Alta Presión', 1500.00, 750.00, 30, 25.00, 'diaria', 'activa', NOW() - INTERVAL '15 days');

-- ----------------------------------------------------------------------------
-- VERIFICACIÓN INMEDIATA EN SUPABASE
-- ----------------------------------------------------------------------------
SELECT obtener_metricas_mype(1); -- Retorna JSON con ventas, mermas de pulpo y meta BCP
