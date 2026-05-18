import sys
import requests

def test_api(base_url: str):
    # Asegurarnos que no termine en '/'
    if base_url.endswith("/"):
        base_url = base_url[:-1]

    print(f"Probando la API en: {base_url}\n")
    
    # 1. Probar el endpoint raíz
    print("--- 1. Probando el endpoint principal (GET /) ---")
    try:
        response = requests.get(f"{base_url}/")
        print(f"Status Code: {response.status_code}")
        print("Respuesta:")
        print(response.json())
    except Exception as e:
        print(f"Error al conectar con la API: {e}")

    print("\n")
    
    # 2. Probar el endpoint de Health Check
    print("--- 2. Probando el Health Check (GET /health) ---")
    try:
        response = requests.get(f"{base_url}/health")
        print(f"Status Code: {response.status_code}")
        print("Respuesta:")
        print(response.json())
    except Exception as e:
        print(f"Error al conectar con la API: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python invoke_api.py <API_GATEWAY_URL>")
        print("Ejemplo: python invoke_api.py https://xxxxx.execute-api.us-east-1.amazonaws.com")
        sys.exit(1)
        
    api_url = sys.argv[1]
    test_api(api_url)
