"""
Módulo Asesor IA - Procesamiento Multimodal y Síntesis de Voz
"""

import os
import json
from typing import Dict, Any, Tuple
from dotenv import load_dotenv

from google import genai
from google.genai import types
import edge_tts

load_dotenv()

GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
client = genai.Client(api_key=GEMINI_API_KEY)

MODEL_NAME = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
EDGE_TTS_VOICE = os.getenv("EDGE_TTS_VOICE", "es-PE-CamilaNeural")

SYSTEM_PROMPT_TEMPLATE = """Eres el Asesor Financiero e Inteligencia de Negocio para una MYPE peruana.

CONTEXTO ACTUAL DEL NEGOCIO:
{negocio_metrics_json}

INSTRUCCIONES DE CLASIFICACIÓN DE AUDIOS:
Analiza el audio del usuario y determina si se trata de:
1. VENTA: "He vendido [cantidad] [producto] a [monto] soles en [yape/efectivo]"
2. COMPRA: "He comprado [cantidad] [producto] a [monto] soles en [yape/efectivo] para inventario"
3. META: "He depositado [monto] soles para la meta [nombre_opcional]"
4. ASESORÍA / CONSULTA: Preguntas sobre finanzas o recomendación de metas.

FORMATO DE RESPUESTA OBLIGATORIO (JSON ESTRICTO):
{{
  "intent": {{
    "tipo": "venta | compra | meta | consulta",
    "producto": "nombre del producto o null",
    "cantidad": 1,
    "monto": 0.0,
    "metodo_pago": "yape | efectivo | null",
    "nombre_meta": "nombre de la meta o null"
  }},
  "respuesta_voz": "Texto empático y directo (máximo 2 párrafos) para responder al usuario en voz alta confirmando la transacción o brindando la asesoría."
}}
"""

def process_user_audio(audio_bytes: bytes, negocio_metrics: Dict[str, Any], mime_type: str = "audio/ogg") -> Tuple[Dict[str, Any], str]:
    metrics_json = json.dumps(negocio_metrics, indent=2, ensure_ascii=False)
    system_instruction = SYSTEM_PROMPT_TEMPLATE.format(negocio_metrics_json=metrics_json)

    audio_part = types.Part.from_bytes(data=audio_bytes, mime_type=mime_type)
    text_prompt = "Escucha el audio, clasifica la transacción en JSON y genera el texto de respuesta."

    response = client.models.generateContent(
        model=MODEL_NAME,
        contents=[audio_part, text_prompt],
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            response_mime_type="application/json"
        )
    )

    raw_text = (response.text or "").strip()

    try:
        data = json.loads(raw_text)
        intent = data.get("intent", {"tipo": "consulta"})
        respuesta_voz = data.get("respuesta_voz", "Transacción procesada correctamente.")
        return intent, respuesta_voz
    except Exception as e:
        print(f"[Gemini Parse Error]: {e}")
        return {"tipo": "consulta"}, raw_text or "No pude procesar el audio correctamente."

async def text_to_speech_edge(text: str, output_path: str = "response_audio.ogg") -> str:
    communicate = edge_tts.Communicate(text, voice=EDGE_TTS_VOICE)
    await communicate.save(output_path)
    return output_path
