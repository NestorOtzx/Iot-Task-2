import os
import time
import json
import paho.mqtt.client as mqtt

MQTT_BROKER = os.getenv("MQTT_BROKER", "mosquitto")
MQTT_PORT = int(os.getenv("MQTT_PORT", 1883))
# Identificador único de este actuador
DEVICE_ID = "f_01"
TOPIC_SUB = f"cmd/+/fan/{DEVICE_ID}/turn_on"

client = mqtt.Client()

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    client.subscribe(TOPIC_SUB)
    print(f"Subscribed to COMMAND topic: {TOPIC_SUB}")

def on_message(client, userdata, msg):
    payload_str = msg.payload.decode()
    topic = msg.topic
    print(f"[FAN {DEVICE_ID}] Command received on {topic}: {payload_str}")
    
    # Extract farm_id from topic (cmd/<farm_id>/fan/<device_id>/turn_on)
    topic_parts = topic.split('/')
    farm_id = topic_parts[1] if len(topic_parts) > 1 else "unknown_farm"
    
    try:
        data = json.loads(payload_str)
        action = data.get("action")
        
        if action == "TURN_ON":
            print(f"[FAN {DEVICE_ID}] ---> ACTIVATING: Turning on the FAN now in farm: {farm_id}! <---")
        else:
            print(f"[FAN {DEVICE_ID}] Unknown action: {action}")
            
    except json.JSONDecodeError:
        print("[FAN] Error decoding command JSON")

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
