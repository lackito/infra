output "s3_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "The name of the S3 bucket"
}

output "terraform_role_arn" {
  description = "Copy this into the aws-terraform-lab GitHub Secret: AWS_IAM_ROLE"
  value       = aws_iam_role.terraform_runner.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC Identity Provider (created once, shared by all roles)"
  value       = aws_iam_openid_connect_provider.github.arn
}
