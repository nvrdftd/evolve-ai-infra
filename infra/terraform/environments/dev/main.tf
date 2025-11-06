terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Uncomment this block to use remote state (recommended for teams)
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "evolve-ai/aws-dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Owner = "Lung"
      Repository = "evolve-ai-infra"
    }
  }
}

# Get current AWS account information
data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  vpc_name             = "${var.project_name}-${var.environment}"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  single_nat_gateway   = var.single_nat_gateway
  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# EKS Cluster Module
module "eks" {
  source = "../../modules/eks-cluster"

  cluster_name       = "${var.project_name}-${var.environment}"
  kubernetes_version = var.kubernetes_version

  # VPC Configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  # Cluster Access Configuration
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_enabled_log_types            = var.cluster_enabled_log_types

  # General Node Group Configuration
  general_node_instance_types = var.general_node_instance_types
  general_node_desired_size   = var.general_node_desired_size
  general_node_min_size       = var.general_node_min_size
  general_node_max_size       = var.general_node_max_size

  # GPU Node Group Configuration
  enable_gpu_nodes        = var.enable_gpu_nodes
  gpu_node_instance_types = var.gpu_node_instance_types
  gpu_node_desired_size   = var.gpu_node_desired_size
  gpu_node_min_size       = var.gpu_node_min_size
  gpu_node_max_size       = var.gpu_node_max_size

  tags = {
    Name = "${var.project_name}-${var.environment}-eks"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
  }

  depends_on = [module.vpc]
}

# EKS Addons Module
module "eks_addons" {
  source = "../../modules/eks-addons"

  cluster_name       = module.eks.cluster_name
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url

  # Enable essential addons
  enable_ebs_csi_driver = true
  enable_vpc_cni        = true
  enable_coredns        = true
  enable_kube_proxy     = true

  depends_on = [module.eks]
}
