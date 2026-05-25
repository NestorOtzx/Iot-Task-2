variable "project_name" { type = string }
variable "environment" { type = string }

variable "default_sensors" {
  description = "Sensores creados por defecto para que la ingesta IoT solo actualice sensores registrados."
  type = map(object({
    sensor_type = string
    description = string
  }))
  default = {
    "sensor-temp-01" = {
      sensor_type = "temperature"
      description = "Sensor de temperatura inicial del laboratorio Docker Compose"
    }
    "sensor-humidity-01" = {
      sensor_type = "humidity"
      description = "Sensor de humedad inicial del laboratorio Docker Compose"
    }
  }
}
