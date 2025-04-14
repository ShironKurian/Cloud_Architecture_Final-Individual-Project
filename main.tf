terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote backend configuration is commented out for now.
  # When you want to use S3 for state storage and DynamoDB for state locking,
  # uncomment and update these lines accordingly.
  #
  # backend "s3" {
  #   bucket         = "skurian-terraform-state-2024-01"  # S3 bucket for storing Terraform state
  #   key            = "terraform.tfstate"                # The path within the bucket to store the state file
  #   region         = "us-east-1"                        # AWS region where the bucket is located
  #   dynamodb_table = "terraform-state-lock"             # DynamoDB table for state locking
  #   encrypt        = true                               # Enable encryption for the state file
  # }
}

provider "aws" {
  # AWS provider configuration. The region value is taken from a variable.
  region = var.aws_region
}

###############################################################################
# VPC Configuration
###############################################################################
# Create a new VPC with DNS support enabled.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true    # Enables DNS hostnames for instances in this VPC.
  enable_dns_support   = true    # Enables DNS resolution in the VPC.

  tags = {
    Name = "main-vpc"          # Tag the VPC for identification.
  }
}

###############################################################################
# Subnets
###############################################################################
# Public Subnet: Used for resources that need direct internet access.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr  # CIDR block for the public subnet.
  map_public_ip_on_launch = true                    # Assign a public IP to instances launched in this subnet.
  availability_zone       = var.availability_zone   # Specify the availability zone.

  tags = {
    Name = "public-subnet"                             # Tag for easier identification.
  }
}

# Private Subnet: Used for resources that don’t require direct internet access.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr     # CIDR block for the private subnet.
  availability_zone = var.private_availability_zone  # Private subnet located in a different availability zone.

  tags = {
    Name = "private-subnet"                             # Tag for identification.
  }
}

###############################################################################
# Internet Gateway and NAT Gateway
###############################################################################
# Internet Gateway: Enables internet access for the VPC.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"            # Tag the internet gateway.
  }
}

# Elastic IP for NAT Gateway: Provides a stable public IP address.
resource "aws_eip" "nat" {
  domain = "vpc"  # Specifies that the IP address is for use in a VPC.
}

# NAT Gateway: Allows instances in the private subnet to access the internet.
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id        # Uses the Elastic IP created above.
  subnet_id     = aws_subnet.public.id    # NAT gateway must be in a public subnet.

  tags = {
    Name = "nat-gateway"                 # Tag for identification.
  }

  depends_on = [aws_internet_gateway.main]  # Ensure IGW is created before the NAT gateway.
}

###############################################################################
# Route Tables and Associations
###############################################################################
# Public Route Table: Routes traffic to the internet via the IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                # Route all outbound traffic.
    gateway_id = aws_internet_gateway.main.id  # Traffic is sent to the IGW.
  }

  tags = {
    Name = "public-rt"                     # Tag for identification.
  }
}

# Private Route Table: Routes traffic to the internet via the NAT Gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"             # Route all outbound traffic.
    nat_gateway_id = aws_nat_gateway.nat.id    # Traffic from private subnet uses NAT.
  }

  tags = {
    Name = "private-rt"                    # Tag for identification.
  }
}

# Associate the public route table with the public subnet.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Associate the private route table with the private subnet.
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

###############################################################################
# Security Group
###############################################################################
# Security Group for EC2 instances to allow SSH, HTTP, and HTTPS access.
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  # Allow SSH access from a specific IP range.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ip]
  }

  # Allow HTTP access from anywhere.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS access from anywhere.
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"  # Tag for identification.
  }
}

###############################################################################
# EC2 Instances
###############################################################################
# Web Server: Deployed in the public subnet.
resource "aws_instance" "web" {
  ami                    = var.ami_id                   # AMI for the instance.
  instance_type          = var.instance_type            # Instance type (e.g., t2.micro).
  subnet_id              = aws_subnet.public.id         # Launch in the public subnet.
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]  # Attach the security group.

  tags = {
    Name = "web-server"               # Tag for easier identification.
  }
}

# Private Server: Deployed in the private subnet.
resource "aws_instance" "private" {
  ami                    = var.ami_id                   # AMI for the instance.
  instance_type          = var.instance_type            # Instance type (e.g., t2.micro).
  subnet_id              = aws_subnet.private.id        # Launch in the private subnet.
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]  # Attach the same security group.

  tags = {
    Name = "private-server"           # Tag to differentiate from the web server.
  }
}