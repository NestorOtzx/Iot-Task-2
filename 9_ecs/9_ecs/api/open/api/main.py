from fastapi import FastAPI

app = FastAPI(title="Mi API en ECS")

@app.get("/")
def read_root():
    return {"mensaje": "¡Hola desde FastAPI corriendo en AWS ECS y Fargate!"}

@app.get("/health")
def health_check():
    return {"status": "ok"}
