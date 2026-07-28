# Root module wiring all sub-modules together for the "prod" environment.
# Run: terraform init && terraform plan && terraform apply

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "REPLACE_ME-terraform-state"
    key            = "springboot-eks-microservices/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_ME-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = "springboot-eks-microservices"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source       = "./vpc"
  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
  tags         = local.common_tags
}

module "iam" {
  source                      = "./iam"
  cluster_name                = var.cluster_name
  namespace                   = "microservices"
  oidc_provider_arn           = module.eks.oidc_provider_arn
  oidc_provider_url           = module.eks.oidc_provider_url
  ci_cd_trusted_principal_arn = var.ci_cd_trusted_principal_arn
  tags                        = local.common_tags
}

module "eks" {
  source                = "./eks"
  cluster_name          = var.cluster_name
  eks_cluster_role_arn  = module.iam.eks_cluster_role_arn
  eks_node_role_arn     = module.iam.eks_node_role_arn
  public_subnet_ids     = module.vpc.public_subnet_ids
  private_subnet_ids    = module.vpc.private_subnet_ids
  kms_key_arn           = var.kms_key_arn
  node_instance_types   = var.node_instance_types
  desired_size          = var.node_desired_size
  min_size              = var.node_min_size
  max_size              = var.node_max_size
  tags                  = local.common_tags
}

module "ecr" {
  source                  = "./ecr"
  allowed_principal_arns  = [module.iam.eks_node_role_arn, module.iam.ci_cd_role_arn]
  tags                    = local.common_tags
}

module "rds" {
  source                   = "./rds"
  cluster_name             = var.cluster_name
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  private_subnet_ids       = module.vpc.private_subnet_ids
  rds_monitoring_role_arn  = var.rds_monitoring_role_arn
  multi_az                 = var.environment == "prod"
  deletion_protection      = var.environment == "prod"
  tags                     = local.common_tags
}
