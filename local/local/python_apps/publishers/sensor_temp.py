import os
import time
import json
import random
import paho.mqtt.client as mqtt

MQTT_BROKER = os.getenv("MQTT_BROKER", "mosquitto")
MQTT_PORT = int(os.getenv("MQTT_PORT", 1883))
TOPIC = "data/finca_norte/sensor_temp/t_01/temperature"

client = mqtt.Client()

def connect_mqtt():
    while True:
        try:
            print(f"Connecting to {MQTT_BROKER}:{MQTT_PORT}...")
            client.connect(MQTT_BROKER, MQTT_PORT, 60)
            print("Connected successfully!")
            break
        except Exception as e:
            print(f"Connection failed: {e}. Retrying in 5 seconds...")
            time.sleep(5)

if __name__ == "__main__":
    connect_mqtt()
    client.loop_start()
    
    while True:
        temp = round(random.uniform(20.0, 35.0), 2)
        payload = json.dumps({
            "farm_id": "finca_norte", 
            "device_type": "sensor_temp",
            "device_id": "t_01", 
            "temperature": temp
        })
        
        print(f"Publishing to {TOPIC}: {payload}")
        client.publish(TOPIC, payload)
        
        time.sleep(5)
