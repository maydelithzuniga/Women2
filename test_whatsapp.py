"""
Script de Prueba Directa de WhatsApp Cloud API
Permite verificar credenciales y enviar un mensaje de prueba real a tu celular.

Uso:
  python test_whatsapp.py --to 51987654321
"""

import os
import sys
import argparse
import httpx
from dotenv import load_dotenv

load_dotenv()

WHATSAPP_TOKEN = os.getenv("WHATSAPP_TOKEN", "")
WHATSAPP_PHONE_NUMBER_ID = os.getenv("WHATSAPP_PHONE_NUMBER_ID", "")


def send_test_message(to_phone: str, text: str = None):
    if not WHATSAPP_TOKEN or not WHATSAPP_PHONE_NUMBER_ID:
        print("\n❌ ERROR: Falta configurar WHATSAPP_TOKEN o WHATSAPP_PHONE_NUMBER_ID en tu archivo .env")
        print("Obtén estos valores en: https://developers.facebook.com > Tu App > WhatsApp > Configuración de la API\n")
        return False

    url = f"https://graph.facebook.com/v20.0/{WHATSAPP_PHONE_NUMBER_ID}/messages"
    headers = {
        "Authorization": f"Bearer {WHATSAPP_TOKEN}",
        "Content-Type": "application/json"
    }

    message_body = text or (
        "🇵🇪 *Asesor Financiero MYPE - BCP*\n\n"
        "¡Conexión exitosa con WhatsApp Cloud API!\n"
        "Tu agente de voz está listo para escuchar y analizar tus ventas, inventario y metas Guardaditos BCP a costo $0."
    )

    payload = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": to_phone.replace("+", "").replace(" ", ""),
        "type": "text",
        "text": {"body": message_body}
    }

    print(f"📡 Enviando mensaje de prueba a {to_phone}...")
    with httpx.Client(timeout=15.0) as client:
        response = client.post(url, headers=headers, json=payload)
        
        if response.status_code in [200, 201]:
            print(f"✅ ¡Mensaje enviado con éxito! ID: {response.json().get('messages', [{}])[0].get('id')}")
            return True
        else:
            print(f"❌ Error al enviar ({response.status_code}): {response.text}")
            return False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Probar conexión con WhatsApp")
    parser.add_argument("--to", required=True, help="Número de celular con código de país (ej: 51987654321)")
    parser.add_argument("--text", required=False, help="Texto personalizado a enviar")
    args = parser.parse_args()

    send_test_message(args.to, args.text)
