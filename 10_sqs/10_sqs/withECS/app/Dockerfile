FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY consumer.py .

# Run unbuffered so logs go straight to CloudWatch
CMD ["python", "-u", "consumer.py"]
