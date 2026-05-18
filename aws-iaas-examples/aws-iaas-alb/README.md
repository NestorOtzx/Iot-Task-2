# 1. Get the vpc, subnetId and AZ
aws ec2 describe-subnets --query "Subnets[*].[SubnetId, VpcId, AvailabilityZone]" --output text

# 2. Replace in main.tf:
- vpc_id and subnet_id with values from step 1
- key_name with your the name of your key pair

# 3. Init with open tofu or terraform
## With terraform
terraform init
terraform plan -out=alb.tfplan
terraform apply alb.tfplan
terraform destroy

## With opentofu
tofu init
tofu plan -out=alb.tfplan
tofu apply alb.tfplan
tofu destroy

# 4. delete all
rm -rf .terraform .terraform.lock.hcl alb.tfplan terraform.tfstate terraform.tfstate.backup


