"""
Módulo de Acceso a Datos - Supabase PostgreSQL con Soporte de Operaciones por Voz y Stub Yape
"""

import os
from typing import Dict, Any, Optional
from datetime import datetime
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")

_supabase_client: Optional[Client] = None

def get_supabase_client() -> Client:
    global _supabase_client
    if _supabase_client is None:
        if not SUPABASE_URL or not SUPABASE_KEY:
            raise ValueError("SUPABASE_URL y SUPABASE_KEY son requeridos.")
        _supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
    return _supabase_client

async def verify_yape_transaction(monto: float, referencia: str = "") -> Dict[str, Any]:
    """
    Función STUB para validación de Yape.
    Posteriormente consultará la API/Historial de Yape para validar la transacción.
    """
    print(f"[YAPE STUB] Verificando pago de S/{monto}...")
    return {
        "status": "pending_verification",
        "verified": False,
        "monto": monto,
        "referencia": referencia
    }

def get_business_metrics(negocio_id: int) -> Dict[str, Any]:
    supabase = get_supabase_client()

    try:
        rpc_response = supabase.rpc("obtener_metricas_mype", {"p_negocio_id": negocio_id}).execute()
        if rpc_response.data:
            return rpc_response.data
    except Exception as e:
        print(f"[Supabase RPC Fallback]: {e}")

    negocio_res = supabase.table("config_negocio").select("*").eq("id", negocio_id).execute()
    negocio = negocio_res.data[0] if negocio_res.data else {"id": negocio_id, "nombre_negocio": "Mi Negocio", "tipo_negocio": "retail"}

    now = datetime.utcnow()
    inicio_mes = datetime(now.year, now.month, 1)

    ventas = supabase.table("ventas").select("total_venta, fecha_venta").eq("negocio_id", negocio_id).execute().data or []
    v_actual = sum(float(x["total_venta"]) for x in ventas if datetime.fromisoformat(x["fecha_venta"].replace("Z", "+00:00")).replace(tzinfo=None) >= inicio_mes)

    prods = supabase.table("productos_insumos").select("*").eq("negocio_id", negocio_id).execute().data or []
    inv_val = sum(float(p.get("stock_actual", 0)) * float(p.get("precio_compra", 0)) for p in prods)
    estancados = [
        {"producto": p["nombre"], "stock": p["stock_actual"], "dias_sin_rotacion": p.get("dias_sin_rotacion", 0)}
        for p in prods if int(p.get("dias_sin_rotacion", 0)) >= 30
    ]

    gastos = supabase.table("gastos").select("*").eq("negocio_id", negocio_id).execute().data or []
    g_fijos = sum(float(g["monto"]) for g in gastos if g.get("categoria") == "fijo")
    g_vars = sum(float(g["monto"]) for g in gastos if g.get("categoria") == "variable")

    metas = supabase.table("metas_ahorro").select("*").eq("negocio_id", negocio_id).eq("estado", "activa").execute().data or []
    meta = metas[0] if metas else None

    return {
        "negocio": {"id": negocio.get("id", 1), "nombre": negocio.get("nombre_negocio", "Mi Negocio"), "tipo": negocio.get("tipo_negocio", "retail")},
        "ventas": {"mes_actual": v_actual},
        "inventario": {"total_valorizado": inv_val, "productos_estancados": estancados},
        "gastos_mes_actual": {"fijos": g_fijos, "variables": g_vars, "total_gastos": g_fijos + g_vars},
        "meta_ahorro_bcp": meta
    }

async def registrar_transaccion_voz(negocio_id: int, intent: Dict[str, Any]) -> Dict[str, Any]:
    """
    Ejecuta el registro en Supabase según la intención capturada por Gemini.
    """
    supabase = get_supabase_client()
    tipo = intent.get("tipo")
    metodo = intent.get("metodo_pago", "efectivo")
    monto = float(intent.get("monto") or 0.0)
    cantidad = int(intent.get("cantidad") or 1)
    producto_nombre = intent.get("producto")
    nombre_meta = intent.get("nombre_meta")

    resultado = {"status": "ok", "tipo": tipo}

    if tipo == "venta":
        # Registrar Venta
        supabase.table("ventas").insert({
            "negocio_id": negocio_id,
            "total_venta": monto,
            "metodo_pago": metodo,
            "estado_verificacion": "pendiente_yape" if metodo == "yape" else "aprobado"
        }).execute()

        # Descontar Stock
        if producto_nombre:
            try:
                supabase.rpc("decrementar_stock", {"p_negocio_id": negocio_id, "p_producto": producto_nombre, "p_cant": cantidad}).execute()
            except Exception as e:
                print(f"[Stock Decrement Error]: {e}")

        # Ejecutar verificación Yape si aplica
        if metodo == "yape":
            resultado["yape_verification"] = await verify_yape_transaction(monto)

    elif tipo == "compra":
        # Registrar Compra
        supabase.table("gastos").insert({
            "negocio_id": negocio_id,
            "monto": monto,
            "categoria": "inventario",
            "metodo_pago": metodo,
            "estado_verificacion": "pendiente_yape" if metodo == "yape" else "aprobado"
        }).execute()

        # Incrementar Stock
        if producto_nombre:
            try:
                supabase.rpc("incrementar_stock", {"p_negocio_id": negocio_id, "p_producto": producto_nombre, "p_cant": cantidad}).execute()
            except Exception as e:
                print(f"[Stock Increment Error]: {e}")

        if metodo == "yape":
            resultado["yape_verification"] = await verify_yape_transaction(monto)

    elif tipo == "meta":
        # Registrar aporte
        try:
            supabase.rpc("sumar_aporte_meta", {"p_negocio_id": negocio_id, "p_monto": monto, "p_nombre_meta": nombre_meta}).execute()
        except Exception as e:
            print(f"[Meta Aporte Error]: {e}")

    return resultado
