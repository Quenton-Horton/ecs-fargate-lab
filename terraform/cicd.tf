resource "aws_iam_role" "github_actions" {
  name = "ecs-fargate-lab-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          # Dynamic Parameterization protecting your account ID
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/://githubusercontent.com"
        }
        Condition = {
          StringEquals = {
            "://githubusercontent.com:aud" = "://amazonaws.com"
          }
          StringLike = {
            "://githubusercontent.com:sub" = "repo:Quenton-Horton/ecs-fargate-lab:*"
          }
        }
      }
    ]
  })
}

