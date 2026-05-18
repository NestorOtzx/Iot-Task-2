#!/bin/bash

# Script to package and deploy a Lambda function

# Set variables (adjust these as needed)
# FUNCTION_NAME will be passed as a parameter
RUNTIME="python3.12"
ROLE_ARN="arn:aws:iam::096833589249:role/LabRole"  # Replace with your actual Role ARN
HANDLER="lambda_function.lambda_handler"
ZIP_FILE="lambda_function.zip"
REQUIREMENTS_FILE="requirements.txt"

# Check if FUNCTION_NAME is provided as a parameter
if [ -z "$1" ]; then
  echo "Error: Function name must be provided as a parameter."
  echo "Usage: $0 <function_name>"
  exit 1
fi

FUNCTION_NAME="$1"

# Create the package directory
echo "Creating package directory..."
mkdir package

# Install dependencies into the package directory
echo "Installing dependencies..."
pip3 install -r $REQUIREMENTS_FILE -t ./package

# Create the ZIP file
echo "Creating ZIP file..."
cd package
zip -r ../$ZIP_FILE .
cd ..

# Include the lambda function source code in the zip
echo "Adding lambda function code to ZIP file..."
zip $ZIP_FILE lambda_function.py

# List the contents of the ZIP file (for verification)
echo "Listing ZIP file contents..."
unzip -l $ZIP_FILE

# Update or create the Lambda function
if aws lambda get-function --function-name $FUNCTION_NAME > /dev/null 2>&1; then
  echo "Updating existing Lambda function..."
  aws lambda update-function-code --function-name $FUNCTION_NAME --zip-file fileb://$ZIP_FILE 
else
  echo "Creating new Lambda function..."
  aws lambda create-function \
      --function-name $FUNCTION_NAME \
      --runtime $RUNTIME \
      --role $ROLE_ARN \
      --handler $HANDLER \
      --zip-file fileb://$ZIP_FILE
fi

echo "Lambda deployment complete."