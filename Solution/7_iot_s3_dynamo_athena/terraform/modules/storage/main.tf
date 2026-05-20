resource "random_id" "id" {
  byte_length = 4
}

resource "aws_s3_bucket" "sensor_data" {
  bucket        = "${var.environment}-${var.project_name}-sensor-data-${random_id.id.hex}"
  force_destroy = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket" "athena_results" {
  bucket        = "${var.environment}-${var.project_name}-athena-results-${random_id.id.hex}"
  force_destroy = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Base de datos logica de Athena/Glue para consultar el historico JSON de sensores.
# Reemplazamos guiones por underscores porque los nombres SQL son mas comodos asi.
resource "aws_glue_catalog_database" "iot_analytics" {
  name = replace("${var.project_name}_${var.environment}_analytics", "-", "_")
}

# Tabla externa de Athena sobre los objetos JSON generados por la regla IoT hacia S3.
# Usa proyeccion de particiones para evitar ejecutar MSCK REPAIR TABLE cada vez que llega un nuevo dia.
resource "aws_glue_catalog_table" "sensor_data" {
  name          = "sensor_data"
  database_name = aws_glue_catalog_database.iot_analytics.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL                    = "TRUE"
    classification              = "json"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2020,2035"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.month.digits"   = "2"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.day.digits"     = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.sensor_data.bucket}/data/year=$${year}/month=$${month}/day=$${day}/"
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.sensor_data.bucket}/data/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    columns {
      name = "device_id"
      type = "string"
    }

    columns {
      name = "sensor_type"
      type = "string"
    }

    columns {
      name = "value"
      type = "double"
    }

    columns {
      name = "timestamp"
      type = "string"
    }

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }
  }
}
