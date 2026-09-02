# This section configures AWS to trust GitHub Actions as an OpenID Connect (OIDC) identity provider.

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# ========================================================================
#
# GitHub Actions assumes to run Terraform in zenpharma AWS account. This role is assumed by GitHub Actions via OIDC.
resource "aws_iam_role" "terraform_runner" {
  name = "${var.project_name}-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = [
          "sts:AssumeRoleWithWebIdentity",
          "sts:TagSession"
        ]
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "${var.github_oidc_subject}"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-terraform-role"
    Environment = "bootstrap"
    ManagedBy   = "Terraform"
  }
}

# Admin permissions so Terraform can create AWS resources
resource "aws_iam_role_policy_attachment" "terraform_admin" {
  role       = aws_iam_role.terraform_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
