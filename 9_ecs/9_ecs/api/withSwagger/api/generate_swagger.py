import json
import os
import sys

# Añadir el directorio 'api' al path para poder importar 'main'
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

try:
    from main import app
except ImportError as e:
    print(f"Error importando la app FastAPI: {e}")
    sys.exit(1)

def generate_openapi_with_aws_extensions():
    # Extraer el esquema OpenAPI puro generado por FastAPI
    openapi_schema = app.openapi()

    # Añadir la versión de OpenAPI (API Gateway a veces prefiere 3.0.1)
    openapi_schema["openapi"] = "3.0.1"

    # Recorrer todos los paths y métodos para inyectar la configuración de AWS
    paths = openapi_schema.get("paths", {})
    for path, methods in paths.items():
        for method, operation in methods.items():
            
            # Crear la integración de API Gateway apuntando a la variable de Terraform ${alb_dns_name}
            # OJO: API Gateway requiere que la URI contenga el path completo
            integration_uri = f"http://${{alb_dns_name}}{path}"
            
            integration = {
                "type": "http_proxy",
                # El método HTTP con el que API Gateway se comunicará con el Backend (ALB)
                "httpMethod": method.upper(),
                "uri": integration_uri,
                "connectionType": "INTERNET",
                "passthroughBehavior": "when_no_match"
            }

            # Si la ruta tiene parámetros (ej. /users/{user_id}), necesitamos mapearlos explícitamente 
            # para que API Gateway los pase al Load Balancer.
            request_parameters = {}
            if "parameters" in operation:
                for param in operation["parameters"]:
                    if param.get("in") == "path":
                        param_name = param["name"]
                        # Mapear el path parameter entrante hacia el path parameter saliente
                        request_parameters[f"integration.request.path.{param_name}"] = f"method.request.path.{param_name}"
            
            if request_parameters:
                integration["requestParameters"] = request_parameters

            # Inyectar la extensión en la operación
            operation["x-amazon-apigateway-integration"] = integration

    # Guardar el JSON modificado
    output_file = "openapi_with_extensions.json"
    with open(output_file, "w") as f:
        json.dump(openapi_schema, f, indent=2)
    
    print(f"Swagger con extensiones de AWS generado exitosamente en: {output_file}")

if __name__ == "__main__":
    generate_openapi_with_aws_extensions()
