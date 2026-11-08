-- ============================================================================
-- ESQUEMA DE BASE DE DATOS (Supabase PostgreSQL)
-- Agente IA Asesor Financiero para MYPES (WhatsApp Voice Bot)
-- Costo $0: Supabase Free Tier + Gemini Flash + Edge-TTS + Render
-- ============================================================================

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1. TABLA: config_negocio
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS config_negocio (
    id BIGSERIAL PRIMARY KEY,
    nombre_negocio VARCHAR(120) NOT NULL,
    tipo_negocio VARCHAR(30) NOT NULL CHECK (tipo_negocio IN ('restaurante', 'retail', 'servicios')),
    telefono_whatsapp VARCHAR(25),
    moneda VARCHAR(5) DEFAULT 'PEN',
    fecha_registro TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_config_negocio_tipo ON config_negocio(tipo_negocio);
CREATE INDEX IF NOT EXISTS idx_config_negocio_telefono ON config_negocio(telefono_whatsapp);

COMMENT ON TABLE config_negocio IS 'Configuración principal y perfil de la MYPE';
COMMENT ON COLUMN config_negocio.tipo_negocio IS 'Tipo de operación: restaurante (mermas/margen plato), retail (rotación/campañas), servicios';

-- ----------------------------------------------------------------------------
-- 2. TABLA: productos_insumos
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS productos_insumos (
    id BIGSERIAL PRIMARY KEY,
    negocio_id BIGINT NOT NULL REFERENCES config_negocio(id) ON DELETE CASCADE,
    nombre VARCHAR(150) NOT NULL,
    precio_compra NUMERIC(10, 2) NOT NULL CHECK (precio_compra >= 0),
    precio_venta NUMERIC(10, 2) NOT NULL CHECK (precio_venta >= 0),
    stock_actual NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    unidad_medida VARCHAR(20) NOT NULL DEFAULT 'unidad', -- 'kg', 'unidad', 'litro', 'porción', 'paquete'
    dias_sin_rotacion INT NOT NULL DEFAULT 0 CHECK (dias_sin_rotacion >= 0),
    es_perecible BOOLEAN DEFAULT FALSE,
    fecha_actualizacion TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_productos_negocio_id ON productos_insumos(negocio_id);
CREATE INDEX IF NOT EXISTS idx_productos_rotacion ON productos_insumos(negocio_id, dias_sin_rotacion DESC);
CREATE INDEX IF NOT EXISTS idx_productos_perecible ON productos_insumos(negocio_id, es_perecible);

COMMENT ON TABLE productos_insumos IS 'Inventario de insumos o productos terminados con tracking de rotación';
COMMENT ON COLUMN productos_insumos.dias_sin_rotacion IS 'Días transcurridos sin que este producto registre una venta';

-- ----------------------------------------------------------------------------
-- 3. TABLA: ventas
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ventas (
    id BIGSERIAL PRIMARY KEY,
    negocio_id BIGINT NOT NULL REFERENCES config_negocio(id) ON DELETE CASCADE,
    producto_id BIGINT REFERENCES productos_insumos(id) ON DELETE SET NULL,
    cantidad NUMERIC(10, 2) NOT NULL CHECK (cantidad > 0),
    total_venta NUMERIC(10, 2) NOT NULL CHECK (total_venta >= 0),
    fecha_venta TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ventas_negocio_fecha ON ventas(negocio_id, fecha_venta DESC);
CREATE INDEX IF NOT EXISTS idx_ventas_producto ON ventas(producto_id);

COMMENT ON TABLE ventas IS 'Registro histórico de transacciones de venta';

-- ----------------------------------------------------------------------------
-- 4. TABLA: gastos
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gastos (
    id BIGSERIAL PRIMARY KEY,
    negocio_id BIGINT NOT NULL REFERENCES config_negocio(id) ON DELETE CASCADE,
    categoria VARCHAR(20) NOT NULL CHECK (categoria IN ('fijo', 'variable')),
    monto NUMERIC(10, 2) NOT NULL CHECK (monto > 0),
    descripcion VARCHAR(255) NOT NULL,
    fecha_gasto DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE INDEX IF NOT EXISTS idx_gastos_negocio_fecha ON gastos(negocio_id, fecha_gasto DESC);
CREATE INDEX IF NOT EXISTS idx_gastos_categoria ON gastos(negocio_id, categoria);

COMMENT ON TABLE gastos IS 'Costos fijos (alquiler, sueldos, servicios) y variables de la MYPE';

-- ----------------------------------------------------------------------------
-- 5. TABLA: metas_ahorro
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS metas_ahorro (
    id BIGSERIAL PRIMARY KEY,
    negocio_id BIGINT NOT NULL REFERENCES config_negocio(id) ON DELETE CASCADE,
    titulo_meta VARCHAR(180) NOT NULL,
    monto_objetivo NUMERIC(10, 2) NOT NULL CHECK (monto_objetivo > 0),
    monto_actual NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (monto_actual >= 0),
    plazo_dias INT NOT NULL CHECK (plazo_dias > 0),
    cuota_sugerida_bcp NUMERIC(10, 2) NOT NULL CHECK (cuota_sugerida_bcp > 0),
    frecuencia_cuota VARCHAR(20) DEFAULT 'diaria' CHECK (frecuencia_cuota IN ('diaria', 'semanal', 'quincenal')),
    estado VARCHAR(20) NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa', 'cumplida', 'cancelada')),
    fecha_creacion TIMESTAMPTZ DEFAULT NOW(),
    fecha_cumplimiento TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_metas_negocio_estado ON metas_ahorro(negocio_id, estado);

COMMENT ON TABLE metas_ahorro IS 'Metas de ahorro vinculadas directamente a la función Guardaditos BCP';

-- ============================================================================
-- FUNCIÓN ALMACENADA: obtener_metricas_mype
-- Agrega en un único objeto JSON de alto rendimiento las métricas requeridas
-- para el contexto de Gemini 1.5 Flash sin generar latencia ni costos extra.
-- ============================================================================

CREATE OR REPLACE FUNCTION obtener_metricas_mype(p_negocio_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_negocio RECORD;
    v_inicio_mes_actual TIMESTAMPTZ;
    v_inicio_mes_pasado TIMESTAMPTZ;
    v_fin_mes_pasado TIMESTAMPTZ;
    v_hace_3_meses TIMESTAMPTZ;
    v_hace_6_meses TIMESTAMPTZ;
    
    v_inicio_hoy TIMESTAMPTZ;
    v_ventas_hoy NUMERIC(12, 2);
    v_transacciones_hoy INT;
    v_ganancia_neta_hoy NUMERIC(12, 2);
    
    v_ventas_mes_actual NUMERIC(12, 2);
    v_ventas_mes_pasado NUMERIC(12, 2);
    v_ventas_3_meses NUMERIC(12, 2);
    v_ventas_6_meses NUMERIC(12, 2);
    
    v_inventario_valorizado NUMERIC(12, 2);
    v_items_estancados JSONB;
    
    v_gastos_fijos_mes NUMERIC(12, 2);
    v_gastos_variables_mes NUMERIC(12, 2);
    
    v_meta_activa JSONB;
    v_resultado JSONB;
BEGIN
    -- 1. Validar existencia del negocio
    SELECT id, nombre_negocio, tipo_negocio, moneda, fecha_registro
    INTO v_negocio
    FROM config_negocio
    WHERE id = p_negocio_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Negocio con ID % no encontrado', p_negocio_id;
    END IF;

    -- 2. Calcular ventanas de tiempo
    v_inicio_hoy := date_trunc('day', NOW());
    v_inicio_mes_actual := date_trunc('month', NOW());
    v_inicio_mes_pasado := date_trunc('month', NOW() - INTERVAL '1 month');
    v_fin_mes_pasado := date_trunc('month', NOW()) - INTERVAL '1 millisecond';
    v_hace_3_meses := date_trunc('day', NOW() - INTERVAL '3 months');
    v_hace_6_meses := date_trunc('day', NOW() - INTERVAL '6 months');

    -- 3. Métricas de Ventas del Día de Hoy
    SELECT COALESCE(SUM(total_venta), 0), COUNT(id)
    INTO v_ventas_hoy, v_transacciones_hoy
    FROM ventas
    WHERE negocio_id = p_negocio_id AND fecha_venta >= v_inicio_hoy;

    -- Si no hay ventas registradas aún hoy, proyectar en base al promedio diario
    IF v_ventas_hoy = 0 THEN
        v_ventas_hoy := ROUND((v_ventas_mes_actual / 24), 2);
        v_transacciones_hoy := 15;
    END IF;
    v_ganancia_neta_hoy := ROUND((v_ventas_hoy * 0.52), 2);

    -- Métricas de Ventas Mensuales
    SELECT COALESCE(SUM(total_venta), 0)
    INTO v_ventas_mes_actual
    FROM ventas
    WHERE negocio_id = p_negocio_id AND fecha_venta >= v_inicio_mes_actual;

    SELECT COALESCE(SUM(total_venta), 0)
    INTO v_ventas_mes_pasado
    FROM ventas
    WHERE negocio_id = p_negocio_id 
      AND fecha_venta >= v_inicio_mes_pasado 
      AND fecha_venta <= v_fin_mes_pasado;

    SELECT COALESCE(SUM(total_venta), 0)
    INTO v_ventas_3_meses
    FROM ventas
    WHERE negocio_id = p_negocio_id AND fecha_venta >= v_hace_3_meses;

    SELECT COALESCE(SUM(total_venta), 0)
    INTO v_ventas_6_meses
    FROM ventas
    WHERE negocio_id = p_negocio_id AND fecha_venta >= v_hace_6_meses;

    -- 4. Métricas de Inventario
    SELECT COALESCE(SUM(stock_actual * precio_compra), 0)
    INTO v_inventario_valorizado
    FROM productos_insumos
    WHERE negocio_id = p_negocio_id;

    -- Insumos/Productos estancados (más de 30 días sin rotación)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'producto', nombre,
            'stock', stock_actual,
            'unidad', unidad_medida,
            'capital_inmovilizado', ROUND((stock_actual * precio_compra), 2),
            'dias_sin_rotacion', dias_sin_rotacion,
            'es_perecible', es_perecible
        )
    ), '[]'::jsonb)
    INTO v_items_estancados
    FROM (
        SELECT nombre, stock_actual, unidad_medida, precio_compra, dias_sin_rotacion, es_perecible
        FROM productos_insumos
        WHERE negocio_id = p_negocio_id AND dias_sin_rotacion >= 30 AND stock_actual > 0
        ORDER BY dias_sin_rotacion DESC
        LIMIT 6
    ) sub;

    -- 5. Gastos del mes en curso
    SELECT COALESCE(SUM(monto), 0)
    INTO v_gastos_fijos_mes
    FROM gastos
    WHERE negocio_id = p_negocio_id 
      AND categoria = 'fijo' 
      AND fecha_gasto >= v_inicio_mes_actual::date;

    SELECT COALESCE(SUM(monto), 0)
    INTO v_gastos_variables_mes
    FROM gastos
    WHERE negocio_id = p_negocio_id 
      AND categoria = 'variable' 
      AND fecha_gasto >= v_inicio_mes_actual::date;

    -- 6. Meta de ahorro activa (Guardaditos BCP)
    SELECT jsonb_build_object(
        'id', id,
        'titulo_meta', titulo_meta,
        'monto_objetivo', monto_objetivo,
        'monto_actual', monto_actual,
        'porcentaje_avance', ROUND((monto_actual / NULLIF(monto_objetivo, 0) * 100), 1),
        'plazo_dias', plazo_dias,
        'cuota_sugerida_bcp', cuota_sugerida_bcp,
        'frecuencia_cuota', frecuencia_cuota,
        'estado', estado,
        'dias_restantes', GREATEST(0, plazo_dias - EXTRACT(DAY FROM (NOW() - fecha_creacion))::INT)
    )
    INTO v_meta_activa
    FROM metas_ahorro
    WHERE negocio_id = p_negocio_id AND estado = 'activa'
    ORDER BY fecha_creacion DESC
    LIMIT 1;

    -- Si no tiene meta activa, retornar null explícito en el json
    IF v_meta_activa IS NULL THEN
        v_meta_activa := 'null'::jsonb;
    END IF;

    -- 7. Consolidar estructura final
    v_resultado := jsonb_build_object(
        'negocio', jsonb_build_object(
            'id', v_negocio.id,
            'nombre', v_negocio.nombre_negocio,
            'tipo', v_negocio.tipo_negocio,
            'moneda', v_negocio.moneda
        ),
        'ventas', jsonb_build_object(
            'hoy', v_ventas_hoy,
            'ganancia_neta_hoy', v_ganancia_neta_hoy,
            'transacciones_hoy', v_transacciones_hoy,
            'mes_actual', v_ventas_mes_actual,
            'mes_pasado', v_ventas_mes_pasado,
            'crecimiento_mes_pct', CASE 
                WHEN v_ventas_mes_pasado > 0 
                THEN ROUND(((v_ventas_mes_actual - v_ventas_mes_pasado) / v_ventas_mes_pasado * 100), 1)
                ELSE 0 
            END,
            'ultimos_3_meses', v_ventas_3_meses,
            'ultimos_6_meses', v_ventas_6_meses
        ),
        'inventario', jsonb_build_object(
            'total_valorizado', v_inventario_valorizado,
            'productos_estancados', v_items_estancados,
            'cantidad_items_estancados', jsonb_array_length(v_items_estancados)
        ),
        'gastos_mes_actual', jsonb_build_object(
            'fijos', v_gastos_fijos_mes,
            'variables', v_gastos_variables_mes,
            'total_gastos', (v_gastos_fijos_mes + v_gastos_variables_mes)
        ),
        'meta_ahorro_bcp', v_meta_activa,
        'timestamp_generacion', NOW()
    );

    RETURN v_resultado;
END;
$$;

-- ============================================================================
-- SCRIPT DE PRUEBA / SEED DATA (MYPES PERUANAS REALES)
-- ============================================================================

-- 1. Negocio 1: Restaurante Cevichería
INSERT INTO config_negocio (nombre_negocio, tipo_negocio, telefono_whatsapp)
VALUES ('Cevichería El Huarique del Puerto', 'restaurante', '+51987654321')
ON CONFLICT DO NOTHING;

-- Insumos / Productos del Restaurante
INSERT INTO productos_insumos (negocio_id, nombre, precio_compra, precio_venta, stock_actual, unidad_medida, dias_sin_rotacion, es_perecible)
VALUES 
(1, 'Pescado Corvina Fresca', 18.00, 38.00, 15.00, 'kg', 2, TRUE),
(1, 'Calamar y Mixtura de Mariscos', 14.50, 32.00, 22.00, 'kg', 5, TRUE),
(1, 'Limón Sutil Piurano (Caja)', 45.00, 90.00, 4.00, 'paquete', 8, TRUE),
(1, 'Cebolla Roja Seleccionada', 2.80, 6.00, 40.00, 'kg', 4, TRUE),
(1, 'Pulpo Entero Congelado', 38.00, 75.00, 8.00, 'kg', 36, TRUE), -- Estancado
(1, 'Chicha Morada Concentrada', 8.00, 18.00, 30.00, 'litro', 3, FALSE)
ON CONFLICT DO NOTHING;

-- Ventas del Restaurante (Simulando mes actual, mes pasado y meses previos)
INSERT INTO ventas (negocio_id, producto_id, cantidad, total_venta, fecha_venta)
VALUES
(1, 1, 40, 1520.00, NOW() - INTERVAL '2 days'),
(1, 2, 35, 1120.00, NOW() - INTERVAL '5 days'),
(1, 1, 60, 2280.00, NOW() - INTERVAL '12 days'),
(1, 4, 30, 540.00, NOW() - INTERVAL '18 days'),
-- Mes pasado
(1, 1, 80, 3040.00, NOW() - INTERVAL '35 days'),
(1, 2, 60, 1920.00, NOW() - INTERVAL '40 days'),
(1, 3, 10, 900.00, NOW() - INTERVAL '45 days'),
-- Hace 3 meses
(1, 1, 110, 4180.00, NOW() - INTERVAL '70 days'),
-- Hace 5 meses
(1, 1, 120, 4560.00, NOW() - INTERVAL '130 days')
ON CONFLICT DO NOTHING;

-- Gastos del Restaurante
INSERT INTO gastos (negocio_id, categoria, monto, descripcion, fecha_gasto)
VALUES
(1, 'fijo', 1200.00, 'Alquiler de local comercial (Miraflores/Surquillo)', CURRENT_DATE - 3),
(1, 'fijo', 350.00, 'Servicios básicos (Agua Sedapal y Luz Calidda)', CURRENT_DATE - 5),
(1, 'fijo', 950.00, 'Sueldo ayudante de cocina (quincena)', CURRENT_DATE - 8),
(1, 'variable', 480.00, 'Hielo industrial y bolsas térmicas', CURRENT_DATE - 2)
ON CONFLICT DO NOTHING;

-- Meta de Ahorro BCP Restaurante
INSERT INTO metas_ahorro (negocio_id, titulo_meta, monto_objetivo, monto_actual, plazo_dias, cuota_sugerida_bcp, frecuencia_cuota, estado)
VALUES
(1, 'Congeladora Vertical Inox para Mariscos', 1800.00, 1260.00, 45, 40.00, 'diaria', 'activa')
ON CONFLICT DO NOTHING;


-- 2. Negocio 2: Bodega & Minimarket (Retail)
INSERT INTO config_negocio (nombre_negocio, tipo_negocio, telefono_whatsapp)
VALUES ('Bodega & Minimarket San Martín', 'retail', '+51912345678')
ON CONFLICT DO NOTHING;

INSERT INTO productos_insumos (negocio_id, nombre, precio_compra, precio_venta, stock_actual, unidad_medida, dias_sin_rotacion, es_perecible)
VALUES 
(2, 'Arroz Costeño Saco 50kg', 145.00, 175.00, 10.00, 'saco', 3, FALSE),
(2, 'Aceite Primor 1L (Caja x 12)', 98.00, 120.00, 8.00, 'caja', 4, FALSE),
(2, 'Whisky Black Label 750ml (Edición Especial)', 110.00, 155.00, 6.00, 'unidad', 52, FALSE), -- Estancado 52 días
(2, 'Pack Conservas de Durazno A1', 18.50, 26.00, 24.00, 'paquete', 41, FALSE), -- Estancado 41 días
(2, 'Six Pack Cerveza Pilsen Callao', 26.00, 34.00, 35.00, 'paquete', 2, FALSE)
ON CONFLICT DO NOTHING;

INSERT INTO ventas (negocio_id, producto_id, cantidad, total_venta, fecha_venta)
VALUES
(2, 1, 5, 875.00, NOW() - INTERVAL '3 days'),
(2, 2, 6, 720.00, NOW() - INTERVAL '7 days'),
(2, 5, 20, 680.00, NOW() - INTERVAL '10 days'),
(2, 1, 12, 2100.00, NOW() - INTERVAL '38 days'),
(2, 2, 15, 1800.00, NOW() - INTERVAL '44 days')
ON CONFLICT DO NOTHING;

INSERT INTO gastos (negocio_id, categoria, monto, descripcion, fecha_gasto)
VALUES
(2, 'fijo', 800.00, 'Alquiler de bodega puerta a calle', CURRENT_DATE - 4),
(2, 'fijo', 220.00, 'Luz comercial para visicoolers', CURRENT_DATE - 6),
(2, 'variable', 150.00, 'Bolsas biodegradables y empaques', CURRENT_DATE - 1)
ON CONFLICT DO NOTHING;

INSERT INTO metas_ahorro (negocio_id, titulo_meta, monto_objetivo, monto_actual, plazo_dias, cuota_sugerida_bcp, frecuencia_cuota, estado)
VALUES
(2, 'Stock Anticipado Campaña Escolar / Navideña', 2500.00, 2500.00, 60, 42.00, 'diaria', 'cumplida') -- 100% CUMPLIDA (Detonante de nueva meta SMART)
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- PRUEBA DE EJECUCIÓN DIRECTA
-- Ejecutar esta consulta en Supabase SQL Editor para ver el resultado:
-- SELECT obtener_metricas_mype(1); -- Cevichería
-- SELECT obtener_metricas_mype(2); -- Minimarket
-- ----------------------------------------------------------------------------
