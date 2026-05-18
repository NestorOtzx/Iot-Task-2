# AWS Lambda con DynamoDB (Caso de Uso IoT)

Este repositorio es un ejemplo ideal para ambientes educativos de **AWS Academy (Learner Lab)** que demuestra un caso de uso cercano a la realidad para Internet of Things (IoT). Un script externo (simulando un dispositivo físico como una Raspberry Pi) envía ráfagas de telemetría directamente a una tabla de Amazon DynamoDB para su posterior consulta y análisis a través de AWS Lambda.

## Arquitectura

1. **Infraestructura base por Terraform**: Despliega una tabla en DynamoDB llamada `iot_events` y dos funciones Lambda (`iot_ingest_lambda` e `iot_query_lambda`) inicialmente sin código real (usando un dummy zip).
2. **Simulador de Dispositivo** (`src/device_simulator/simulator.py`): Un script de Python externo a AWS que simula un sensor. Genera una ráfaga de 10 eventos (con temperatura y humedad aleatorias) y los envía a través de una invocación a la Lambda de Ingesta, pausando brevemente entre cada envío para emular telemetría en tiempo real.
3. **Lambda Ingest** (`src/ingest/lambda_function.py`): Función que actúa como API interna, recibe los eventos del simulador, los valida y los inserta en DynamoDB.
4. **Lambda Query** (`src/query/lambda_function.py`): Función desplegada en AWS que usaremos para consultar a la base de datos de DynamoDB por un `device_id` específico y traer el historial de eventos del dispositivo.

---

## Instrucciones de Uso

### 1. Desplegar Infraestructura (Terraform)
En nuestro modelo dinámico, vamos a crear los recursos (Tabla de DynamoDB y esqueleto de la Lambda) usando Terraform, referenciando a la regla requerida `LabRole` para Learner Lab:

1. Ve a la carpeta de terraform:
```bash
cd terraform
```

2. Inicializa Terraform:
```bash
terraform init
```

3. Validar plan:
```bash
terraform plan -out=project.tfplan
```

4. Ejecuta el plan y aplica:
```bash
terraform apply project.tfplan
```
*Este comando desplegará la tabla de DynamoDB y las funciones Lambda.*

### 2. Subir de manera independiente el código de las Lambdas (Zip)
Como fue solicitado, las lambdas se crearon vacías en la infraestructura inicial. Ahora inyectaremos el código a las funciones usando nuestro Makefile.

Empaquetar y desplegar el código para la función **Ingest**:
```bash
make ingest
```

Empaquetar y desplegar el código para la función **Query**:
```bash
make query
```

### 3. Prueba del Ciclo Completo

Primero, ir a la carpeta del simulador e instalar dependencias:
```bash
make venv
. venv/bin/activate
cd src/device_simulator
```

Ejecutar el simulador para invocar la Lambda de Ingesta y procesar los eventos hacia DynamoDB:
```bash
python simulator.py
```
*Verán en la consola cómo se generan y envían 10 eventos invocando a `iot_ingest_lambda`.*

A continuación, probarán la lectura. Invocarán la Lambda **Query** solicitando los datos del dispositivo `sensor-01` (vuelvan a la raíz o ejecuten este comando de AWS CLI en cualquier lugar donde estén logueados a AWS):

**Opción 1: Todos los eventos del dispositivo**
```bash
aws lambda invoke --function-name iot_query_lambda --cli-binary-format raw-in-base64-out --payload '{"device_id": "sensor-01"}' response_query.json
```

**Opción 2: Eventos desde una fecha específica (Range Key)**
Puedes copiar un timestamp del `response_query.json` e intentar filtrar desde ese momento en adelante:
```bash
aws lambda invoke --function-name iot_query_lambda --cli-binary-format raw-in-base64-out --payload '{"device_id": "sensor-01", "timestamp_start": "2024-01-01T00:00:00Z"}' response_query_range.json
```

Abre `response_query.json` o `response_query_range.json` y verán la lista de registros generados por su simulador local, retornados rápidamente gracias a la consulta por Partition Key (y Sort Key) en DynamoDB.

**Opción 3: Probar la Lambda localmente (Sin AWS CLI)**
También se preparó el código de la función Lambda de consulta para que pueda ejecutarse de forma local desde su máquina sin necesidad de usar comandos de AWS CLI. 
En otra terminal, ve a la carpeta raíz de terraform y ejecuta el script de la función pasándole Python directamente:
```bash
# Estando dentro del entorno virtual previamente activado (venv)
python src/query/lambda_function.py
```
*Esto ejecutará internamente varios casos de prueba definidos en el código, imprimiendo en consola los resultados directamente desde la tabla de DynamoDB.*

### 4. Verificar en la Consola de AWS (Opcional)
También pueden dirigirse a la consola de AWS -> **DynamoDB** -> **Tablas** -> `iot_events` -> **Explorar elementos de la tabla**. Ahí verán físicamente los eventos insertados con su timestamp correspondiente.

## Limpieza de recursos

Para destruir los recursos creados y no mantener basura en su laboratorio:
```bash
cd terraform
terraform destroy --auto-approve
```
