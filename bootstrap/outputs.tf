output "s3_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "The name of the S3 bucket"
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC Identity Provider (created once, shared by all roles)"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "terraform_runner_role_arn" {
  description = "ARN of the infrastructure runner IAM role"
  value       = aws_iam_role.terraform_runner.arn
}

output "github_actions_ci_role_arn" {
  description = "ARN of the application CI IAM role"
  value       = aws_iam_role.github_actions_ci.arn
}
