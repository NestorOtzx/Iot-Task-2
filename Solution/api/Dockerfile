FROM python:3.12-slim

# Evita archivos .pyc y hace que los logs salgan inmediatamente hacia CloudWatch.
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Instala dependencias primero para aprovechar cache de Docker cuando solo cambia el codigo.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia la aplicacion FastAPI dentro de la imagen final.
COPY main.py .

EXPOSE 8000

# Uvicorn escucha en todas las interfaces para que ECS/ALB puedan enrutar trafico al contenedor.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
