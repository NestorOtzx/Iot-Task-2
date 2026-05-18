import sys
import requests
import json

def print_separator(title):
    print(f"\n{'='*50}")
    print(f"--- {title} ---")
    print(f"{'='*50}")

def main():
    if len(sys.argv) < 2:
        print("Uso: python consume_api.py <API_GATEWAY_URL>")
        print("Ejemplo: python consume_api.py https://xxxxxx.execute-api.us-east-1.amazonaws.com/prod")
        sys.exit(1)

    base_url = sys.argv[1].rstrip('/')

    print(f"Iniciando pruebas contra la API: {base_url}")

    # 1. Probar ruta raíz
    print_separator("Prueba GET /")
    try:
        response = requests.get(f"{base_url}/")
        print(f"Status Code: {response.status_code}")
        print("Respuesta:")
        try:
            print(json.dumps(response.json(), indent=2))
        except Exception:
            print(response.text)
    except Exception as e:
        print(f"Error en GET /: {e}")

    # 2. Probar Health Check
    print_separator("Prueba GET /health")
    try:
        response = requests.get(f"{base_url}/health")
        print(f"Status Code: {response.status_code}")
        print("Respuesta:")
        try:
            print(json.dumps(response.json(), indent=2))
        except Exception:
            print(response.text)
    except Exception as e:
        print(f"Error en GET /health: {e}")

    # 3. Probar obtener todos los usuarios
    print_separator("Prueba GET /users")
    try:
        response = requests.get(f"{base_url}/users")
        print(f"Status Code: {response.status_code}")
        print("Respuesta:")
        try:
            print(json.dumps(response.json(), indent=2))
        except Exception:
            print(response.text)
    except Exception as e:
        print(f"Error en GET /users: {e}")

    # 4. Probar obtener un usuario específico (Parámetro de ruta)
    print_separator("Prueba GET /users/1 (Path Parameter)")
    try:
        response = requests.get(f"{base_url}/users/1")
        print(f"Status Code: {response.status_code}")
        print("Respuesta:")
        try:
            print(json.dumps(response.json(), indent=2))
        except Exception:
            print(response.text)
    except Exception as e:
        print(f"Error en GET /users/1: {e}")

    # 5. Probar crear un nuevo usuario (POST)
    print_separator("Prueba POST /users")
    nuevo_usuario = {
        "nombre": "Carlos Lopez",
        "email": "carlos@example.com"
    }
    try:
        response = requests.post(f"{base_url}/users", json=nuevo_usuario)
        print(f"Status Code: {response.status_code}")
        print("Respuesta:")
        print(json.dumps(response.json(), indent=2))
    except Exception as e:
        print(f"Error en POST /users: {e}")

    # 6. Validar que el usuario se creó pidiendo todos los usuarios de nuevo
    print_separator("Prueba GET /users (Validar nuevo usuario)")
    try:
        response = requests.get(f"{base_url}/users")
        print(f"Status Code: {response.status_code}")
        print("Respuesta (Debería incluir a Carlos):")
        print(json.dumps(response.json(), indent=2))
    except Exception as e:
        print(f"Error en GET /users: {e}")

if __name__ == "__main__":
    main()
