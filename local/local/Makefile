.PHONY: up down logs logs-actuator logs-heater logs-fan clean

up:
	@echo "Levantando el entorno local de simulación IoT..."
	docker compose up -d --build
	@echo "Entorno iniciado. Usa 'make logs' para ver la salida de todos los servicios."
	@echo "O usa 'make logs-actuator' para ver solo la salida de la válvula de agua."

down:
	@echo "Deteniendo contenedores..."
	docker compose down
	@echo "Entorno detenido."

logs:
	docker compose logs -f

logs-actuator:
	docker compose logs -f actuator_water_valve

logs-heater:
	docker compose logs -f actuator_heater

logs-fan:
	docker compose logs -f actuator_fan

clean:
	@echo "Eliminando contenedores, volúmenes e imágenes del entorno..."
	docker compose down --volumes --rmi all
	@echo "Limpieza completa."
