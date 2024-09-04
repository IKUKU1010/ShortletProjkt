provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "latest-ubuntu-jammy-22-04-image" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_launch_template" "eks" {
  name_prefix   = "eks-"
  image_id      = data.aws_ami.latest-ubuntu-jammy-22-04-image.id
  instance_type = "t2.micro"

  tag_specifications {
    resource_type = "instance"

    tags = {
      "Environment" = "Development"
      "Name"        = "eks-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "vpc" {
  source = "git::https://github.com/IKUKU1010/terraform-aws-vpc.git?ref=master"

  name                 = "shortlet-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1c"]
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets      = ["10.0.3.0/24", "10.0.4.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "Environment" = "Development"
    "Project"     = "shortlet"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true

  tags = {
    "Name"        = "nat-eip"
    "Environment" = "Development"
  }
}

resource "aws_nat_gateway" "custom_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = module.vpc.public_subnets[0]

  tags = {
    "Name"        = "custom-nat-gateway"
    "Environment" = "Development"
  }
}

resource "aws_security_group" "eks_sg" {
  name_prefix = "eks-sg-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name"        = "eks-sg"
    "Environment" = "Development"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "shortlet-CICD001"
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    work-node1 = {
      name           = "shortletapp-node1"
      launch_template = {
        id      = aws_launch_template.eks.id
        version = "$Latest"
      }
      instance_types = ["t2.micro"]
      min_size       = 1
      max_size       = 2
      desired_size   = 2
      key_name       = "Nkem-key" # Add your SSH key name here for access
      tags = {
        "Name"        = "shortletapp-node1"
        "Environment" = "Development"
      }
    }

    work-node2 = {
      name           = "shortletapp-node2"
      launch_template = {
        id      = aws_launch_template.eks.id
        version = "$Latest"
      }
      instance_types = ["t2.micro"]
      min_size       = 1
      max_size       = 2
      desired_size   = 2
      key_name       = "Nkem-key" # Add your SSH key name here for access
      tags = {
        "Name"        = "shortletapp-node2"
        "Environment" = "Development"
      }
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = {
    "Environment" = "Development"
    "Project"     = "shortlet"
  }
}
