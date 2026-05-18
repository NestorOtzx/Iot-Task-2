# 1. Get the vpc, subnetId and AZ
aws ec2 describe-subnets --query "Subnets[*].[SubnetId, VpcId, AvailabilityZone]" --output text

# 2. Replace in main.tf:
- vpc_id and subnet_id with values from step 1
- key_name with your the name of your key pair

# 3. Init with open tofu or terraform
## With terraform
terraform init
terraform plan -out=project.tfplan
terraform apply project.tfplan
terraform destroy

## With opentofu
tofu init
tofu plan -out=project.tfplan
tofu apply project.tfplan
tofu destroy

# 4. delete all
rm -rf .terraform .terraform.lock.hcl project.tfplan terraform.tfstate terraform.tfstate.backup

# 5. Apply only one resource
- RabbitMQ tofu apply -target=aws_instance.rabbitmq
- EC2 API tofu apply -target=aws_instance.api_server
- Security Group del worker tofu apply -target=aws_security_group.worker_sg
- Parámetro SSM del worker tofu apply -target=aws_ssm_parameter.worker_ip


# 6. To see only the plan for individual resource
tofu plan -target=aws_instance.rabbitmq
# Apply only that resource
tofu apply -target=aws_instance.rabbitmq


# 7. Test
## RabbitMQ:
http://[IP_RABBITMQ]:15672/

## MongoDB
Connect with mongodb using your preferred database manager.

## Balancer
http://[IP_BALANCER]/health

## PostgreSQL Only for IoT course
Connect with postgresql using your preferred database manager.



