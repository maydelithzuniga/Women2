"""
Servidor Principal FastAPI - Webhook de WhatsApp y Agente de Voz MYPE
"""

import os
import json
import logging
from dotenv import load_dotenv
import httpx
from fastapi import FastAPI, Request, Response, BackgroundTasks, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware

from database import get_business_metrics, get_supabase_client, registrar_transaccion_voz
from ai_advisor import process_user_audio, text_to_speech_edge

load_dotenv()
logger = logging.getLogger("mype_advisor")

app = FastAPI(title="MYPE WhatsApp Voice Advisor")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

WHATSAPP_TOKEN = os.getenv("WHATSAPP_TOKEN", "")
WHATSAPP_PHONE_NUMBER_ID = os.getenv("WHATSAPP_PHONE_NUMBER_ID", "")
WHATSAPP_VERIFY_TOKEN = os.getenv("WHATSAPP_VERIFY_TOKEN", "mype_voice_advisor_2025")
APP_BASE_URL = os.getenv("APP_BASE_URL", "https://tu-app.onrender.com")

@app.get("/health")
def health():
    return {"status": "ok", "agent": "WhatsApp Voice MYPE", "cost": "$0/month"}

@app.get("/")
def root():
    return {"status": "ok", "message": "MYPE WhatsApp Voice Advisor API is running"}

# CORRECCIÓN: Servir los audios generados a Meta (Evita Error 404)
@app.get("/audio/{filename}")
def get_audio(filename: str):
    file_path = os.path.join("/tmp", filename)
    if os.path.exists(file_path):
        return FileResponse(file_path, media_type="audio/ogg")
    raise HTTPException(status_code=404, detail="Archivo de audio no encontrado.")

# Endpoint de Verificación del Webhook para Meta
@app.get("/webhook")
def verify_webhook(request: Request):
    params = request.query_params
    if params.get("hub.mode") == "subscribe" and params.get("hub.verify_token") == WHATSAPP_VERIFY_TOKEN:
        return Response(content=params.get("hub.challenge"), media_type="text/plain")
    return Response(content="Error de verificación", status_code=403)

async def send_whatsapp_utility_template(to_phone: str, template_name: str, parameters: list, language_code: str = "es"):
    """
    Envía Plantillas de Utilidad (Utility Templates) de WhatsApp Cloud API.
    """
    headers = {"Authorization": f"Bearer {WHATSAPP_TOKEN}"}
    body_parameters = [{"type": "text", "text": str(p)} for p in parameters]

    send_payload = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": to_phone,
        "type": "template",
        "template": {
            "name": template_name,
            "language": {"code": language_code},
            "components": [{"type": "body", "parameters": body_parameters}]
        }
    }

    async with httpx.AsyncClient() as client:
        res = await client.post(
            f"https://graph.facebook.com/v20.0/{WHATSAPP_PHONE_NUMBER_ID}/messages",
            headers=headers,
            json=send_payload
        )
        return res.json()

async def handle_whatsapp_voice(msg: dict):
    from_phone = msg.get("from")
    if msg.get("type") not in ["audio", "voice"]:
        return
    media_id = (msg.get("audio") or msg.get("voice"))["id"]

    # 1. Descargar audio desde WhatsApp Cloud API
    meta_url = f"https://graph.facebook.com/v20.0/{media_id}"
    headers = {"Authorization": f"Bearer {WHATSAPP_TOKEN}"}
    async with httpx.AsyncClient() as client:
        res = await client.get(meta_url, headers=headers)
        file_url = res.json().get("url")
        audio_data = (await client.get(file_url, headers=headers)).content

    # 2. Consultar métricas del negocio
    supabase = get_supabase_client()
    neg_res = supabase.table("config_negocio").select("id").eq("telefono_whatsapp", from_phone).execute()
    negocio_id = neg_res.data[0]["id"] if neg_res.data else 1
    metrics = get_business_metrics(negocio_id)

    # 3. Analizar audio con Gemini (Obtener Intent + Texto para sintetizar)
    intent, advisor_text = process_user_audio(audio_data, metrics, mime_type="audio/ogg")

    # 4. Registrar en Base de Datos & Ejecutar verificación Yape si aplica
    if intent.get("tipo") in ["venta", "compra", "meta"]:
        await registrar_transaccion_voz(negocio_id, intent)

    # 5. Sintetizar Audio de respuesta con Edge-TTS
    out_filename = f"response_{media_id}.ogg"
    out_filepath = os.path.join("/tmp", out_filename)
    await text_to_speech_edge(advisor_text, out_filepath)

    # 6. Enviar respuesta por voz a WhatsApp
    audio_public_url = f"{APP_BASE_URL}/audio/{out_filename}"
    send_payload = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": from_phone,
        "type": "audio",
        "audio": {"link": audio_public_url}
    }
    async with httpx.AsyncClient() as client:
        await client.post(
            f"https://graph.facebook.com/v20.0/{WHATSAPP_PHONE_NUMBER_ID}/messages",
            headers=headers,
            json=send_payload
        )

@app.post("/webhook")
async def webhook(request: Request, bg: BackgroundTasks):
    body = await request.json()
    for entry in body.get("entry", []):
        for change in entry.get("changes", []):
            for msg in change.get("value", {}).get("messages", []):
                bg.add_task(handle_whatsapp_voice, msg)
    return {"status": "ok"}
