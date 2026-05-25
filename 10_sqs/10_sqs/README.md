# Implementación de Colas SQS en AWS (Lambda y ECS)

Este proyecto demuestra cómo implementar y consumir mensajes de **Amazon SQS (Simple Queue Service)** utilizando dos enfoques arquitectónicos diferentes, todo gestionado mediante Terraform.

## Arquitectura

La solución consiste en un script local en Python que envía mensajes en formato JSON a dos colas SQS distintas:
1. **`my-lambda-queue`**: Consumida de forma automática por una función AWS Lambda a través de un Event Source Mapping.
2. **`my-ecs-queue`**: Consumida mediante *Long Polling* por un contenedor de Docker ejecutándose en AWS ECS (Fargate).

![Arquitectura de SQS](/home/callanor01/.gemini/antigravity/brain/6a429874-c019-416b-8d15-61c5428e72a6/sqs_architecture_diagram_1778542335224.png)

Ambos consumidores procesan los mensajes y envían los registros (logs) directamente a **Amazon CloudWatch**.

---

## ¿Cómo funciona SQS? (Conceptos Clave)

Amazon SQS es un servicio de colas de mensajes administrado que permite desacoplar microservicios, sistemas distribuidos y aplicaciones serverless. Aquí están los conceptos clave utilizados en este laboratorio:

*   **Productor y Consumidor**: El productor (nuestro script local) envía mensajes a la cola. Los consumidores (Lambda o ECS) los leen para procesarlos.
*   **Retención de mensajes (`message_retention_seconds`)**: SQS guarda los mensajes durante un tiempo determinado (en nuestro caso, 24 horas) si nadie los procesa. El máximo permitido en AWS es de 14 días.
*   **Tiempo de Visibilidad (Visibility Timeout)**: Cuando un consumidor lee un mensaje, SQS lo "oculta" temporalmente para que otros consumidores no lo lean al mismo tiempo. Si el consumidor procesa el mensaje con éxito, debe enviar una señal para borrarlo definitivamente. Si el consumidor falla o se bloquea, el tiempo de visibilidad expira y el mensaje vuelve a aparecer en la cola.
*   **Polling (Short vs Long)**:
    *   *Short Polling*: El consumidor pregunta "¿hay mensajes?" y SQS responde inmediatamente, incluso si la cola está vacía. Genera muchas peticiones inútiles.
    *   *Long Polling*: El consumidor pregunta y SQS "mantiene la llamada en espera" hasta 20 segundos esperando a que llegue un mensaje. Esto ahorra muchísimo dinero y recursos computacionales (es lo que usamos en el script de ECS).

### Diferencia en el Consumo (Lambda vs ECS)
*   **Lambda (Event Source Mapping)**: Actúa como un supervisor automático. Lee los mensajes en lotes (batch) y activa la función. **Si tu código no falla, AWS borra el mensaje de SQS automáticamente por ti**.
*   **ECS (Código a la medida)**: Eres responsable de la lógica completa. El código Python hace el polling manualmente usando `boto3.receive_message()` y, lo más importante, **debes hacer explícitamente `sqs.delete_message()`** después de procesarlo, de lo contrario, el mensaje volverá a la cola.

---

## Guía de Ejecución

### Requisitos Previos
*   Tener `terraform` instalado en tu máquina.
*   Tener `docker` instalado y ejecutándose.
*   Tener configurado el AWS CLI (`aws configure`) con credenciales de Learner Lab.
*   Tener la librería de Python instalada: `pip install boto3`.

### 1. Despliegue de la Infraestructura
Desde la raíz de la carpeta `10_sqs`, ejecuta el orquestador principal:
```bash
make deploy
```
Esto construirá la imagen Docker, la subirá a ECR, empacará el código de la Lambda y aprovisionará toda la infraestructura en AWS (S3, IAM, SQS, ECS, Lambda, CloudWatch).

### 2. Probar y Enviar Mensajes
Puedes usar el script local en Python que descubre automáticamente las colas usando `boto3`.

Para enviar 1 mensaje a ambas colas:
```bash
python send_messages.py
```

Para enviar 5 mensajes únicamente a la cola de Lambda:
```bash
python send_messages.py --target lambda --count 5
```

Los mensajes se envían en un formato estructurado JSON.

### 3. Verificar los Resultados
Ingresa a la consola de AWS y dirígete a **CloudWatch > Grupos de registros (Log Groups)**:
*   Para Lambda, busca el log group: `/aws/lambda/SqsProcessorLambda`.
*   Para ECS, busca el log group: `/ecs/sqs-consumer`.

Allí verás el output de los consumidores recibiendo e imprimiendo el JSON.

### 4. Limpieza Total
Para destruir todo lo creado en AWS y no generar cobros:
```bash
make destroy
```

---

## Diferencias principales: AWS SQS vs RabbitMQ

Aunque ambos son sistemas de mensajería (Message Brokers), tienen filosofías y casos de uso muy diferentes:

| Característica | Amazon SQS | RabbitMQ |
| :--- | :--- | :--- |
| **Arquitectura** | Servicio 100% administrado (Serverless). No administras servidores. | Software que instalas y mantienes (en EC2, contenedores o clusters). |
| **Enrutamiento** | Muy básico. Un productor envía a una cola específica. (Si quieres routing complejo, debes usar AWS SNS + SQS). | Muy avanzado. Usa "Exchanges" para enrutar un mensaje a múltiples colas usando reglas, tópicos o *headers*. |
| **Escalabilidad** | Infinita y automática. AWS maneja la carga por ti sin límite de throughput. | Escalabilidad vertical u horizontal gestionada por ti. Requiere configurar clustering si el tráfico es masivo. |
| **Orden de Mensajes** | En SQS Estándar el orden **no está garantizado** (usa SQS FIFO si lo necesitas). | El orden está estrictamente garantizado (First-In, First-Out). |
| **Protocolos** | Se comunica vía API HTTP/HTTPS (SDK de AWS, REST). | Soporta múltiples protocolos de red abierta como AMQP, MQTT, STOMP. |
| **Mantenimiento** | Cero mantenimiento. Sólo pagas por petición (Pay-as-you-go). | Requiere mantenimiento de infraestructura, SO, parches, monitoreo de disco y RAM. |

**¿Cuándo usar cuál?**
*   Usa **SQS** si buscas simplicidad extrema, integración nativa y automática con el ecosistema de AWS (como invocar Lambdas), cero mantenimiento de infraestructura y una escalabilidad inmensa.
*   Usa **RabbitMQ** si tienes requerimientos agnósticos de la nube (multi-cloud u on-premise), necesitas protocolos específicos como AMQP, o requieres lógicas de enrutamiento de mensajes (routing) muy complejas e integradas en el mismo broker.
