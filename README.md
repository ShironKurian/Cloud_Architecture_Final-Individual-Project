# Terraform Infrastructure Project
Student ID: 8951881

## Project Overview
This project sets up a complete AWS infrastructure using Terraform, including:
- VPC with public and private subnets
- EC2 instances in both subnets
- Security groups for network access control
- S3 bucket for Terraform state management
- DynamoDB table for state locking

## Infrastructure Components

### Network Setup
- VPC with CIDR block 10.0.0.0/16
- Public subnet (10.0.1.0/24) in us-east-1a
- Private subnet (10.0.2.0/24) in us-east-1b
- Internet Gateway for public subnet access
- NAT Gateway for private subnet internet access

### Compute Resources
- Public EC2 instance (t2.micro) in public subnet
- Private EC2 instance (t2.micro) in private subnet
- Security groups configured for SSH and HTTP access

### State Management
- S3 bucket for Terraform state storage
- DynamoDB table for state locking
- Versioning enabled for state files
- Server-side encryption enabled

## Setup Instructions

1. Install Terraform
2. Configure AWS credentials
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Review the plan:
   ```bash
   terraform plan
   ```
5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Security Features
- SSH access restricted to specific IP
- HTTP access open to the world
- Private subnet instances protected by NAT
- S3 bucket with versioning and encryption
- State locking to prevent concurrent modifications

## Maintenance
- State files are automatically versioned
- Old state versions are retained for 30 days
- Infrastructure can be modified through Terraform
- State is stored securely in S3 with encryption

## Cleanup
To destroy the infrastructure:
```bash
terraform destroy
```

## Notes

- The S3 bucket name must be globally unique
- Ensure you have sufficient AWS permissions
- The infrastructure is designed to be within AWS Free Tier limits

## Troubleshooting

Common issues and solutions:
1. **Bucket already exists**: Choose a different bucket name
2. **Permission errors**: Verify AWS credentials and permissions
3. **State locking issues**: Check DynamoDB table configuration

## License

This project is licensed under the MIT License. 