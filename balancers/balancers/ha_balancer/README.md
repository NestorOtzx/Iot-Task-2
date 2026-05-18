# Balanceador en Verdadera Alta Disponibilidad (Keepalived + HAProxy)

Este ejemplo demuestra cómo montar una arquitectura de Alta Disponibilidad **sin un único punto de fallo (SPOF)** mediante el protocolo VRRP con `Keepalived`.

En configuraciones anteriores, un balanceador principal (como Nginx) se encargaba de distribuir tráfico a otros balanceadores, pero si ese Nginx fallaba, todo el sistema dejaba de estar disponible.

## Arquitectura

1. **Virtual IP (VIP) - 10.25.0.100**: Es una única dirección IP a la que los clientes se conectan. Esta IP no está atada físicamente a ningún contenedor de forma permanente.
2. **Nodos Activo-Pasivo (Master/Backup)**: Tenemos dos contenedores idénticos (`haproxy_master` y `haproxy_backup`), cada uno corriendo `HAProxy` y `Keepalived` simultáneamente.
3. **Keepalived (VRRP)**: Se encarga de negociar quién tiene la VIP. El Master normalmente la retiene. Si el Master deja de enviar señales de vida (o si su proceso HAProxy muere), el Backup inmediatamente reclama la IP `10.25.0.100`.
4. **Servidores Web Backend (3 instancias)**: Servidores web mínimos.

## Cómo probar

1. Da permisos de ejecución a los scripts:
   ```bash
   chmod +x entrypoint.sh check_haproxy.sh
   ```

2. Construye e inicia el entorno:
   ```bash
   docker-compose up --build -d
   ```

3. Verifica que puedes acceder (haremos una petición desde un contenedor en la misma red hacia la IP virtual):
   ```bash
   docker run --rm --network ha_balancer_ha_net alpine curl -s http://10.25.0.100
   ```
   (El tráfico será dirigido por el Master hacia el Backend).

4. **Prueba de fallo (Failover Test)**:
   Mata o detén el contenedor master:
   ```bash
   docker stop haproxy_master
   ```

5. Vuelve a hacer la petición:
   ```bash
   docker run --rm --network ha_balancer_ha_net alpine curl -s http://10.25.0.100
   ```
   ¡Verás que sigue respondiendo! `haproxy_backup` detectó la falla instantáneamente y tomó control de la IP `10.25.0.100`.

6. Limpiar:
   ```bash
   docker-compose down
   ```
