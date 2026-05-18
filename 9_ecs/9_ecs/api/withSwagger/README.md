# API REST en ECS con API Gateway (Swagger / OpenAPI import)

Este proyecto despliega una aplicación FastAPI en un contenedor de AWS ECS (Fargate), balanceada a través de un Application Load Balancer (ALB). La gran diferencia de este ejemplo es que **las rutas de API Gateway se generan automáticamente a partir del esquema Swagger (OpenAPI)** de la aplicación FastAPI.

## Concepto Clave

En lugar de definir en Terraform ruta por ruta (`/users`, `/health`, etc.), seguimos este flujo:
1. **Extraemos el JSON de Swagger** directamente de la aplicación FastAPI (`app.openapi()`).
2. **Inyectamos extensiones de AWS** (`x-amazon-apigateway-integration`) en cada ruta usando Python. Estas extensiones le dicen al API Gateway hacia dónde redirigir el tráfico (hacia el ALB).
3. **Terraform toma ese JSON modificado** e importa todas las rutas al API Gateway `REST API` de un solo golpe usando el bloque `body`.

### ¿Por qué usar REST API (v1) en vez de HTTP API (v2)?
Aunque HTTP API es más moderno y barato, **REST API** tiene un soporte mucho más maduro para la importación nativa de Swagger, especialmente cuando se trata de mapear variables dinámicas en las URLs (por ejemplo `/users/{user_id}`).

## Despliegue Automatizado

Se ha preparado un script que orquesta todo el flujo de trabajo:
1. Crea un entorno virtual e instala FastAPI localmente.
2. Ejecuta `generate_swagger.py` (crea el archivo `openapi_with_extensions.json`).
3. Crea el repositorio en Amazon ECR si no existe.
4. Construye la imagen de Docker de la carpeta `api/` y le hace *push* a AWS ECR.
5. Ejecuta `terraform init` y `terraform apply` para levantar toda la infraestructura (VPC, ALB, ECS, API Gateway).

Solo se debe dar permisos de ejecución al script y correrlo:

```bash
chmod +x build_and_deploy.sh
./build_and_deploy.sh
```

## Estructura del Proyecto

- `api/`: Contiene el código fuente de la aplicación FastAPI, su Dockerfile y scripts como `generate_swagger.py` (que inyecta la integración con ALB) y `consume_api.py`.
- `terraform/`: Contiene toda la infraestructura como código (`main.tf`, `variables.tf`, `outputs.tf`, `security_groups.tf`). En `main.tf` se encuentra el recurso `aws_api_gateway_rest_api` que despliega el JSON del Swagger modificado.
- `build_and_deploy.sh` y `Makefile`: Scripts en la raíz que orquestan automáticamente todo el proceso de empaquetado y despliegue.

## Prueba de la API

Al finalizar el script, Terraform imprimirá el `api_gateway_url`. Puedes usarlo para consultar las rutas manualmente con curl:

Se ha provisto el script `api/consume_api.py` para probar todas las rutas automáticamente de forma ordenada. Ejecútenlo pasándole la URL de su API Gateway como argumento:

```bash
# Uso: python api/consume_api.py <API_GATEWAY_URL>
python api/consume_api.py https://xxxxxx.execute-api.us-east-1.amazonaws.com/prod
```

## Limpieza

Para eliminar los recursos de AWS y evitar cobros:
```bash
terraform destroy
```
*(Confirma con `yes` cuando se te pida).*

## Entendiendo `x-amazon-apigateway-integration`

El archivo `openapi_with_extensions.json` que se genera dinámicamente contiene una extensión específica de AWS en cada ruta de la API llamada `x-amazon-apigateway-integration`. Esta extensión le indica a API Gateway cómo debe conectarse exactamente con el backend (en este caso, el Application Load Balancer que apunta a los contenedores de ECS).

A continuación se explican sus parámetros clave:

- **`type`**: Define el tipo de integración. Al usar `http_proxy`, configuramos API Gateway para que pase la petición HTTP del cliente directamente al backend sin modificar la estructura (headers, body, query parameters), actuando como un intermediario o proxy transparente.
- **`httpMethod`**: Especifica el método HTTP (GET, POST, PUT, etc.) que API Gateway usará para enviar la petición al backend. Generalmente, es el mismo método de la solicitud original.
- **`uri`**: Es la dirección de destino a la que API Gateway enviará el tráfico. En nuestro caso, se configura dinámicamente como la URL de nuestro Load Balancer concatenada con el path de la ruta (ej. `http://${alb_dns_name}/users/{id}`).
- **`connectionType`**: Define cómo API Gateway se conecta al backend. Al utilizar `INTERNET`, indicamos que la conexión se realizará a través del internet público hacia el endpoint público del balanceador. (La alternativa común es `VPC_LINK` para backends privados sin salida a internet).
- **`passthroughBehavior`**: Controla cómo API Gateway maneja los body payloads (cuerpos de mensaje) de un `Content-Type` que no está mapeado explícitamente en la definición. El valor `when_no_match` le instruye dejar pasar (pass-through) la petición hacia el backend de todas formas, en lugar de bloquearla o devolver un error.
