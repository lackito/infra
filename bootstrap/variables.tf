variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "The name of the S3 bucket to store Terraform state"
  type        = string
}

variable "project_name" {
  description = "Project name, used for naming the IAM role"
  type        = string
  default     = "zenpharma"
}

variable "github_oidc_subject" {
  description = "The OIDC subject claim that identifies which GitHub repo can assume this role"
  type        = string
  default     = "repo:lackito*/infra*:*"
}

variable "github_org" {
  description = "GitHub username or organization that owns frontend and backend"
  type        = string
  default     = "lackito"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "650032249451"
}

variable "env" {
  description = "Environment name (dev, qa, prod)"
  type        = string
  default     = "dev"
}
