## HAProxy Algorithms

HAProxy soporta varios algoritmos de balanceo en la sección backend. 

1. roundrobin (El actual)
**Cómo funciona:** Distribuye las peticiones de forma secuencial entre los servidores.
**Uso:** Es el estándar para servidores con capacidades similares y aplicaciones sin estado (stateless). Soporta pesos (weights) para dar más carga a ciertos servidores.

2. leastconn
**Cómo funciona:** Envía la nueva petición al servidor que tiene menos conexiones activas en ese momento.
**Uso:** Ideal para sesiones largas (como bases de datos o WebSockets), ya que evita saturar un servidor si algunas conexiones tardan mucho en cerrarse.

3. source
**Cómo funciona:** Realiza un hash de la dirección IP del cliente. Esto asegura que un mismo usuario siempre llegue al mismo servidor (mientras el número de servidores no cambie).
**Uso:** Útil cuando necesitas persistencia de sesión (Session Stickiness) y no puedes usar cookies.

4. first
**Cómo funciona:** Envía todas las peticiones al primer servidor disponible hasta que alcanza su capacidad máxima (maxconn), y solo entonces pasa al siguiente.
**Uso:** Útil para ahorrar costos en la nube (puedes apagar los servidores que están al final de la lista si no hay mucho tráfico).

5. uri
**Cómo funciona:** Balancea basándose en la parte de la URL (el URI).
**Uso:** Excelente para servidores de caché (Proxy Cache), ya que asegura que una misma imagen o archivo siempre se pida al mismo servidor, mejorando la tasa de aciertos de la caché.
