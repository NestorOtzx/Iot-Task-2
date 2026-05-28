import os
import time
import json
from datetime import datetime, timezone
import random
import paho.mqtt.client as mqtt

# Configuraciones desde variables de entorno
MQTT_HOST = os.environ.get("MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", 1883))
CLIENT_ID = os.environ.get("CLIENT_ID", f"sensor-{random.randint(1000,9999)}")
SENSOR_TYPE = os.environ.get("SENSOR_TYPE", "temperature") # temperature, humidity o cualquier tipo nuevo.
INTERVAL = int(os.environ.get("INTERVAL", 5))
SENSOR_MIN_VALUE = os.environ.get("SENSOR_MIN_VALUE")
SENSOR_MAX_VALUE = os.environ.get("SENSOR_MAX_VALUE")
SENSOR_UNIT = os.environ.get("SENSOR_UNIT")

TOPIC = "lab/sensors/data"


def _optional_float(value):
    """Convierte una variable opcional de entorno a float."""
    return float(value) if value is not None else None


def _sensor_range():
    """Resuelve el rango de simulacion segun variables de entorno o tipo conocido."""
    custom_min = _optional_float(SENSOR_MIN_VALUE)
    custom_max = _optional_float(SENSOR_MAX_VALUE)

    # Si el usuario define rango por entorno, este gana sobre los valores por defecto.
    if custom_min is not None and custom_max is not None:
        return custom_min, custom_max

    # Rangos conocidos para los sensores iniciales del laboratorio.
    if SENSOR_TYPE == "temperature":
        return 20.0, 35.0
    if SENSOR_TYPE == "humidity":
        return 40.0, 60.0

    # Fallback generico para cualquier sensor nuevo que se agregue en la sustentacion.
    return 0.0, 100.0


def _sensor_unit():
    """Devuelve la unidad configurada o una unidad por defecto para tipos conocidos."""
    if SENSOR_UNIT:
        return SENSOR_UNIT
    if SENSOR_TYPE == "temperature":
        return "C"
    if SENSOR_TYPE == "humidity":
        return "%"
    return "custom"

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f"[{CLIENT_ID}] Conectado exitosamente al broker local MQTT en {MQTT_HOST}:{MQTT_PORT}")
    else:
        print(f"[{CLIENT_ID}] Error al conectar. Código: {rc}")

def generate_sensor_data():
    """Genera un dato simulado para este sensor."""
    min_value, max_value = _sensor_range()
    value = round(random.uniform(min_value, max_value), 2)

    return {
        "device_id": CLIENT_ID,
        "sensor_type": SENSOR_TYPE,
        "value": value,
        "unit": _sensor_unit(),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

def main():
    print(f"[{CLIENT_ID}] Iniciando sensor tipo '{SENSOR_TYPE}'...")
    
    client = mqtt.Client(client_id=CLIENT_ID)
    client.on_connect = on_connect

    # Conexión sin TLS ya que es dentro de la red local de Docker
    while True:
        try:
            client.connect(MQTT_HOST, MQTT_PORT, 60)
            break
        except Exception as e:
            print(f"[{CLIENT_ID}] Esperando al broker MQTT {MQTT_HOST}:{MQTT_PORT}... Error: {e}")
            time.sleep(2)

    client.loop_start()

    try:
        count = 1
        while True:
            payload = generate_sensor_data()
            print(f"[{CLIENT_ID}] Publicando: {payload}")
            
            client.publish(TOPIC, json.dumps(payload), qos=1)
            count += 1
            time.sleep(INTERVAL)
            
    except KeyboardInterrupt:
        print(f"\n[{CLIENT_ID}] Deteniendo sensor...")
    finally:
        client.loop_stop()
        client.disconnect()
        print(f"[{CLIENT_ID}] Desconectado.")

if __name__ == '__main__':
    main()
