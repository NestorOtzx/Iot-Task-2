# Docker AWS CLI para este proyecto

Usa estos comandos desde la carpeta raiz del proyecto. La carpeta actual se monta en `/app`, asi que cualquier archivo que crees o modifiques dentro del contenedor se vera tambien en esta carpeta.

## 1. Construir la imagen

```powershell
docker build -t iot_dev_environment_image .
```

## 2. Crear y abrir el contenedor en esta carpeta

Este comando monta este proyecto en `/app`, monta tus credenciales de AWS y conecta el cliente Docker del contenedor con el Docker del host.

```powershell
docker run --rm -it --name iot_dev_environment `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v ${PWD}:/app `
  -v ${env:USERPROFILE}\.aws:/root/.aws `
  -w /app `
  iot_dev_environment_image bash
```

## 3. Volver a entrar al contenedor si lo dejas corriendo

Si prefieres levantarlo en segundo plano:

```powershell
docker run -d --name iot_dev_environment `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v ${PWD}:/app `
  -v ${env:USERPROFILE}\.aws:/root/.aws `
  -w /app `
  iot_dev_environment_image tail -f /dev/null
```

Luego entra con:

```powershell
docker exec -it iot_dev_environment bash
```

## 4. Probar AWS CLI dentro del contenedor

Dentro del contenedor configura AWS manualmente:

```bash
aws configure
```

Luego prueba:

```bash
aws s3 ls
```

Para verificar que el contenedor tambien puede construir y subir imagenes Docker:

```bash
docker info
```
