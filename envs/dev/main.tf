# ZenPharma Dev Environment — managed via GitHub Actions CI/CD
locals {
  project = "pharma"
  env     = "dev"
  region  = "us-east-1"
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../modules/vpc"

  project               = local.project
  env                   = local.env
  region                = local.region
  vpc_cidr              = "10.1.0.0/16"
  public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs  = ["10.1.3.0/24", "10.1.4.0/24"]
  database_subnet_cidrs = ["10.1.5.0/24", "10.1.6.0/24"]
}

# Query the IAM Role directly from AWS IAM API by its name
data "aws_iam_role" "github_actions_ci" {
  name = "zenpharma-dev-github-actions-role"
}

module "eks" {
  source = "../../modules/eks"

  project            = local.project
  env                = local.env
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  kubernetes_version = "1.33"
  instance_types     = ["t3.small"]
  min_size           = 1
  max_size           = 3
  desired_size       = 2

  access_entries = {
    # 1. Human Identity Center SSO
    sso_admin = {
      principal_arn = "arn:aws:iam::650032249451:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_6b0a9fa820943c11"
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    # 2. Application CI Role from Bootstrap
    github_actions_ci = {
      principal_arn = data.aws_iam_role.github_actions_ci.arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

module "rds" {
  source = "../../modules/rds"

  project                    = local.project
  env                        = local.env
  username                   = "pharmaadmin"
  password                   = var.db_password
  vpc_id                     = module.vpc.vpc_id
  db_subnet_group_name       = module.vpc.database_subnet_group_name
  eks_node_security_group_id = module.eks.node_security_group_id
}

module "ecr" {
  source = "../../modules/ecr"

  project = local.project
  env     = local.env
  repositories = [
    "api-gateway",
    "auth-service",
    "drug-catalog-service",
    "inventory-service",
    "manufacturing-service",
    "notification-service",
    "pharma-ui",
    "supplier-service",
    "qc-service",
  ]
}

module "iam" {
  source = "../../modules/iam"

  project           = local.project
  env               = local.env
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url
  aws_account_id    = data.aws_caller_identity.current.account_id
  github_org        = var.github_org
}

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project     = local.project
  env         = local.env
  db_username = "pharmaadmin"
  db_password = var.db_password
  db_host     = module.rds.db_instance_address
  jwt_secret  = var.jwt_secret
}
