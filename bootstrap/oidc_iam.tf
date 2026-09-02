# ─── 1. Global OIDC Provider ──────────────────────────────────────────────────
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# ─── 2. Infrastructure Runner Role (Terraform / IaC) ─────────────────────────
# Used by your infrastructure repositories to manage AWS resources.
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

resource "aws_iam_role_policy_attachment" "terraform_admin" {
  role       = aws_iam_role.terraform_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ─── 3. Application CI Role (App Repos / Image Builds) ───────────────────────
# Used by frontend/backend repos to push ECR images and update EKS workloads.
data "aws_iam_policy_document" "github_actions_ci_assume_role" {
  statement {
    effect  = "Allow"
    actions = [
      "sts:AssumeRoleWithWebIdentity",
      "sts:TagSession"
    ]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/frontend:ref:refs/heads/main",
        "repo:${var.github_org}/frontend:ref:refs/heads/develop",
        "repo:${var.github_org}/backend:ref:refs/heads/main",
        "repo:${var.github_org}/backend:ref:refs/heads/develop",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_ci" {
  name                 = "${var.project_name}-${var.env}-github-actions-role"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_ci_assume_role.json
  max_session_duration = 3600

  tags = {
    Name        = "${var.project_name}-${var.env}-github-actions-role"
    Environment = "bootstrap"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "github_actions_ci_policy" {
  name        = "${var.project_name}-${var.env}-github-actions-policy"
  description = "Allow GitHub Actions CI to push images to ECR and read EKS cluster info"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
        ]
        Resource = "arn:aws:ecr:*:${var.aws_account_id}:repository/*"
      },
      {
        Sid      = "EKSRead"
        Effect   = "Allow"
        Action   = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_ci_policy_attachment" {
  role       = aws_iam_role.github_actions_ci.name
  policy_arn = aws_iam_policy.github_actions_ci_policy.arn
}
