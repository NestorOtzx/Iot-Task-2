from fastapi import FastAPI, HTTPException

app = FastAPI(
    title="API con Swagger en ECS",
    description="Esta API demuestra cómo usar Swagger para crear rutas en API Gateway",
    version="1.0.0"
)

# Base de datos simulada
db_users = {
    "1": {"id": "1", "nombre": "Juan Perez", "email": "juan@example.com"},
    "2": {"id": "2", "nombre": "Maria Gomez", "email": "maria@example.com"}
}

@app.get("/")
def read_root():
    return {"mensaje": "¡Hola desde FastAPI en ECS configurado vía Swagger!"}

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/users", tags=["Users"])
def get_users():
    return {"users": list(db_users.values())}

@app.get("/users/{user_id}", tags=["Users"])
def get_user(user_id: str):
    user = db_users.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return user

@app.post("/users", tags=["Users"])
def create_user(user: dict):
    new_id = str(len(db_users) + 1)
    user["id"] = new_id
    db_users[new_id] = user
    return {"mensaje": "Usuario creado", "user": user}
