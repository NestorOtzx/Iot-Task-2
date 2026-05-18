provider "aws" {
  region = "us-east-1"
}

# Reference the existing LabRole provided by AWS Learner Lab
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Create the DynamoDB table for IoT Events
resource "aws_dynamodb_table" "iot_events" {
  name           = "iot_events"
  billing_mode   = "PAY_PER_REQUEST" # Serverless billing, good for labs
  hash_key       = "device_id"
  range_key      = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

# Initial empty ZIP files for the lambdas so that the infrastructure can be created.
# Code can be updated later via AWS CLI as requested.
data "archive_file" "dummy_zip" {
  type        = "zip"
  output_path = "${path.module}/dummy.zip"

  source {
    content  = "def lambda_handler(event, context): pass"
    filename = "lambda_function.py"
  }
}

# Ingest Lambda Resource
resource "aws_lambda_function" "ingest_lambda" {
  function_name    = "iot_ingest_lambda"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  
  # Deploying dummy zip so code can be uploaded separately
  filename         = data.archive_file.dummy_zip.output_path
  source_code_hash = data.archive_file.dummy_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.iot_events.name
    }
  }
}

# Query Lambda Resource
resource "aws_lambda_function" "query_lambda" {
  function_name    = "iot_query_lambda"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  
  # Deploying dummy zip so code can be uploaded separately
  filename         = data.archive_file.dummy_zip.output_path
  source_code_hash = data.archive_file.dummy_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.iot_events.name
    }
  }
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.iot_events.name
}

output "ingest_function_name" {
  value = aws_lambda_function.ingest_lambda.function_name
}

output "query_function_name" {
  value = aws_lambda_function.query_lambda.function_name
}
