#!/bin/bash

# Iniciar Keepalived en el background
keepalived -n -l -D &

# Iniciar HAProxy en el foreground usando el archivo de configuración mapeado
haproxy -f /etc/haproxy/haproxy.cfg
