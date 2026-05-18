import os
import time
import json
import paho.mqtt.client as mqtt

MQTT_BROKER = os.getenv("MQTT_BROKER", "mosquitto")
MQTT_PORT = int(os.getenv("MQTT_PORT", 1883))
TOPIC_SUB = "data/+/sensor_temp/+/temperature"
# IDs de los actuadores destino: cada suscriptor manda al dispositivo concreto
HEATER_DEVICE_ID = "ht_01"
FAN_DEVICE_ID    = "f_01"

client = mqtt.Client()

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    client.subscribe(TOPIC_SUB)
    print(f"Subscribed to topic: {TOPIC_SUB}")

def on_message(client, userdata, msg):
    payload_str = msg.payload.decode()
    topic = msg.topic
    print(f"[TEMP-CONTROL] Received on {topic}: {payload_str}")
    
    # Extract farm_id from topic (format: data/<farm_id>/sensor_temp/<device_id>/temperature)
    topic_parts = topic.split('/')
    farm_id = topic_parts[1] if len(topic_parts) > 1 else "unknown_farm"
    
    try:
        data = json.loads(payload_str)
        temperature = data.get("temperature")
        
        if temperature is not None:
            if temperature < 15.0:
                # Tópico específico al heater ht_01 de la finca detectada
                cmd_topic = f"cmd/{farm_id}/heater/{HEATER_DEVICE_ID}/turn_on"
                print(f"[TEMP-CONTROL] CRITICAL COLD! {temperature}°C in {farm_id}. Sending TURN_ON to actuator {HEATER_DEVICE_ID} on {cmd_topic}")
                cmd_payload = json.dumps({"action": "TURN_ON", "reason": f"Temperature too low ({temperature}°C)"})
                client.publish(cmd_topic, cmd_payload)
            elif temperature > 30.0:
                # Tópico específico al fan f_01 de la finca detectada
                cmd_topic = f"cmd/{farm_id}/fan/{FAN_DEVICE_ID}/turn_on"
                print(f"[TEMP-CONTROL] CRITICAL HEAT! {temperature}°C in {farm_id}. Sending TURN_ON to actuator {FAN_DEVICE_ID} on {cmd_topic}")
                cmd_payload = json.dumps({"action": "TURN_ON", "reason": f"Temperature too high ({temperature}°C)"})
                client.publish(cmd_topic, cmd_payload)
            
    except json.JSONDecodeError:
        print("[TEMP-CONTROL] Error decoding JSON")

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
