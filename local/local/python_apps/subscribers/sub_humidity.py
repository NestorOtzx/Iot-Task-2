import os
import time
import json
import paho.mqtt.client as mqtt

MQTT_BROKER = os.getenv("MQTT_BROKER", "mosquitto")
MQTT_PORT = int(os.getenv("MQTT_PORT", 1883))
TOPIC_SUB = "data/+/sensor_humidity/+/humidity"
# ID del actuador destino: solo este water_valve recibirá el comando
WATER_VALVE_DEVICE_ID = "v_01"

client = mqtt.Client()

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    client.subscribe(TOPIC_SUB)
    print(f"Subscribed to topic: {TOPIC_SUB}")

def on_message(client, userdata, msg):
    payload_str = msg.payload.decode()
    topic = msg.topic
    print(f"[HUMIDITY-CONTROL] Received on {topic}: {payload_str}")
    
    # Extract farm_id from topic (format: data/<farm_id>/sensor_humidity/<device_id>/humidity)
    topic_parts = topic.split('/')
    farm_id = topic_parts[1] if len(topic_parts) > 1 else "unknown_farm"
    
    try:
        data = json.loads(payload_str)
        humidity = data.get("humidity")
        
        # Porcentaje de humedad relativa (RH)
        if humidity is not None and humidity < 30.0:
            # Tópico específico al actuador v_01 de la finca detectada
            cmd_topic = f"cmd/{farm_id}/water_valve/{WATER_VALVE_DEVICE_ID}/open"
            print(f"[HUMIDITY-CONTROL] CRITICAL! {humidity}% in {farm_id}. Sending OPEN to actuator {WATER_VALVE_DEVICE_ID} on {cmd_topic}")
            cmd_payload = json.dumps({"action": "OPEN", "reason": f"Humidity too low ({humidity}%)"})
            client.publish(cmd_topic, cmd_payload)
            
    except json.JSONDecodeError:
        print("[HUMIDITY-CONTROL] Error decoding JSON")

client.on_connect = on_connect
client.on_message = on_message

def connect_mqtt():
    while True:
        try:
            print(f"Connecting to {MQTT_BROKER}:{MQTT_PORT}...")
            client.connect(MQTT_BROKER, MQTT_PORT, 60)
            break
        except Exception as e:
            print(f"Connection failed: {e}. Retrying in 5 seconds...")
            time.sleep(5)

if __name__ == "__main__":
    connect_mqtt()
    client.loop_forever()
