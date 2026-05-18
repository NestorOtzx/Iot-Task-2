# Integración de Lambda con DynamoDB

Esta sección del laboratorio se explorara cómo conectarse funciones AWS Lambda con Amazon DynamoDB. Se divide en dos enfoques de despliegue, organizados en las siguientes carpetas:

## Carpetas del Proyecto

### 1. `basic`
Contiene los ejemplos y recursos para realizar un despliegue de manera manual o a través de comandos básicos de AWS CLI. 
En este enfoque, el flujo típico es:
1. Crear la tabla en DynamoDB manualmente (ej: tabla `devices`, partition key: `id`).
2. Desplegar el código de las Lambdas (empaquetado y subida manual).
3. Probar las funciones.
4. Borrar los recursos manualmente al terminar: 
   `aws dynamodb delete-table --table-name devices`

### 2. `terraform`
Contiene una solución mucho más robusta y automatizada utilizando **Infraestructura como Código (IaC)**.
En esta carpeta encontrarás:
- Archivos `.tf` que aprovisionan automáticamente la tabla DynamoDB (`iot_events`), las funciones Lambda y los roles necesarios.
- Un simulador en Python que genera ráfagas de datos simulando dispositivos IoT reales.
- Un `Makefile` y scripts que automatizan el empaquetado de código y su inyección en la nube.
- Un patrón de arquitectura donde los datos pasan por una "Lambda de Ingesta" antes de llegar a la base de datos, y una "Lambda de Consulta" para extraer historiales basados en Partition Keys y Sort Keys.

*Nota: Para ver las instrucciones detalladas de la versión automatizada, se debe ingresar a la carpeta `terraform` y revisar su propio archivo README.*