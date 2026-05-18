# Obtener información de la cuenta de AWS (ID, ARN)
data "aws_caller_identity" "current" {}

# Obtener el LabRole preexistente del AWS Learner Lab
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
